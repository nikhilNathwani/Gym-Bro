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
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(Array(routines.enumerated()), id: \.element.id) { index, routine in
                                NavigationLink(value: AppRoute.routine(routine.id)) {
                                    RoutineCard(title: displayName(for: routine, index: index))
                                }
                                .buttonStyle(.plain)
                                // Long-press replaces the old swipe actions — a
                                // grid of cards has no natural "swipe" edge the
                                // way list rows do.
                                .contextMenu {
                                    Button {
                                        renameDraft = displayName(for: routine, index: index)
                                        renameTarget = routine
                                    } label: {
                                        Label("Rename", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        pendingDeleteRoutine = routine
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                // Drag-to-reorder replaces the old EditButton +
                                // onMove — there's no list edit mode in a grid,
                                // so cards reorder the same way home-screen
                                // icons do: drag one onto another's spot.
                                .draggable(routine.id.uuidString)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let uuidString = items.first,
                                          let sourceId = UUID(uuidString: uuidString),
                                          let sourceIndex = routines.firstIndex(where: { $0.id == sourceId }),
                                          let destIndex = routines.firstIndex(where: { $0.id == routine.id }),
                                          sourceIndex != destIndex
                                    else { return false }
                                    Task { await moveRoutines(sourceIndex: sourceIndex, destIndex: destIndex) }
                                    return true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
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

    private func moveRoutines(sourceIndex: Int, destIndex: Int) async {
        var reordered = routines
        let moved = reordered.remove(at: sourceIndex)
        reordered.insert(moved, at: destIndex)
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

/// A routine's grid tile: a big, thumb-friendly tap target (vs. the old
/// narrow list row) sized after Reminders'/Notes' folder-grid cards.
private struct RoutineCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "list.bullet.clipboard.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}
