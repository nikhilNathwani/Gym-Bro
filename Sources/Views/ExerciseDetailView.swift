import SwiftUI

/// Standalone exercise page — reached from the Exercises tab, with no
/// Prev/Next paging (there's no routine/workout context to page through).
/// Hosts the same `ExercisePageList` content `WorkoutSessionView` wraps with
/// its Prev/Next toolbar; this used to be a separate page with its own
/// duplicated (and less capable — no editable target/cues, no inline
/// history) content before the two were merged into one.
struct ExerciseDetailView: View {
    let exerciseId: UUID

    @State private var controller: ExerciseLogController?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @FocusState private var focusedField: LoggingFocusField?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let controller {
                ExercisePageList(controller: controller, focusedField: $focusedField)
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Exercise Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if controller != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete Exercise", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            // Same as WorkoutSessionView's keyboard accessory — commits
            // whatever's focused by clearing focus, which the `onChange`
            // below turns into an actual save.
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            guard let oldValue, let controller else { return }
            switch oldValue {
            case .name: controller.saveName()
            case .target: controller.saveTarget()
            case .cues: controller.saveCues()
            case .weight(let id): if let i = controller.setIndex(for: id) { controller.commitWeightText(at: i) }
            case .reps(let id): if let i = controller.setIndex(for: id) { controller.commitRepsText(at: i) }
            case .notes: controller.commitNotes()
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: controller?.sets.count)
        .sensoryFeedback(.impact(weight: .light), trigger: controller?.stepTick)
        .sensoryFeedback(.selection, trigger: controller?.expandedSetNumber)
        .task { await load() }
        .confirmationDialog(
            "Delete this exercise? This removes it from every routine and deletes its log history. This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await deleteExercise() } }
        }
        .errorAlert($errorMessage)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let detail = try await SupabaseService.shared.fetchExerciseDetail(id: exerciseId) else {
                errorMessage = "Exercise not found"
                return
            }
            controller = ExerciseLogController(
                exercise: detail,
                onLogged: {},
                onError: { errorMessage = $0 }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExercise() async {
        do {
            try await SupabaseService.shared.deleteExercise(id: exerciseId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
