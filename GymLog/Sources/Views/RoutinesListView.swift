import SwiftUI

/// Port of page.tsx (home / "/"). The app's single root screen — also owns
/// the one shared `NavigationStack` (see `RootView`), including the push
/// into `ExerciseLibraryView` via the toolbar icon below, so its
/// `navigationDestination` declarations cover every route in the app.
struct RoutinesListView: View {
    @Binding var createTrigger: Bool
    @Binding var createExerciseTrigger: Bool
    @Binding var addExerciseTrigger: Bool
    @Binding var isRoutineDetailActive: Bool
    @Binding var isExerciseLibraryActive: Bool
    @Binding var isWorkoutSessionActive: Bool

    @State private var path = NavigationPath()
    @State private var routines: [Routine] = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var pendingDeleteRoutine: Routine?
    @State private var renameTarget: Routine?
    @State private var renameDraft = ""
    @State private var destructiveActionTaken = false
    @State private var savedTick = 0

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLoading {
                    ProgressView()
                } else if routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines", systemImage: "list.bullet.clipboard",
                        description: Text("Tap + to create one."))
                } else {
                    // A real `List`, not a `ScrollView`/`LazyVStack` (this
                    // row's original grid-card predecessor) — reorder is
                    // `EditButton` + `.onMove`, matching
                    // `RoutineDetailView`'s exercise list exactly instead of
                    // a second, unrelated drag-and-drop mechanism, and
                    // rename/delete are `.swipeActions`, matching
                    // `ExerciseLibraryView`'s exercise rows instead of a
                    // long-press context menu a full-width row doesn't
                    // otherwise invite.
                    List {
                        ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                            NavigationLink(value: AppRoute.routine(routine.id)) {
                                RoutineRow(title: displayName(for: routine, index: index))
                            }
                            // `allowsFullSwipe: false` — same reasoning as
                            // `ExerciseLibraryView`/`HistoryEntryView`'s own
                            // swipe actions: a full swipe would otherwise
                            // play the row-removal animation before the
                            // confirmation dialog appears, then snap back.
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteRoutine = routine
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    renameDraft = displayName(for: routine, index: index)
                                    renameTarget = routine
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                        }
                        .onMove { source, destination in
                            Task { await moveRoutines(from: source, to: destination) }
                        }
                    }
                    .listStyle(.plain)
                    // Breathing room between the large title and the first
                    // row — `.plain` otherwise butts content right up
                    // against it with no gap at all.
                    .contentMargins(.top, 24, for: .scrollContent)
                    .refreshable { await load() }
                }
            }
            // A real large title ("Routines"), Apple Notes-style (its main
            // list shows "All iCloud" the same way) — previously no title
            // at all, just the avatar button, which read as unfinished/
            // nameless compared to Notes' own big bold heading. The avatar
            // still sits in the slim bar above it; a large title and a
            // leading toolbar item don't compete for space, they stack.
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { AccountAvatarButton() }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(AppRoute.exerciseLibrary)
                    } label: {
                        Image(systemName: "dumbbell")
                    }
                    .accessibilityLabel("Exercises")
                }
                if !routines.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .routine(let id):
                    RoutineDetailView(routineId: id, addExerciseTrigger: $addExerciseTrigger)
                        .onAppear { isRoutineDetailActive = true }
                        .onDisappear { isRoutineDetailActive = false }
                case .exercise(let id): ExerciseDetailView(exerciseId: id)
                case .workoutSession(let routineId, let startIndex):
                    WorkoutSessionView(routineId: routineId, startIndex: startIndex)
                        .onAppear {
                            isRoutineDetailActive = false
                            isWorkoutSessionActive = true
                        }
                        .onDisappear { isWorkoutSessionActive = false }
                case .exerciseLibrary:
                    ExerciseLibraryView(createTrigger: $createExerciseTrigger)
                        .onAppear { isExerciseLibraryActive = true }
                        .onDisappear { isExerciseLibraryActive = false }
                }
            }
        }
        .task { await load() }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { Task { await load() } }
        }
        .onChange(of: createTrigger) { _, _ in
            Task { await createRoutine() }
        }
        .confirmationDialog(
            "Delete this routine? This cannot be undone.",
            isPresented: Binding(
                get: { pendingDeleteRoutine != nil },
                set: { if !$0 { pendingDeleteRoutine = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                destructiveActionTaken.toggle()
                if let routine = pendingDeleteRoutine { Task { await deleteRoutine(routine) } }
            }
        }
        .alert(
            "Rename Routine",
            isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )
        ) {
            TextField("Routine name", text: $renameDraft)
            Button("Save") {
                if let routine = renameTarget { Task { await renameRoutine(routine) } }
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        }
        .sensoryFeedback(.warning, trigger: destructiveActionTaken)
        .sensoryFeedback(.impact(weight: .light), trigger: savedTick)
        .errorAlert($errorMessage)
    }

    /// A routine's name IS its label now, not a separate "Routine A - Foo"
    /// pairing — new routines get a real "Routine A"/"Routine B"/... label
    /// at creation time (like Apple Notes' "New Folder"), immediately
    /// renamable. This positional fallback only still exists for legacy
    /// rows created before this change that have no label at all.
    private func displayName(for routine: Routine, index: Int) -> String {
        guard let label = routine.label, !label.isEmpty else { return RoutineLetter.forIndex(index) }
        return label
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            routines = try await SupabaseService.shared.fetchRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createRoutine() async {
        isCreating = true
        defer { isCreating = false }
        do {
            let id = try await SupabaseService.shared.createRoutine(label: RoutineLetter.forIndex(routines.count))
            routines = try await SupabaseService.shared.fetchRoutines()
            savedTick += 1
            path.append(AppRoute.routine(id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveRoutines(from source: IndexSet, to destination: Int) async {
        var reordered = routines
        reordered.move(fromOffsets: source, toOffset: destination)
        do {
            try await SupabaseService.shared.reorderRoutines(orderedIds: reordered.map { $0.id })
            routines = try await SupabaseService.shared.fetchRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRoutine(_ routine: Routine) async {
        do {
            try await SupabaseService.shared.deleteRoutine(id: routine.id)
            pendingDeleteRoutine = nil
            routines = try await SupabaseService.shared.fetchRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func renameRoutine(_ routine: Routine) async {
        let trimmed = renameDraft.trimmed
        do {
            try await SupabaseService.shared.updateRoutineLabel(id: routine.id, label: trimmed.isEmpty ? nil : trimmed)
            renameTarget = nil
            savedTick += 1
            routines = try await SupabaseService.shared.fetchRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// A routine row's content — just the title, with generous vertical
/// padding for a taller, easier tap target than a default list row.
///
/// Used to pair the title with a leading icon inside its own rounded,
/// tinted card — a carryover from when these were square grid tiles with
/// no native list behavior at all. Once this became a real `List` (swipe
/// actions, `EditButton` reorder, a system chevron), the icon (identical
/// on every row, so it never actually distinguished anything) and the
/// tinted-card look both increasingly fought what the row actually was: a
/// plain list row. Now it's title-only on the list's own background with a
/// standard divider beneath it, same as every other list already in the
/// app (Exercise Library, Routine Detail's exercise list, History) — no
/// manual trailing chevron either, since a `List` row with a
/// `NavigationLink` as its primary content draws its own disclosure
/// indicator; one drawn here too would double up.
private struct RoutineRow: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
    }
}
