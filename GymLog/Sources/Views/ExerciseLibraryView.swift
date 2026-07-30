import SwiftUI

/// Port of exercises/page.tsx + ExerciseLibraryList.tsx. Pushed from
/// `RoutinesListView`'s toolbar icon (its own `NavigationStack` hosts this,
/// same routes as everywhere else in the app) — not a tab root anymore, so
/// it gets a plain system back chevron instead of an account avatar button.
struct ExerciseLibraryView: View {
    @Binding var createTrigger: Bool

    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showNewExercise = false
    @State private var errorMessage: String?
    @State private var pendingDeleteExercise: Exercise?
    @State private var renameTarget: Exercise?
    @State private var renameDraft = ""
    @State private var destructiveActionTaken = false
    @State private var savedTick = 0

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if exercises.isEmpty {
                ContentUnavailableView(
                    "No Exercises", systemImage: "dumbbell",
                    description: Text("Tap + to create one."))
            } else {
                List {
                    ForEach(exercises) { exercise in
                        NavigationLink(value: AppRoute.exercise(exercise.id)) {
                            Text(exercise.name)
                                .lineLimit(1)
                        }
                        // `allowsFullSwipe: false` — without it, a full
                        // swipe plays List's optimistic delete-and-collapse
                        // animation before this confirmation dialog even
                        // appears, so the row snaps back once the dialog
                        // resolves (same bug fixed in `HistoryEntryView`/
                        // `RoutineDetailView`'s swipe actions).
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                // `.plain` — matching Routines' edge-to-edge, divider-
                // separated look. Left unset before, this list defaulted to
                // an inset-grouped rounded card floating on a gray
                // background, a different native list style from its
                // sibling top-level list for no real reason (unlike
                // RoutineDetailView, which has a deliberate reason to stay
                // grouped: its accent-colored "Start/Continue Workout"
                // button relies on the grouped style's rounded corners to
                // read as a button at all).
                .listStyle(.plain)
                // Small breathing room between the large title and the
                // first row — `.plain` otherwise butts content right up
                // against it with almost no gap.
                .contentMargins(.top, 8, for: .scrollContent)
            }
        }
        // Large title, same Apple Notes-style treatment as Routines — but
        // no avatar button here; the back chevron (automatic for a pushed
        // screen) already occupies the leading slot.
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.large)
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
                destructiveActionTaken.toggle()
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
        .sensoryFeedback(.warning, trigger: destructiveActionTaken)
        .sensoryFeedback(.impact(weight: .light), trigger: savedTick)
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
        let trimmed = renameDraft.trimmed
        guard !trimmed.isEmpty else {
            renameTarget = nil
            return
        }
        do {
            try await SupabaseService.shared.updateExerciseName(id: exercise.id, name: trimmed)
            renameTarget = nil
            savedTick += 1
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
