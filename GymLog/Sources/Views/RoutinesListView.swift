import SwiftUI

/// Port of page.tsx (home / "/"). Root of the Routines tab's own
/// NavigationStack.
struct RoutinesListView: View {
    @Binding var createTrigger: Bool
    @Binding var addExerciseTrigger: Bool
    @Binding var isRoutineDetailActive: Bool
    @Binding var isWorkoutSessionActive: Bool
    @Binding var popToRootTrigger: Bool

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
                                RoutineCard(title: displayName(for: routine, index: index))
                            }
                            .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
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
                    .refreshable { await load() }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { AccountAvatarButton() }
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
        .onChange(of: popToRootTrigger) { _, _ in path = NavigationPath() }
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

/// A routine's tap target: a wide row spanning the full screen width, taller
/// than a plain list row — big and thumb-friendly (like the grid tile this
/// replaced) but reachable without moving a finger all the way to one
/// corner, since the whole row's width is live, not just a square in a
/// column. No manual trailing chevron — this is now a real `List` row with
/// a `NavigationLink` as its primary content, so the system draws its own
/// disclosure indicator; one drawn here too would double up.
private struct RoutineCard: View {
    let title: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
