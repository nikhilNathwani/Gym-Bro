import SwiftUI

/// Port of page.tsx (home / "/"). Root of the Routines tab's own
/// NavigationStack.
struct RoutinesListView: View {
    @Binding var createTrigger: Bool
    @Binding var addExerciseTrigger: Bool
    @Binding var isRoutineDetailActive: Bool
    @Binding var isWorkoutSessionActive: Bool

    @State private var path = NavigationPath()
    @State private var routines: [Routine] = []
    @State private var isLoading = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var pendingDeleteRoutine: Routine?
    @State private var renameTarget: Routine?
    @State private var renameDraft = ""

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
                    List {
                        ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                            NavigationLink(value: AppRoute.routine(routine.id)) {
                                HStack(spacing: 12) {
                                    Image(systemName: "list.bullet.clipboard")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 20, height: 20)
                                    Text(displayName(for: routine, index: index))
                                        .font(.headline)
                                        .lineLimit(1)
                                }
                            }
                            // This same panel is what appears when tapping
                            // the edit-mode "-" too (SwiftUI ties the two
                            // together — there's no way to give "-" a
                            // different, simpler reveal).
                            .swipeActions(edge: .trailing) {
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
                    .contentMargins(.top, 20, for: .scrollContent)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Placeholder auth entry point (Todoist-style) — not wired up yet.
                    Button {} label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(.systemGray4))
                                .frame(width: 28, height: 28)
                                .overlay {
                                    Text("N")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            Text("Nikhil")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
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
        .confirmationDialog(
            "Delete this routine? This cannot be undone.",
            isPresented: Binding(
                get: { pendingDeleteRoutine != nil },
                set: { if !$0 { pendingDeleteRoutine = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
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
        let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await SupabaseService.shared.updateRoutineLabel(id: routine.id, label: trimmed.isEmpty ? nil : trimmed)
            renameTarget = nil
            routines = try await SupabaseService.shared.fetchRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
