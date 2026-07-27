import SwiftUI

/// Port of AssignExercisePicker.tsx: inline search + "Add"/"Create" panel,
/// always visible at the bottom of a routine (both view and edit modes).
struct AssignExercisePickerView: View {
    let routineId: UUID
    let unassignedExercises: [Exercise]
    let onChanged: () async -> Void
    let onError: (String) -> Void

    @State private var query = ""
    @State private var isBusy = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var filtered: [Exercise] {
        guard !trimmed.isEmpty else { return [] }
        return unassignedExercises.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var hasExactMatch: Bool {
        filtered.contains { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("+ Add exercise")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.foreground)

            TextField("Search or create an exercise…", text: $query)
                .padding(10)
                .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))

            if !trimmed.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, exercise in
                        if index > 0 {
                            Rectangle().fill(Theme.foreground).frame(height: 1)
                        }
                        resultRow(title: exercise.name, actionLabel: "Add") {
                            await add(exercise)
                        }
                    }
                    if !hasExactMatch {
                        if !filtered.isEmpty {
                            Rectangle().fill(Theme.foreground).frame(height: 1)
                        }
                        resultRow(title: "Create “\(trimmed)”", actionLabel: "Create") {
                            await create()
                        }
                    }
                }
                .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
            }
        }
        .disabled(isBusy)
    }

    private func resultRow(title: String, actionLabel: String, action: @escaping () async -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 14))
            Spacer()
            Button {
                Task { await action() }
            } label: {
                Text(actionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(BorderedRowButtonStyle())
        }
        .padding(10)
    }

    private func add(_ exercise: Exercise) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await SupabaseService.shared.addExerciseToRoutine(routineId: routineId, exerciseId: exercise.id)
            query = ""
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func create() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await SupabaseService.shared.createExercise(name: trimmed, routineId: routineId)
            query = ""
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }
}
