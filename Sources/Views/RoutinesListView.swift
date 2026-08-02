import SwiftUI

/// Port of page.tsx (home / "/"). The app's single root screen (hosted
/// directly by `GymLogApp`'s `WindowGroup`) — also owns the one shared
/// `NavigationStack`, including the push into `ExerciseLibraryView` via the
/// toolbar icon below, so its `navigationDestination` declarations cover
/// every route in the app.
///
/// Each pushed screen owns its own "add" action now (Routines here,
/// Exercises in `ExerciseLibraryView`, "Add Exercise" in
/// `RoutineDetailView`) rather than a single shared floating "+" hoisted up
/// to a former `RootView` shell — that FAB deliberately ignored the
/// keyboard safe area so it wouldn't drift when a normal text field
/// focused, which broke once iOS 26's `.searchable()` started docking its
/// own floating search field in that same bottom-right corner: the FAB's
/// higher z-order sat on top of the search field's clear button and ate
/// the tap. A per-screen nav-bar button can't overlap floating content at
/// all, since it isn't in the same coordinate space — removes the whole
/// class of bug instead of patching this one instance of it.
///
/// Here specifically, Edit and Add Routine share one trailing "•••" menu
/// rather than each being its own icon — a lone floating "+" reads fine,
/// but next to the existing dumbbell icon and an EditButton it made three
/// trailing icons on a large-title screen, which read as cluttered. Add
/// Routine is also a rare action once a program is actually set up, so it
/// doesn't need to be as reachable as it was as a provisional floating "+".
struct RoutinesListView: View {
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

    @Environment(\.editMode) private var editMode

    private var isEditing: Bool { editMode?.wrappedValue.isEditing ?? false }

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
                                RoutineRow(
                                    title: displayName(for: routine, index: index),
                                    subtitle: lastPerformedText(for: routine)
                                )
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
                    // Small breathing room between the large title and the
                    // first row — `.plain` otherwise butts content right up
                    // against it with almost no gap. Kept deliberately
                    // modest: the space *above* the title (between it and
                    // the compact toolbar row) is the system's own large-
                    // title spacing, not adjustable via public API without
                    // replacing the native title entirely — so a small
                    // value here keeps the title reading like it belongs
                    // with what's above it, rather than overcorrecting
                    // with a big gap below that then needs shrinking back.
                    .contentMargins(.top, 8, for: .scrollContent)
                    .refreshable { await load() }
                }
            }
            // A real large title ("Routines"), Apple Notes-style (its main
            // list shows "All iCloud" the same way) — previously no title
            // at all, just the placeholder avatar button, which read as
            // unfinished/nameless compared to Notes' own big bold heading.
            .navigationTitle("Routines")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(AppRoute.exerciseLibrary)
                    } label: {
                        Image(systemName: "dumbbell")
                    }
                    .accessibilityLabel("Exercises")
                }
                // Edit and Add Routine combined into one menu rather than
                // two more standalone icons — three trailing icons (this
                // plus the dumbbell above) read as cluttered for a large-
                // title screen, and "Add Routine" in particular is a rare
                // action once a program is actually set up, so it doesn't
                // need its own always-visible button the way it did as a
                // provisional floating "+".
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if !routines.isEmpty {
                            Button {
                                editMode?.wrappedValue = isEditing ? .inactive : .active
                            } label: {
                                Label(isEditing ? "Done" : "Edit", systemImage: isEditing ? "checkmark" : "pencil")
                            }
                        }
                        Button {
                            Task { await createRoutine() }
                        } label: {
                            Label("Add Routine", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .routine(let id):
                    RoutineDetailView(routineId: id, path: $path)
                case .exercise(let id): ExerciseDetailView(exerciseId: id)
                case .workoutSession(let routineId, let startIndex):
                    WorkoutSessionView(routineId: routineId, startIndex: startIndex)
                case .exerciseLibrary:
                    ExerciseLibraryView(path: $path)
                }
            }
        }
        .task { await load() }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { Task { await load() } }
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

    private static let lastPerformedFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// `nil` for a routine with no logged session yet (e.g. a freshly
    /// created one, or one you haven't gotten around to) — no subtitle at
    /// all reads better here than a naggy "Never logged."
    private func lastPerformedText(for routine: Routine) -> String? {
        guard let date = routine.lastPerformedAt else { return nil }
        return "Last done \(Self.lastPerformedFormatter.localizedString(for: date, relativeTo: Date()))"
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

/// A routine row's content — title plus an optional "Last done …"
/// subtitle, with generous vertical padding for a taller, easier tap
/// target than a default list row.
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
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if let subtitle {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }
}
