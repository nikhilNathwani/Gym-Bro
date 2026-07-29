import SwiftUI

/// Port of exercises/page.tsx + ExerciseLibraryList.tsx.
struct ExerciseLibraryView: View {
    @Binding var createTrigger: Bool

    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showNewExercise = false
    @State private var errorMessage: String?
    @State private var pendingDeleteExercise: Exercise?
    @State private var renameTarget: Exercise?
    @State private var renameDraft = ""

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List {
                    if exercises.isEmpty {
                        Text("No exercises yet — create one below.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(exercises) { exercise in
                            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                                Text(exercise.name)
                                    .lineLimit(1)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeleteExercise = exercise
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    renameDraft = exercise.name
                                    renameTarget = exercise
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNewExercise) {
            NewExerciseView(onCreated: { _ in Task { await load() } })
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: createTrigger) { _, _ in
            showNewExercise = true
        }
        .confirmationDialog(
            "Delete this exercise? This removes it from every routine and deletes its log history. This cannot be undone.",
            isPresented: Binding(
                get: { pendingDeleteExercise != nil },
                set: { if !$0 { pendingDeleteExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let exercise = pendingDeleteExercise { Task { await deleteExercise(exercise) } }
            }
        }
        .alert(
            "Rename Exercise",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField("Exercise name", text: $renameDraft)
            Button("Save") {
                if let exercise = renameTarget { Task { await renameExercise(exercise) } }
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .errorAlert($errorMessage)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            exercises = try await SupabaseService.shared.fetchExercises()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExercise(_ exercise: Exercise) async {
        do {
            try await SupabaseService.shared.deleteExercise(id: exercise.id)
            pendingDeleteExercise = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameExercise(_ exercise: Exercise) async {
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            renameTarget = nil
            return
        }
        do {
            try await SupabaseService.shared.updateExerciseName(id: exercise.id, name: trimmed)
            renameTarget = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
