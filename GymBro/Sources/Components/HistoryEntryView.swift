import SwiftUI

/// Port of HistoryEntry.tsx: view/edit toggle per logged session, delete via
/// confirmationDialog (native replacement for the web's `confirm()`).
struct HistoryEntryView: View {
    let log: ExerciseLog
    let canEdit: Bool
    let onChanged: () async -> Void
    let onError: (String) -> Void

    @State private var isEditing = false
    @State private var isSaving = false
    @State private var weightText = ""
    @State private var repsText = ""
    @State private var notes = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !canEdit || !isEditing {
                if canEdit {
                    HStack(spacing: 16) {
                        Spacer()
                        Button("Edit") { beginEditing() }
                        Button("Delete", role: .destructive) { showDeleteConfirm = true }
                    }
                    .font(.subheadline)
                }
                LogSummaryView(log: log)
            } else {
                SetFieldsEditor(weightText: $weightText, repsText: $repsText)

                TextField("Notes — how did it feel?", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Button {
                        Task { await save() }
                    } label: {
                        Text(isSaving ? "Saving…" : "Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)

                    Button {
                        isEditing = false
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .confirmationDialog(
            "Delete this logged session? This cannot be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { Task { await delete() } }
        }
    }

    private func beginEditing() {
        weightText = log.setLogs.map { $0.weight.map(formatNumber) ?? "" }.joined(separator: ",")
        repsText = log.setLogs.map { $0.reps.map { String($0) } ?? "" }.joined(separator: ",")
        notes = log.notes ?? ""
        isEditing = true
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let weights = SetFieldsParsing.splitCommaList(weightText).map(SetFieldsParsing.parseDoubleOrNil)
            let reps = SetFieldsParsing.splitCommaList(repsText).map(SetFieldsParsing.parseIntOrNil)
            try await SupabaseService.shared.updateLogEntry(
                exerciseLogId: log.id,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                weights: weights,
                reps: reps
            )
            isEditing = false
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func delete() async {
        do {
            try await SupabaseService.shared.deleteLogEntry(id: log.id)
            await onChanged()
        } catch {
            onError(error.localizedDescription)
        }
    }
}
