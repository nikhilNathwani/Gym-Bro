import SwiftUI

/// Modal presentation of AssignExercisePickerView, opened from the
/// bottom-right "+" button while a routine is on screen — keeps "+" meaning
/// "create/add into the current context" everywhere in the app (a routine
/// on the Routines tab, an exercise on the Exercises tab, an exercise
/// within a routine here), instead of a permanently-visible inline panel.
struct AddExerciseToRoutineSheet: View {
    let routineId: UUID
    let unassignedExercises: [Exercise]
    let onChanged: () async -> Void
    let onCreated: (UUID) -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                AssignExercisePickerView(
                    routineId: routineId,
                    unassignedExercises: unassignedExercises,
                    onChanged: {
                        await onChanged()
                        dismiss()
                    },
                    onCreated: onCreated,
                    onError: onError,
                    autofocus: true
                )
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
