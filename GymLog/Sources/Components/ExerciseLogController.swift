import Foundation

/// Owns one exercise's editable log state (sets, notes) and its lazy
/// persistence to Supabase, independent of how that state gets laid out on
/// screen. Split out of what used to be a single `InlineExerciseCard` view
/// so `WorkoutSessionView` can render the read-only reference material
/// (`ExerciseReferenceSection`: target, last time, cues, open-full-page
/// link) in one independently-scrolling region and the actual input
/// controls (`ExerciseLoggingDock`: steppers + notes) in a separate fixed
/// dock alongside Prev/Next — both views share this same controller
/// instance instead of duplicating state.
///
/// Deliberately does NOT create a workout_session/exercise_log just because
/// the exercise is being viewed — merely reading cues or checking last
/// time's numbers must not silently log a phantom session. A log (and each
/// set within it) is only created lazily, the moment "Add Set" is tapped;
/// see `ensureTodayLog()`. This includes the very first set — there's no
/// pre-filled draft row a stepper tap silently turns into a real log
/// anymore (an earlier version worked that way, but a set that happened to
/// match the pre-filled default then never got logged at all, since
/// nothing ever "changed" — tapping "Add Set" itself is now the only thing
/// that logs a set, matching the explicit action every other set already
/// requires).
///
/// `@MainActor` is required, not decorative: every `commitSet`/`addSet`/
/// `deleteLastSet` call spins up a `Task` that awaits a network call
/// (`SupabaseService`, not itself MainActor-isolated) and then reads/writes
/// `sets` afterward. Without pinning this class to MainActor, that
/// post-await continuation is free to resume on a background thread,
/// racing the main thread's synchronous UI-driven mutations to the same
/// `sets` array — confirmed as a real, reproducible bug (not just a
/// theoretical one): two rapid stepper taps could lose an update, silently
/// persisting an earlier value instead of the latest one.
@MainActor
@Observable
final class ExerciseLogController {
    let exercise: ExerciseDetail
    let onLogged: () async -> Void
    let onError: (String) -> Void

    struct EditableSet: Identifiable {
        var id: UUID
        var setNumber: Int
        var weight: Double
        var reps: Int
        var weightText: String
        var repsText: String
        var persisted: Bool
    }

    var sets: [EditableSet] = []
    var notesDraft = ""
    var isCuesExpanded = true

    // Only one set shows its stepper controls at a time — completed sets
    // collapse to a compact read-only row (see `ExerciseLoggingSections`),
    // since in practice past sets are rarely revisited once logged. `nil`
    // means "no explicit choice yet," which defers to the last set — so a
    // fresh set added via `addSet()` becomes the active one automatically
    // just by resetting this to `nil` again, without needing to know its
    // number in advance.
    var expandedSetNumber: Int?

    var effectiveExpandedSetNumber: Int? {
        expandedSetNumber ?? sets.last?.setNumber
    }

    // Bumped on every stepper tap so a view can attach
    // `.sensoryFeedback(_:trigger:)` to it — a plain `Stepper` fires this
    // haptic itself on a real device, but that's implicit system behavior
    // this project has no direct control over, so this gives an explicit,
    // guaranteed-correct trigger to pair it with instead of relying on it
    // alone.
    var stepTick = 0

    private var todayLogId: UUID?
    private var lastCommittedNotes: String?

    // Serializes concurrent writers so a rapid double-tap (or an
    // automated UI test tapping faster than the network round-trip) can't
    // race two "not persisted yet" checks and create duplicate rows.
    // Keyed by setNumber, not the set's own id — that id changes from a
    // temporary local UUID to the real database one the moment it's first
    // persisted, so it can't be used as a stable queue key.
    private var creatingLogTask: Task<UUID?, Never>?
    private var pendingSetTasks: [Int: Task<Void, Never>] = [:]

