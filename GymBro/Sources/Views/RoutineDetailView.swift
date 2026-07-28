import SwiftUI

/// Port of routines/[id]/page.tsx + RoutineView.tsx.
///
/// A single native List for both view and edit states, toggled by the
/// standard `EditButton()` — replacing the web's explicit up/down arrow
/// buttons with iOS drag-to-reorder/swipe-to-delete. This is a plain
/// browse/organize list — tapping a row (outside edit mode) pushes straight
/// to that exercise's full page (cues, history, editing). Actual logging
/// happens in `WorkoutSessionView`, reached via the "Start Workout" button:
/// a full-screen one-exercise-at-a-time flow with Prev/Next, because the
/// user only ever logs one exercise at a time and an inline accordion here
/// added scrolling/tapping without adding any benefit. (An earlier revision
/// of this screen had an inline accordion — see git history/
/// INLINE_LOGGING_HANDOFF.md — replaced after user feedback that it didn't
/// solve the actual complaint, plus a real bug where any NavigationLink
/// nested in a List row makes the *whole row* tappable-through to that link.)
struct RoutineDetailView: View {
    let routineId: UUID
    @Binding var addExerciseTrigger: Bool

    @State private var routine: RoutineDetail?
    @State private var routineIndex = 0
    @State private var allExercises: [Exercise] = []
    @State private var isLoading = true
    @State private var titleDraft = ""
    @State private var showDeleteConfirm = false
    @State private var showAddExercise = false
    @State private var pendingRemoveOffsets: IndexSet?
    @State private var errorMessage: String?

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
                            ForEach(routine.routineExercises) { entry in
                                exerciseRow(entry.exercise)
                            }
                            .onDelete { offsets in pendingRemoveOffsets = offsets }
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
                            ZStack {
                                NavigationLink(value: AppRoute.workoutSession(routineId: routineId, startIndex: 0)) {
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
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Routine Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        // No nav bar title at all — just the back chevron. The routine name
        // is the heading at the top of the list instead (see body), same
        // Apple Notes "open a folder" treatment as the account/settings
        // icons replacing "Gym Bro" on the routines list itself.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if routine != nil {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .confirmationDialog(
            "Delete this routine? This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await deleteRoutine() } }
        }
        .confirmationDialog(
            "Remove this exercise from the routine?",
            isPresented: Binding(
                get: { pendingRemoveOffsets != nil },
                set: { if !$0 { pendingRemoveOffsets = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let offsets = pendingRemoveOffsets, let routine {
                    Task { await removeExercises(at: offsets, routine: routine) }
                }
            }
        }
        .onChange(of: isEditing) { wasEditing, editing in
            if editing {
                titleDraft = routine.map(displayName) ?? ""
            } else if wasEditing {
                let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
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
        .onChange(of: addExerciseTrigger) { _, _ in
            // Refresh first in case an exercise was created elsewhere (e.g.
            // the Exercises tab) while this routine screen stayed mounted
            // in the background — cheap insurance against a stale
            // allExercises snapshot, even though this wasn't reproducible
            // as an actual bug.
            Task {
                await reload()
                showAddExercise = true
            }
        }
        .task { await load() }
        .errorAlert($errorMessage)
    }

    // Shows what's already logged today directly under the exercise name —
    // more informative than a bare checkmark (which only says "something
    // was logged," not what), and doubles as confirmation of what's about
    // to be saved without having to open the exercise.
    private func exerciseRow(_ exercise: ExerciseDetail) -> some View {
        NavigationLink(value: AppRoute.exercise(exercise.id)) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let log = todayLog(exercise), !log.setLogs.isEmpty {
                    Text(log.setsSummary)
                        .font(.caption)
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
            let label = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func removeExercises(at offsets: IndexSet, routine: RoutineDetail) async {
        let ids = offsets.map { routine.routineExercises[$0].id }
        do {
            for id in ids {
                try await SupabaseService.shared.removeExerciseFromRoutine(routineExerciseId: id)
            }
            pendingRemoveOffsets = nil
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
