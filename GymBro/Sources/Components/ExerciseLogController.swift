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
/// time's numbers must not silently log a phantom session. A log is only
/// created lazily, on the first real interaction (a stepper tap, a typed
/// value, or "Add set"); see `ensureTodayLog()`.
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
            let existing = todayLog.setLogs
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
            sets = existing.isEmpty ? [draftFirstSet()] : existing
            notesDraft = todayLog.notes ?? ""
            lastCommittedNotes = todayLog.notes
        } else {
            todayLogId = nil
            sets = [draftFirstSet()]
            notesDraft = ""
            lastCommittedNotes = nil
        }
    }

    private func draftFirstSet() -> EditableSet {
        let lastSet = lastTime?.setLogs.sorted { $0.setNumber < $1.setNumber }.first
        let weight = lastSet?.weight ?? 0
        let reps = lastSet?.reps ?? 0
        return EditableSet(
            id: UUID(), setNumber: 1, weight: weight, reps: reps,
            weightText: formatNumber(weight), repsText: String(reps), persisted: false
        )
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
        if let id = todayLogId { return id }
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
        commitSet(at: index)
    }

    func adjustReps(at index: Int, by delta: Int) {
        let newValue = max(0, sets[index].reps + delta)
        sets[index].reps = newValue
        sets[index].repsText = String(newValue)
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
            guard let i = sets.firstIndex(where: { $0.setNumber == setNumber }) else { return }
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
                // Persist any still-draft rows first (the initial unsaved row).
                for i in sets.indices where !sets[i].persisted {
                    let newId = try await SupabaseService.shared.createSetLog(
                        exerciseLogId: logId, setNumber: sets[i].setNumber,
                        weight: sets[i].weight, reps: sets[i].reps)
                    sets[i].id = newId
                    sets[i].persisted = true
                }
                // "Add set" is a deliberate action, so the new row persists immediately.
                let last = sets.last
                let weight = last?.weight ?? 0
                let reps = last?.reps ?? 0
                let setNumber = sets.count + 1
                let newId = try await SupabaseService.shared.createSetLog(
                    exerciseLogId: logId, setNumber: setNumber, weight: weight, reps: reps)
                sets.append(
                    EditableSet(
                        id: newId, setNumber: setNumber, weight: weight, reps: reps,
                        weightText: formatNumber(weight), repsText: String(reps), persisted: true))
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

    /// Undoes an accidental "Add set" — only ever removes the last row, so
    /// the remaining sets stay a contiguous 1...N run with no renumbering
    /// needed either locally or in the backend.
    func deleteLastSet() {
        guard sets.count > 1, let last = sets.popLast() else { return }
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