    init(exercise: ExerciseDetail, onLogged: @escaping () async -> Void, onError: @escaping (String) -> Void) {
        self.exercise = exercise
        self.onLogged = onLogged
        self.onError = onError
        seed()
    }

    // MARK: - Last Time

    var lastTime: ExerciseLog? {
        let logs = exercise.exerciseLogs
        guard let first = logs.first else { return nil }
        if Calendar.current.isDateInToday(first.createdAt) {
            return logs.count > 1 ? logs[1] : nil
        }
        return first
    }

    // MARK: - Seeding

    private func seed() {
        if let todayLog = exercise.exerciseLogs.first(where: { Calendar.current.isDateInToday($0.createdAt) }) {
            todayLogId = todayLog.id
            // Can legitimately be empty — deleting the last set (down to
            // zero) leaves a real, childless exercise_log row behind rather
            // than deleting it outright (see `deleteLastSet`), and every
            // read of it already treats zero sets as "not logged today"
            // (`RoutineDetailView.hasLoggedToday`/`exerciseRow`).
            sets = todayLog.setLogs
                .sorted { $0.setNumber < $1.setNumber }
                .map { set in
                    EditableSet(
                        id: set.id,
                        setNumber: set.setNumber,
                        weight: set.weight ?? 0,
                        reps: set.reps ?? 0,
                        weightText: formatNumber(set.weight ?? 0),
                        repsText: String(set.reps ?? 0),
                        persisted: true
                    )
                }
            notesDraft = todayLog.notes ?? ""
            lastCommittedNotes = todayLog.notes
        } else {
            todayLogId = nil
            sets = []
            notesDraft = ""
            lastCommittedNotes = nil
        }
    }

    /// Sensible starting values for the very first set of a fresh session —
    /// last time's first set, if there is one — used only as `addSet()`'s
    /// pre-filled suggestion, not to silently create a row on its own.
    private func firstSetDefaults() -> (weight: Double, reps: Int) {
        let lastSet = lastTime?.setLogs.sorted { $0.setNumber < $1.setNumber }.first
        return (lastSet?.weight ?? 0, lastSet?.reps ?? 0)
    }

    func setIndex(for id: UUID) -> Int? {
        sets.firstIndex { $0.id == id }
    }

    // MARK: - Persistence

    /// Lazily creates today's exercise_log on first real interaction only —
    /// never on mere expand/view. Notifies the parent so the routine list's
    /// "logged today" checkmark can update. Concurrent callers (a rapid
    /// double-tap before the first creation round-trips) share the same
    /// in-flight task instead of each creating their own exercise_log.
    private func ensureTodayLog() async -> UUID? {
        if let id = todayLogId {
            return id
        }
        if let creatingLogTask {
            return await creatingLogTask.value
        }
        let task = Task<UUID?, Never> {
            do {
                return try await SupabaseService.shared.createExerciseLogForToday(exerciseId: exercise.id)
            } catch {
                onError(error.localizedDescription)
                return nil
            }
        }
        creatingLogTask = task
        let id = await task.value
        creatingLogTask = nil
        if let id {
            todayLogId = id
            await onLogged()
        }
        return id
    }

    func adjustWeight(at index: Int, by delta: Double) {
        let newValue = max(0, sets[index].weight + delta)
        sets[index].weight = newValue
        sets[index].weightText = formatNumber(newValue)
        stepTick += 1
        commitSet(at: index)
    }

    func adjustReps(at index: Int, by delta: Int) {
        let newValue = max(0, sets[index].reps + delta)
        sets[index].reps = newValue
        sets[index].repsText = String(newValue)
        stepTick += 1
        commitSet(at: index)
    }

    func commitWeightText(at index: Int) {
        let trimmed = sets[index].weightText.trimmingCharacters(in: .whitespaces)
        if let parsed = Double(trimmed) {
            sets[index].weight = max(0, parsed)
        }
        sets[index].weightText = formatNumber(sets[index].weight)
        commitSet(at: index)
    }

