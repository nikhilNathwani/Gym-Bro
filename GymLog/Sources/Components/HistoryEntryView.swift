import SwiftUI

/// Shared short date style ("7/31/26") for every logged-session date shown
/// on the exercise page — History rows and the "Today's Log" section
/// header alike — so today's entry reads as the same kind of thing as a
/// past one, just the most recent.
let logEntryDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d/yy"
    return formatter
}()

private enum HistoryEditField: Hashable {
    case weight(Int)
    case reps(Int)
}

/// One past logged session inside `ExerciseHistorySection`. Tap the
/// summary to edit it, swipe to delete — same
/// idioms as a set row in "Today's Log" (tap-to-expand for editing, swipe
/// reserved for the destructive action only), not the always-visible
/// "Edit"/"Delete" text buttons and custom card background this used to
/// have, which read as a leftover from before this app leaned into native
/// list components.
///
/// Editing uses the same `SetValueStepper` (TextField + Stepper) pairs as
/// "Today's Log" — this used to be a completely different editor (a
/// comma-separated-list `TextField` backed by a custom on-screen keypad,
/// `SetFieldsEditor`/`NumericKeypadView`), a leftover from before that
/// redesign that never got reconciled. Editing here is a one-shot batch
/// edit (an explicit Save button, not commit-per-field like Today's Log),
/// so there's no network round-trip per keystroke/stepper-tap — just local
/// `editableSets` state, converted to `weights`/`reps` arrays on Save.
struct HistoryEntryView: View {
    let log: ExerciseLog
    let onChanged: () async -> Void
    let onError: (String) -> Void

    private struct EditableSet: Identifiable {
        let id = UUID()
        var weight: Double
        var weightText: String
        var reps: Int
        var repsText: String
    }

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var editableSets: [EditableSet] = []
    @State private var notes = ""
    @State private var showDeleteConfirm = false
    @State private var destructiveActionTaken = false
    @State private var savedTick = 0
    @FocusState private var focusedField: HistoryEditField?

