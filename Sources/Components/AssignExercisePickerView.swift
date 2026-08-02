import SwiftUI

/// Port of AssignExercisePicker.tsx: inline search + "Add"/"Create" panel,
/// always visible at the bottom of a routine (both view and edit modes).
/// Rendered inside a List Section, so its rows use plain List-row styling
/// rather than a custom bordered box.
struct AssignExercisePickerView: View {
    let routineId: UUID
    let unassignedExercises: [Exercise]
    let onChanged: () async -> Void
    let onCreated: (UUID) -> Void
    let onError: (String) -> Void
    var autofocus: Bool = false

    @State private var query = ""
    @State private var isBusy = false
    @State private var addedTick = 0
    @FocusState private var isFocused: Bool

    private var trimmed: String { query.trimmed }

    private var filtered: [Exercise] {
        guard !trimmed.isEmpty else { return [] }
        return unassignedExercises.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var hasExactMatch: Bool {
        filtered.contains { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        Group {
            TextField("Search or create an exercise…", text: $query)
                .focused($isFocused)
                .onAppear { if autofocus { isFocused = true } }

            ForEach(filtered) { exercise in
                resultRow(title: exercise.name, actionLabel: "Add") {
                    await add(exercise)
                }
            }
            if !trimmed.isEmpty && !hasExactMatch {
                resultRow(title: "Create “\(trimmed)”", actionLabel: "Create") {
                    await create()
                }
            }
        }
        .disabled(isBusy)
        .sensoryFeedback(.impact(weight: .light), trigger: addedTick)
    }

    private func resultRow(title: String, actionLabel: String, action: @escaping () async -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(actionLabel) { Task { await action() } }
                .buttonStyle(.bordered)
        }
    }

    private func add(_ exercise: Exercise) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await SupabaseService.shared.addExerciseToRoutine(routineId: routineId, exerciseId: exercise.id)
            query = ""
            addedTick += 1
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func create() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let id = try await SupabaseService.shared.createExercise(name: trimmed, routineId: routineId)
            query = ""
            addedTick += 1
            await onChanged()
            onCreated(id)
        } catch {
            onError(error.localizedDescription)
        }
    }
}
