import SwiftUI

/// Port of routines/[id]/page.tsx + RoutineView.tsx.
///
/// View mode is a ScrollView of AccordionCards (matches the web's expand/
/// scroll-into-view accordion). Edit mode swaps to a native List with
/// onDelete/onMove — replacing the web's explicit up/down arrow buttons with
/// standard iOS drag-to-reorder and swipe-to-delete.
struct RoutineDetailView: View {
    let routineId: UUID

    @State private var routine: RoutineDetail?
    @State private var routineIndex = 0
    @State private var allExercises: [Exercise] = []
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var titleDraft = ""
    @State private var expandedExerciseId: UUID?
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let routine {
                if isEditing {
                    editingLayout(routine)
                } else {
                    viewingLayout(routine)
                }
            } else if isLoading {
                ProgressView()
            } else {
                Text("Routine not found")
                    .foregroundColor(Theme.foreground)
            }
        }
        .navigationTitle(routine.map { title(for: $0) } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if routine != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") { toggleEditing() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete Routine", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this routine? This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await deleteRoutine() } }
        }
        .task { await load() }
        .errorAlert($errorMessage)
    }

    // MARK: - View mode

    private func viewingLayout(_ routine: RoutineDetail) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    exerciseAccordionList(routine)
                    AssignExercisePickerView(
                        routineId: routineId,
                        unassignedExercises: unassignedExercises(routine),
                        onChanged: { await reload() },
                        onError: { errorMessage = $0 }
                    )
                }
                .padding(16)
            }
            .onChange(of: expandedExerciseId) { _, newValue in
                guard let id = newValue else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
        .background(Theme.background)
    }

    private func exerciseAccordionList(_ routine: RoutineDetail) -> some View {
        VStack(spacing: 12) {
            if routine.routineExercises.isEmpty {
                Text("No exercises yet — add one below.")
                    .foregroundColor(Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(routine.routineExercises) { entry in
                    let exercise = entry.exercise
                    AccordionCard(
                        isExpanded: expandedExerciseId == exercise.id,
                        onToggle: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                expandedExerciseId = (expandedExerciseId == exercise.id) ? nil : exercise.id
                            }
                        },
                        header: {
                            Text(exercise.name).font(.system(size: 17, weight: .medium))
                        },
                        content: {
                            exerciseCardContent(exercise)
                        }
                    )
                    .id(exercise.id)
                }
            }
        }
    }

    private func exerciseCardContent(_ exercise: ExerciseDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink(value: AppRoute.exercise(exercise.id)) {
                Text("Open full exercise page")
                    .font(.system(size: 12))
                    .underline()
                    .foregroundColor(Theme.foreground)
            }

            if let subtitle = exercise.subtitle, !subtitle.isEmpty {
                (Text("Target: ").fontWeight(.medium) + Text(subtitle))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.foreground)
            }

            if let cues = exercise.cues, !cues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cues").font(.system(size: 14, weight: .medium))
                    ScrollView {
                        Text(cues)
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 118)
                    .padding(8)
                    .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
                }
                .foregroundColor(Theme.foreground)
            }

            if let lastLog = exercise.exerciseLogs.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last logged").font(.system(size: 14, weight: .medium))
                    LogSummaryView(log: lastLog)
                }
                .foregroundColor(Theme.foreground)
            }

            LogEntryFormView(
                exerciseId: exercise.id,
                previousSets: exercise.exerciseLogs.first?.setLogs ?? [],
                onLogged: { await reload() },
                onError: { errorMessage = $0 }
            )
        }
    }

    // MARK: - Edit mode

    private func editingLayout(_ routine: RoutineDetail) -> some View {
        List {
            Section("Title") {
                TextField("e.g. Vertical Push/Pull", text: $titleDraft)
                Button("Save") { Task { await saveLabel() } }
            }

            Section("Exercises") {
                if routine.routineExercises.isEmpty {
                    Text("No exercises yet.").foregroundColor(.secondary)
                } else {
                    ForEach(routine.routineExercises) { entry in
                        Text(entry.exercise.name)
                    }
                    .onDelete { offsets in Task { await removeExercises(at: offsets, routine: routine) } }
                    .onMove { source, destination in
                        Task { await moveExercises(from: source, to: destination, routine: routine) }
                    }
                }
            }

            Section("Add exercise") {
                AssignExercisePickerView(
                    routineId: routineId,
                    unassignedExercises: unassignedExercises(routine),
                    onChanged: { await reload() },
                    onError: { errorMessage = $0 }
                )
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Data

    private func title(for routine: RoutineDetail) -> String {
        let letter = RoutineLetter.forIndex(routineIndex)
        guard let label = routine.label, !label.isEmpty else { return letter }
        return "\(letter) - \(label)"
    }

    private func unassignedExercises(_ routine: RoutineDetail) -> [Exercise] {
        let assignedIds = Set(routine.routineExercises.map { $0.exercise.id })
        return allExercises.filter { !assignedIds.contains($0.id) }
    }

    private func toggleEditing() {
        isEditing.toggle()
        expandedExerciseId = nil
        if isEditing { titleDraft = routine?.label ?? "" }
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