    func commitRepsText(at index: Int) {
        let trimmed = sets[index].repsText.trimmingCharacters(in: .whitespaces)
        if let parsed = Int(trimmed) {
            sets[index].reps = max(0, parsed)
        }
        sets[index].repsText = String(sets[index].reps)
        commitSet(at: index)
    }

    /// Queued per setNumber: a second commit arriving before the first has
    /// round-tripped awaits it first, then re-reads the row fresh — so it
    /// correctly sees `persisted == true` (set by the first commit) and
    /// updates instead of creating a duplicate set_log.
    private func commitSet(at index: Int) {
        let setNumber = sets[index].setNumber
        let previous = pendingSetTasks[setNumber]
        let task = Task<Void, Never> {
            await previous?.value
            guard let logId = await ensureTodayLog() else { return }
            guard let i = sets.firstIndex(where: { $0.setNumber == setNumber }) else {
                return
            }
            let set = sets[i]
            do {
                if set.persisted {
                    try await SupabaseService.shared.updateSetLog(id: set.id, weight: set.weight, reps: set.reps)
                } else {
                    let newId = try await SupabaseService.shared.createSetLog(
                        exerciseLogId: logId, setNumber: set.setNumber, weight: set.weight, reps: set.reps)
                    if let ii = sets.firstIndex(where: { $0.setNumber == setNumber }) {
                        sets[ii].id = newId
                        sets[ii].persisted = true
                    }
                }
            } catch {
                onError(error.localizedDescription)
            }
        }
        pendingSetTasks[setNumber] = task
    }

    func addSet() {
        Task {
            guard let logId = await ensureTodayLog() else { return }
            do {
                // Repeats the previous set's own values if there is one;
                // otherwise (the very first set of the session) falls back
                // to last time's numbers as a starting suggestion. Either
                // way "Add set" is a deliberate action, so the new row
                // persists immediately.
                let weight = sets.last?.weight ?? firstSetDefaults().weight
                let reps = sets.last?.reps ?? firstSetDefaults().reps
                let setNumber = sets.count + 1
                let newId = try await SupabaseService.shared.createSetLog(
                    exerciseLogId: logId, setNumber: setNumber, weight: weight, reps: reps)
                sets.append(
                    EditableSet(
                        id: newId, setNumber: setNumber, weight: weight, reps: reps,
                        weightText: formatNumber(weight), repsText: String(reps), persisted: true))
                expandedSetNumber = nil
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    func commitNotes() {
        let trimmed = notesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? nil : trimmed
        guard normalized != lastCommittedNotes else { return }
        lastCommittedNotes = normalized
        Task {
            guard let logId = await ensureTodayLog() else { return }
            do {
                try await SupabaseService.shared.updateExerciseLogNotesOnly(id: logId, notes: normalized)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    /// Undoes an "Add set" — only ever removes the last row, so the
    /// remaining sets stay a contiguous 1...N run with no renumbering
    /// needed either locally or in the backend. Can now empty the list
    /// entirely (the first set is no different from any other latest set —
    /// see the type doc comment) — that's not a special case here, since
    /// every read of `sets`/the persisted log already treats zero sets as
    /// "nothing logged today."
    func deleteLastSet() {
        guard let last = sets.popLast() else { return }
        // `effectiveExpandedSetNumber` already falls back to the new last
        // set whenever `expandedSetNumber` is nil, but if it was pointing
        // at this now-deleted set *explicitly* (set via tapping this exact
        // row open while it also happened to be the last one), it would
        // otherwise keep pointing at a set number that no longer exists —
        // leaving every remaining row collapsed with nothing active.
        if expandedSetNumber == last.setNumber { expandedSetNumber = nil }
        let setNumber = last.setNumber
        let previousTask = pendingSetTasks[setNumber]
        pendingSetTasks[setNumber] = nil
        guard last.persisted else { return }
        Task {
            await previousTask?.value
            do {
                try await SupabaseService.shared.deleteSetLog(id: last.id)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }
}
