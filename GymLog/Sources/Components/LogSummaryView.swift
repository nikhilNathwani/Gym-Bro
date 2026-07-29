import SwiftUI

private let logDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d/yy"
    return formatter
}()

/// Port of LogSummary.tsx.
struct LogSummaryView: View {
    let log: ExerciseLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let notes = log.notes, !notes.isEmpty {
                row(label: logDateFormatter.string(from: log.createdAt), value: notes, lineLimit: 1)
            }
            if !log.setLogs.isEmpty {
                row(
                    label: "Reps",
                    value: log.setLogs.map { $0.reps.map { String($0) } ?? "—" }.joined(separator: ", "))
                row(
                    label: "Weight",
                    value: log.setLogs.map { $0.weight.map(formatNumber) ?? "—" }.joined(separator: ", "))
            }
        }
        .font(.subheadline)
    }

    private func row(label: String, value: String, lineLimit: Int? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
    }
}
