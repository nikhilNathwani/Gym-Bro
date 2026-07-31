import SwiftUI

/// Port of routines/[id]/page.tsx + RoutineView.tsx.
///
/// A single native List for both view and edit states, toggled by the
/// standard `EditButton()` — replacing the web's explicit up/down arrow
/// buttons with iOS drag-to-reorder/swipe-to-delete. Tapping a row (outside
/// edit mode) pushes straight into `WorkoutSessionView` at that exercise's
/// position, not the full exercise-detail/edit page — this list exists in a
/// "workout" context (it's the screen "Start Workout" lives on), so tapping
/// an exercise should mean "let me log this one," not "let me edit its
/// name/cues." The full edit page is still reachable via "Open full
/// exercise page" from within the workout flow, or from the Exercises tab.
/// (An earlier revision of this screen had an inline accordion — see git
/// history/INLINE_LOGGING_HANDOFF.md — replaced after user feedback that it
/// didn't solve the actual complaint, plus a real bug where any
/// NavigationLink nested in a List row makes the *whole row*
/// tappable-through to that link.)
struct RoutineDetailView: View {
    let routineId: UUID

    @State private var routine: RoutineDetail?
    @State private var routineIndex = 0
    @State private var allExercises: [Exercise] = []
    @State private var isLoading = true
    @State private var titleDraft = ""
    @State private var showDeleteConfirm = false
    @State private var showAddExercise = false
    @State private var pendingRemoveExercise: RoutineExercise?
    @State private var errorMessage: String?
    @State private var destructiveActionTaken = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.editMode) private var editMode

    private var isEditing: Bool { editMode?.wrappedValue.isEditing ?? false }

    var body: some View {
        Group {
            if let routine {
                List {
                    // Apple Notes-style: no nav bar title, just the back
                    // chevron — the routine's name is this heading instead.
                    // Outside Edit mode it's plain text sitting directly on
                    // the page background, like a real page title; only in
                    // Edit mode does it become a boxed, editable field.
                    Section {
                        if isEditing {
                            TextField("Routine name", text: $titleDraft)
                                .font(.title2.bold())
                        } else {
                            Text(displayName(routine))
                                .font(.title2.bold())
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                    .listRowSeparator(.hidden)

                    Section("Exercises") {
                        if routine.routineExercises.isEmpty {
                            Text("No exercises yet — tap + to add one.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(routine.routineExercises.enumerated()), id: \.element.id) { index, entry in
                                exerciseRow(entry.exercise, startIndex: index)
                                    // `.swipeActions` with `allowsFullSwipe: false`,
                                    // not `.onDelete` — `.onDelete`'s default swipe
                                    // is a full swipe by default, which plays
                                    // List's optimistic delete-and-collapse
                                    // animation immediately, before this
                                    // confirmation dialog even appears; since the
                                    // actual removal doesn't happen until the
                                    // dialog is confirmed, the row then snaps back
                                    // (same bug fixed in `HistoryEntryView`).
                                    // Costs the Edit-mode leading minus-circle
                                    // affordance `.onDelete` would have added, but
                                    // swipe-to-remove still works both in and out
                                    // of Edit mode.
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) { pendingRemoveExercise = entry } label: {
                                            Label("Remove", systemImage: "trash")
                                        }
                                    }
                            }
                            .onMove { source, destination in
                                Task { await moveExercises(from: source, to: destination, routine: routine) }
                            }
                        }
                    }

                    if !routine.routineExercises.isEmpty && !isEditing {
                        Section {
                            // The visible content is a plain Label, not a
                            // NavigationLink's own label — List only draws
                            // the automatic trailing chevron for a row whose
                            // *primary* content is a NavigationLink, so an
                            // empty-label NavigationLink pushing the same
                            // destination, layered underneath, still
                            // navigates without that disclosure indicator.
                            //
                            // Deliberately no extra tap gesture here for
                            // haptic feedback (tried `.simultaneousGesture`
                            // layered on top to fire one) — it broke the
                            // invisible NavigationLink's own tap recognition
                            // outright, silently leaving the app on this
                            // same screen instead of navigating. This
                            // ZStack/opacity trick is already a delicate
                            // workaround; not worth compounding the fragility
                            // for a cosmetic haptic on what's still, at its
                            // core, a plain navigation push.
                            ZStack {
                                NavigationLink(
                                    value: AppRoute.workoutSession(
                                        routineId: routineId, startIndex: continueStartIndex(routine))
                                ) {
                                    EmptyView()
                                }
                                .opacity(0)

                                Label(
                                    hasLoggedToday(routine) ? "Continue Workout" : "Start Workout",
                                    systemImage: "play.fill"
                                )
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowBackground(Color.accentColor)
                        .foregroundStyle(.white)
                    }

                    if isEditing {
                        Section {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Text("Delete this routine")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }
                }
                .refreshable { await reload() }
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Routine Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        // No nav bar title at all — just the back chevron. The routine name
        // is the heading at the top of the list instead (see body), same
        // Apple Notes "open a folder" treatment as the account/settings
        // icons replacing "Gym Log" on the routines list itself.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if routine != nil {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // Refresh first in case an exercise was created
                        // elsewhere (e.g. the Exercises tab) while this
                        // routine screen stayed mounted in the background —
                        // cheap insurance against a stale allExercises
                        // snapshot, even though this wasn't reproducible as
                        // an actual bug.
                        Task {
                            await reload()
                            showAddExercise = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Exercise")
                }
            }
        }
        .confirmationDialog(
            "Delete this routine? This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                destructiveActionTaken.toggle()
                Task { await deleteRoutine() }
            }
        }
        .confirmationDialog(
            "Remove this exercise from the routine?",
            isPresented: Binding(
                get: { pendingRemoveExercise != nil },
                set: { if !$0 { pendingRemoveExercise = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                destructiveActionTaken.toggle()
                if let entry = pendingRemoveExercise {
                    Task { await removeExercise(entry) }
                }
            }
        }
        .sensoryFeedback(.warning, trigger: destructiveActionTaken)
        .onChange(of: isEditing) { wasEditing, editing in
            if editing {
                titleDraft = routine.map(displayName) ?? ""
            } else if wasEditing {
                let trimmed = titleDraft.trimmed
                if trimmed != (routine?.label ?? "") {
                    Task { await saveLabel() }
                }
            }
        }
        .sheet(isPresented: $showAddExercise) {
            if let routine {
                AddExerciseToRoutineSheet(
                    routineId: routineId,
                    unassignedExercises: unassignedExercises(routine),
                    onChanged: { await reload() },
                    onError: { errorMessage = $0 }
                )
            }
        }
        .task { await load() }
        .errorAlert($errorMessage)
    }

    // Shows what's already logged today directly under the exercise name —
    // more informative than a bare checkmark (which only says "something
    // was logged," not what), and doubles as confirmation of what's about
    // to be saved without having to open the exercise. Tapping the row
    // jumps straight into the workout flow at this exercise's position
    // (not the full edit page — see the type doc comment above).
    private func exerciseRow(_ exercise: ExerciseDetail, startIndex: Int) -> some View {
        NavigationLink(value: AppRoute.workoutSession(routineId: routineId, startIndex: startIndex)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(startIndex + 1). \(exercise.name)")
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let log = todayLog(exercise), !log.setLogs.isEmpty {
                    Text(log.setsSummary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Data

    /// A routine's name is its label now, not a separate "Routine A" +
    /// label pairing (see RoutinesListView.displayName) — this positional
    /// fallback only matters for legacy rows with no label at all.
    private func displayName(_ routine: RoutineDetail) -> String {
        guard let label = routine.label, !label.isEmpty else { return RoutineLetter.forIndex(routineIndex) }
        return label
    }

    private func unassignedExercises(_ routine: RoutineDetail) -> [Exercise] {
        let assignedIds = Set(routine.routineExercises.map { $0.exercise.id })
        return allExercises.filter { !assignedIds.contains($0.id) }
    }

    private func todayLog(_ exercise: ExerciseDetail) -> ExerciseLog? {
        exercise.exerciseLogs.first { Calendar.current.isDateInToday($0.createdAt) }
    }

    private func hasLoggedToday(_ routine: RoutineDetail) -> Bool {
        routine.routineExercises.contains { todayLog($0.exercise)?.setLogs.isEmpty == false }
    }

    /// Where "Continue Workout" should resume: the *last* exercise (by
    /// routine order) with any sets logged today, not always index 0 and
    /// not the first exercise with zero sets. Landing on the last-touched
    /// exercise rather than skipping past it matters because a set count
    /// here doesn't mean "finished" — there's no tracked target-vs-actual
    /// completion, so an exercise with 2 of a planned 4 sets logged looks
    /// identical to one that's fully done. Re-opening it (rather than
    /// jumping to the next untouched exercise) costs at most one "Next"
    /// tap if it really was finished, but never skips past one still in
    /// progress — the worse failure mode, e.g. resuming after a mid-set
    /// rest with the phone put away. Falls back to 0 (the start) if
    /// nothing's logged yet today.
    private func continueStartIndex(_ routine: RoutineDetail) -> Int {
        let lastLoggedIndex = routine.routineExercises.lastIndex {
            todayLog($0.exercise)?.setLogs.isEmpty == false
        }
        return lastLoggedIndex ?? 0
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let detail = SupabaseService.shared.fetchRoutineDetail(id: routineId)
            async let routines = SupabaseService.shared.fetchRoutines()
            async let exercises = SupabaseService.shared.fetchExercises()
            let (detailResult, routinesResult, exercisesResult) = try await (detail, routines, exercises)
            guard let detailResult else {
                errorMessage = "Routine not found"
                return
            }
            routine = detailResult
            routineIndex = routinesResult.firstIndex(where: { $0.id == routineId }) ?? 0
            allExercises = exercisesResult
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() async {
        do {
            if let detail = try await SupabaseService.shared.fetchRoutineDetail(id: routineId) {
                routine = detail
            }
            allExercises = try await SupabaseService.shared.fetchExercises()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLabel() async {
        do {
            let label = titleDraft.trimmed
            try await SupabaseService.shared.updateRoutineLabel(id: routineId, label: label.isEmpty ? nil : label)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteRoutine() async {
        do {
            try await SupabaseService.shared.deleteRoutine(id: routineId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeExercise(_ entry: RoutineExercise) async {
        do {
            try await SupabaseService.shared.removeExerciseFromRoutine(routineExerciseId: entry.id)
            pendingRemoveExercise = nil
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int, routine: RoutineDetail) async {
        var reordered = routine.routineExercises
        reordered.move(fromOffsets: source, toOffset: destination)
        do {
            try await SupabaseService.shared.reorderRoutineExercises(orderedIds: reordered.map { $0.id })
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
