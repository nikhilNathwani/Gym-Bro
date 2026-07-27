import SwiftUI

/// Port of LogEntryForm.tsx: the "+ Log today" entry form, used both at the
/// bottom of ExerciseDetailView and inline in each expanded routine-exercise
/// accordion card.
struct LogEntryFormView: View {
    let exerciseId: UUID
    var previousSets: [SetLog] = []
    let onLogged: () async -> Void
    let onError: (String) -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var notes = ""
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("+ Log today")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.foreground)

            SetFieldsEditor(weightText: $weightText, repsText: $repsText, previousSets: previousSets)

            TextField("Notes — how did it feel?", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding(10)
                .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))

            Button {
                Task { await save() }
            } label: {
                Text(isSaving ? "Saving…" : "Save entry")
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(Theme.background)
                    .background(Theme.foreground)
            }
            .disabled(isSaving)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let weights = SetFieldsParsing.splitCommaList(weightText).map(SetFieldsParsing.parseDoubleOrNil)
            let reps = SetFieldsParsing.splitCommaList(repsText).map(SetFieldsParsing.parseIntOrNil)
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            try await SupabaseService.shared.addLogEntry(
                exerciseId: exerciseId,
                weights: weights,
                reps: reps,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            weightText = ""
            repsText = ""
            notes = ""
            await onLogged()
        } catch {
            onError(error.localizedDescription)
        }
    }
}
