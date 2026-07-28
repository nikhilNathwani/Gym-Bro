import SwiftUI

/// Inline accordion replacement for the old RoutineExerciseDetailSheet —
/// expands directly within the routine's exercise list instead of a
/// `.sheet`, matching Apple Notes' "one continuous scrollable page" feel
/// instead of a sheet-per-exercise, custom-keypad-per-field flow.
///
/// Deliberately does NOT create a workout_session/exercise_log just because
/// the card is expanded — merely opening an exercise to read cues or check
/// last time's numbers must not silently log a phantom session. A log is
/// only created lazily, on the first real interaction (a stepper tap, a
/// typed value, or "Add set"); see `ensureTodayLog()`.
///
/// Owns its own local editable state, seeded once per exercise identity via
/// `.task(id:)` — a parent `reload()` mid-edit (e.g. after another card's
/// change) passes fresh `exercise` data down without resetting whatever the
/// user is mid-typing here, since `.task(id:)` only re-seeds when the
/// exercise identity itself changes.
struct InlineExerciseCard: View {
    let exercise: ExerciseDetail
    let onLogged: () async -> Void
    let onError: (String) -> Void

    private struct EditableSet: Identifiable {
        var id: UUID
        var setNumber: Int
        var weight: Double
        var reps: Int
        var weightText: String
        var repsText: String
        var persisted: Bool
    }

    private enum FocusField: Hashable {
        case weight(UUID)
        case reps(UUID)
        case notes
    }

    @State private var todayLogId: UUID?
    @State private var sets: [EditableSet] = []
    @State private var notesDraft = ""
    @State private var lastCommittedNotes: String?
    @State private var isCuesExpanded = true
    @FocusState private var focusedField: FocusField?

    // Serializes concurrent writers so a rapid double-tap (or an
    // automated UI test tapping faster than the network round-trip) can't
    // race two "not persisted yet" checks and create duplicate rows.
    // Keyed by setNumber, not the set's own id — that id changes from a
    // temporary local UUID to the real database one the moment it's first
    // persisted, so it can't be used as a stable queue key.
    @State private var creatingLogTask: Task<UUID?, Never>?
    @State private var pendingSetTasks: [Int: Task<Void, Never>] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let subtitle = exercise.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let lastTime {
                lastTimeSection(lastTime)
            }

            inputArea

            if let cues = exercise.cues, !cues.isEmpty {
                cuesSection(cues)
            }