    var body: some View {
        Group {
            if isEditing {
                editingRow
            } else {
                summaryRow
            }
        }
        .confirmationDialog(
            "Delete this logged session? This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                destructiveActionTaken.toggle()
                Task { await delete() }
            }
        }
        .sensoryFeedback(.warning, trigger: destructiveActionTaken)
        .sensoryFeedback(.impact(weight: .light), trigger: savedTick)
        .onChange(of: focusedField) { oldValue, _ in
            guard let oldValue else { return }
            switch oldValue {
            case .weight(let index): commitWeightText(at: index)
            case .reps(let index): commitRepsText(at: index)
            }
        }
    }

    private var summaryRow: some View {
        Button {
            beginEditing()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(logEntryDateFormatter.string(from: log.createdAt))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(log.setsSummary)
                    .font(.body)
                    .monospacedDigit()
                if let notes = log.notes, !notes.isEmpty {
                    Text("\u{201C}\(notes)\u{201D}")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // `allowsFullSwipe: false` (matching the "Today's Log" set row's
        // own swipe action) — without it, a full swipe plays List's
        // optimistic delete-and-collapse animation immediately, before this
        // action closure's confirmation dialog even appears; since nothing
        // actually removes the row from `pastLogs` until the dialog is
        // confirmed, the row then snaps back once the dialog is dismissed
        // or never shown in time — reads as "deleted, then came back" and
        // masks the confirmation prompt entirely. Forcing an explicit tap
        // on "Delete" avoids the premature animation altogether.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No `role: .destructive` — that role makes List play its own
            // optimistic row-collapse animation the instant the button is
            // tapped, even with `allowsFullSwipe: false` and even though
            // nothing is actually deleted until the confirmation dialog
            // below is confirmed. The row then snapped back once that
            // animation finished, reading as "deleted, then un-deleted
            // itself" — the exact bug `allowsFullSwipe: false` above was
            // meant to prevent, just triggered by a tap instead of a full
            // swipe. A plain button tinted red keeps the same destructive
            // look without the automatic animation.
            //
            // Deferred past the current run loop turn — setting
            // `showDeleteConfirm` synchronously here races the swipe
            // action's own dismissal animation (same issue as the "Today's
            // Log" set row's delete swipe action; see its own comment),
            // which on-device tears the dialog down before it can be
            // tapped, or swallows a tap that lands during that window.
            Button {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showDeleteConfirm = true
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    private var editingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            if editableSets.isEmpty {
                Text("No sets — Add Set below.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(editableSets.enumerated()), id: \.element.id) { index, _ in
                    editableSetRow(at: index)
                }
            }

            Button(action: addSet) {
                Label("Add Set", systemImage: "plus.circle.fill")
            }

            TextField("Notes — how did it feel?", text: $notes, axis: .vertical)
                .lineLimit(2...4)

            HStack(spacing: 8) {
                Button {
                    Task { await save() }
                } label: {
                    Text(isSaving ? "Saving…" : "Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button {
                    isEditing = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func editableSetRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(index + 1)")
                    .font(.body.weight(.medium))
                Spacer()
                // Same domain constraint as Today's Log: only the last set
                // can be removed, so nothing needs renumbering.
                if index == editableSets.count - 1 {
                    Button(role: .destructive, action: removeLastSet) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            HStack(spacing: 14) {
                SetValueStepper(
                    label: "Weight (lbs)",
                    text: $editableSets[index].weightText,
                    keyboardType: .decimalPad,
                    idPrefix: "history-weight-\(index)",
                    focusedField: $focusedField,
                    focusCase: .weight(index),
                    onIncrement: { adjustWeight(at: index, by: 2.5) },
                    onDecrement: { adjustWeight(at: index, by: -2.5) }
                )
                SetValueStepper(
                    label: "Reps",
                    text: $editableSets[index].repsText,
                    keyboardType: .numberPad,
                    idPrefix: "history-reps-\(index)",
                    focusedField: $focusedField,
                    focusCase: .reps(index),
                    onIncrement: { adjustReps(at: index, by: 1) },
                    onDecrement: { adjustReps(at: index, by: -1) }
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func beginEditing() {
        editableSets = log.setLogs
            .sorted { $0.setNumber < $1.setNumber }
            .map { set in
                EditableSet(
                    weight: set.weight ?? 0, weightText: set.weight.map(formatNumber) ?? "0",
                    reps: set.reps ?? 0, repsText: set.reps.map(String.init) ?? "0")
            }
        notes = log.notes ?? ""
        isEditing = true
    }

    private func adjustWeight(at index: Int, by delta: Double) {
        let newValue = max(0, editableSets[index].weight + delta)
        editableSets[index].weight = newValue
        editableSets[index].weightText = formatNumber(newValue)
    }

    private func adjustReps(at index: Int, by delta: Int) {
        let newValue = max(0, editableSets[index].reps + delta)
        editableSets[index].reps = newValue
        editableSets[index].repsText = String(newValue)
    }

    private func commitWeightText(at index: Int) {
        guard index < editableSets.count else { return }
        let trimmed = editableSets[index].weightText.trimmingCharacters(in: .whitespaces)
        if let parsed = Double(trimmed) {
            editableSets[index].weight = max(0, parsed)
        }
        editableSets[index].weightText = formatNumber(editableSets[index].weight)
    }

    private func commitRepsText(at index: Int) {
        guard index < editableSets.count else { return }
        let trimmed = editableSets[index].repsText.trimmingCharacters(in: .whitespaces)
        if let parsed = Int(trimmed) {
            editableSets[index].reps = max(0, parsed)
        }
        editableSets[index].repsText = String(editableSets[index].reps)
    }

    private func addSet() {
        let last = editableSets.last
        let weight = last?.weight ?? 0
        let reps = last?.reps ?? 0
        editableSets.append(
            EditableSet(weight: weight, weightText: formatNumber(weight), reps: reps, repsText: String(reps)))
    }

    private func removeLastSet() {
        guard !editableSets.isEmpty else { return }
        editableSets.removeLast()
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedNotes = notes.trimmed
            try await SupabaseService.shared.updateLogEntry(
                exerciseLogId: log.id,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                weights: editableSets.map { Optional($0.weight) },
                reps: editableSets.map { Optional($0.reps) }
            )
            savedTick += 1
            isEditing = false
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func delete() async {
        do {
            try await SupabaseService.shared.deleteLogEntry(id: log.id)
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }
}
