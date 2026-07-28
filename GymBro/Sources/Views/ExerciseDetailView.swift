import SwiftUI

/// Port of exercises/[id]/page.tsx + ExerciseView.tsx and its Editable*
/// subcomponents. Back navigation is the native NavigationStack back button —
/// the web's custom "back href + label" query-string plumbing isn't needed
/// since the stack already knows where you came from.
struct ExerciseDetailView: View {
    let exerciseId: UUID

    @State private var exercise: ExerciseDetail?
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var nameDraft = ""
    @State private var targetDraft = ""
    @State private var cuesDraft = ""
    @State private var isCuesCollapsed = false
    @State private var isCuesTextEditing = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    @FocusState private var isNameFocused: Bool
    @FocusState private var isTargetFocused: Bool
    @FocusState private var isCuesFocused: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let exercise {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        nameField
                        targetField(exercise)
                        cuesSection(exercise)
                        historySection(exercise)
                        LogEntryFormView(
                            exerciseId: exerciseId,
                            previousSets: exercise.exerciseLogs.first?.setLogs ?? [],
                            onLogged: { await reload() },
                            onError: { errorMessage = $0 }
                        )
                    }
                    .padding(16)
                }
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Exercise Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if exercise != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") { toggleEditing() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete Exercise", role: .destructive) { showDeleteConfirm = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this exercise? This removes it from every routine and deletes its log history. This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await deleteExercise() } }
        }
        .task { await load() }
        .onDisappear { flushPendingEdits() }
        .errorAlert($errorMessage)
    }

    // MARK: - Sections

    private var nameField: some View {
        TextField("Exercise name", text: $nameDraft)
            .font(.largeTitle.bold())
            .focused($isNameFocused)
            .onChange(of: isNameFocused) { wasFocused, isFocused in
                if wasFocused && !isFocused { Task { await saveName() } }
            }
    }

    private func targetField(_ exercise: ExerciseDetail) -> some View {
        Group {
            if isEditing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target").font(.headline)
                    TextField("e.g. 3 sets × 6–10 reps", text: $targetDraft)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTargetFocused)
                        .onChange(of: isTargetFocused) { wasFocused, isFocused in
                            if wasFocused && !isFocused { Task { await saveTarget() } }
                        }
                }
            } else if let subtitle = exercise.subtitle, !subtitle.isEmpty {
                (Text("Target: ").fontWeight(.medium) + Text(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cuesSection(_ exercise: ExerciseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cues").font(.headline)
                Spacer()
                HStack(spacing: 16) {
                    if isEditing && !isCuesCollapsed {
                        Button(isCuesTextEditing ? "Done" : "Edit") {
                            if isCuesTextEditing {
                                Task { await saveCues() }
                            } else {
                                cuesDraft = exercise.cues ?? ""
                            }
                            isCuesTextEditing.toggle()
                        }
                    }
                    Button(isCuesCollapsed ? "Show" : "Hide") {
                        isCuesCollapsed.toggle()
                    }
                }
                .font(.subheadline)
            }

            if !isCuesCollapsed {
                if isEditing && isCuesTextEditing {
                    TextEditor(text: $cuesDraft)
                        .frame(minHeight: 100, maxHeight: 158)
                        .padding(6)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .focused($isCuesFocused)
                        .onChange(of: isCuesFocused) { wasFocused, isFocused in
                            if wasFocused && !isFocused { Task { await saveCues() } }
                        }
                } else if let cues = exercise.cues, !cues.isEmpty {
                    ScrollView {
                        Text(cues)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 158)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(isEditing ? "No cues yet — tap Edit to add some." : "No cues yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func historySection(_ exercise: ExerciseDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History").font(.headline)
            if exercise.exerciseLogs.isEmpty {
                Text("No logged sessions yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exercise.exerciseLogs) { log in
                    HistoryEntryView(
                        log: log,
                        canEdit: isEditing,
                        onChanged: { await reload() },
                        onError: { errorMessage = $0 }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleEditing() {
        isEditing.toggle()
        if !isEditing { isCuesTextEditing = false }
    }

    /// Safety net for navigating away (e.g. tapping the back button) while a
    /// field is still focused: the focus-loss save in each field's
    /// `onChange(of:)` may not fire before teardown, so flush anything still
    /// dirty relative to the last-loaded value.
    private func flushPendingEdits() {
        guard let exercise else { return }
        if nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) != exercise.name {
            Task { await saveName() }
        }
        if targetDraft.trimmingCharacters(in: .whitespacesAndNewlines) != (exercise.subtitle ?? "") {
            Task { await saveTarget() }
        }
        if isCuesTextEditing, cuesDraft != (exercise.cues ?? "") {
            Task { await saveCues() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let detail = try await SupabaseService.shared.fetchExerciseDetail(id: exerciseId) else {
                errorMessage = "Exercise not found"
                return
            }
            exercise = detail
            nameDraft = detail.name
            targetDraft = detail.subtitle ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() async {
        do {
            if let detail = try await SupabaseService.shared.fetchExerciseDetail(id: exerciseId) {
                exercise = detail
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveName() async {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameDraft = exercise?.name ?? ""
            return
        }
        do {
            try await SupabaseService.shared.updateExerciseName(id: exerciseId, name: trimmed)
            exercise?.name = trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveTarget() async {
        do {
            let trimmed = targetDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            try await SupabaseService.shared.updateExerciseSubtitle(
                id: exerciseId, subtitle: trimmed.isEmpty ? nil : trimmed)
            exercise?.subtitle = trimmed.isEmpty ? nil : trimmed
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveCues() async {
        do {
            let trimmed = cuesDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            try await SupabaseService.shared.updateCues(
                exerciseId: exerciseId, cues: trimmed.isEmpty ? nil : cuesDraft)
            exercise?.cues = trimmed.isEmpty ? nil : cuesDraft
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteExercise() async {
        do {
            try await SupabaseService.shared.deleteExercise(id: exerciseId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