            openFullPageLink
        }
        .padding(.vertical, 6)
        .task(id: exercise.id) { seed() }
        .onChange(of: focusedField) { oldValue, _ in
            guard let oldValue else { return }
            switch oldValue {
            case .weight(let id): if let i = setIndex(for: id) { commitWeightText(at: i) }
            case .reps(let id): if let i = setIndex(for: id) { commitRepsText(at: i) }
            case .notes: commitNotes()
            }
        }
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    // MARK: - Last Time

    private var lastTime: ExerciseLog? {
        let logs = exercise.exerciseLogs
        guard let first = logs.first else { return nil }
        if Calendar.current.isDateInToday(first.createdAt) {
            return logs.count > 1 ? logs[1] : nil
        }
        return first
    }

    private func lastTimeSection(_ log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last Time").font(.subheadline.weight(.semibold))
                Spacer()
                // Not wired up yet — deliberately left as a placeholder.
                Text("View history")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(setsSummary(log))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let notes = log.notes, !notes.isEmpty {
                Text("\u{201C}\(notes)\u{201D}")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func setsSummary(_ log: ExerciseLog) -> String {
        log.setLogs
            .sorted { $0.setNumber < $1.setNumber }
            .map { set in
                let weight = set.weight.map(formatNumber) ?? "–"
                let reps = set.reps.map(String.init) ?? "–"
                return "\(weight)×\(reps)"
            }
            .joined(separator: " · ")
    }

    // MARK: - Input area (sets + notes)

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Spacer().frame(width: 34)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(sets.indices, id: \.self) { index in
                    setRow(index)
                }
                HStack {
                    Spacer()
                    addSetButton
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                notesField
            }
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func setRow(_ index: Int) -> some View {
        HStack(spacing: 6) {
            Text("Set \(sets[index].setNumber)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

            numericStepper(
                text: Binding(
                    get: { sets[index].weightText },
                    set: { sets[index].weightText = $0 }
                ),
                keyboardType: .decimalPad,
                focusField: .weight(sets[index].id),
                idPrefix: "weight-\(sets[index].setNumber)",
                onDecrement: { adjustWeight(at: index, by: -2.5) },
                onIncrement: { adjustWeight(at: index, by: 2.5) }
            )
            numericStepper(
                text: Binding(
                    get: { sets[index].repsText },
                    set: { sets[index].repsText = $0 }
                ),
                keyboardType: .numberPad,
                focusField: .reps(sets[index].id),
                idPrefix: "reps-\(sets[index].setNumber)",
                onDecrement: { adjustReps(at: index, by: -1) },
                onIncrement: { adjustReps(at: index, by: 1) }
            )
        }
    }

    // idPrefix is keyed by set *number* (stable, e.g. "weight-1"), not the
    // set's UUID (which only exists once persisted) — lets UI tests target
    // "the first set's weight stepper" predictably regardless of
    // persistence state.
    private func numericStepper(
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        focusField: FocusField,
        idPrefix: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 2) {
            stepperButton(systemImage: "minus", identifier: "\(idPrefix)-minus", action: onDecrement)

            TextField("", text: text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.center)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .focused($focusedField, equals: focusField)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("\(idPrefix)-field")

            stepperButton(systemImage: "plus", identifier: "\(idPrefix)-plus", action: onIncrement)
        }
        .padding(3)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    // 44x44 matches Apple HIG's minimum recommended tap target — the
    // original 21x21 was too small to hit reliably mid-set at the gym.
    private func stepperButton(systemImage: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityIdentifier(identifier)
    }

    private var addSetButton: some View {
        Button(action: addSet) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("Add set")
            }
            .font(.caption.weight(.semibold))
        }
        .accessibilityIdentifier("addSetButton")
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    private var notesField: some View {
        TextField("Add a note for today…", text: $notesDraft, axis: .vertical)
            .font(.subheadline)
            .lineLimit(2...6)
            .focused($focusedField, equals: .notes)
            .padding(9)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("notesField")
    }

    // MARK: - Cues

    private func cuesSection(_ cues: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isCuesExpanded.toggle()
            } label: {
                HStack {
                    Text("Cues").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCuesExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if isCuesExpanded {
                Text(cues)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var openFullPageLink: some View {
        VStack(spacing: 10) {
            Divider()
            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                HStack(spacing: 4) {
                    Text("Open full exercise page")
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
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

    private func setIndex(for id: UUID) -> Int? {
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

    private func adjustWeight(at index: Int, by delta: Double) {
        let newValue = max(0, sets[index].weight + delta)
        sets[index].weight = newValue
        sets[index].weightText = formatNumber(newValue)
        commitSet(at: index)
    }

    private func adjustReps(at index: Int, by delta: Int) {
        let newValue = max(0, sets[index].reps + delta)
        sets[index].reps = newValue
        sets[index].repsText = String(newValue)
        commitSet(at: index)
    }

    private func commitWeightText(at index: Int) {
        let trimmed = sets[index].weightText.trimmingCharacters(in: .whitespaces)
        if let parsed = Double(trimmed) {
            sets[index].weight = max(0, parsed)
        }
        sets[index].weightText = formatNumber(sets[index].weight)
        commitSet(at: index)
    }

    private func commitRepsText(at index: Int) {
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

    private func addSet() {
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

    private func commitNotes() {
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
}
