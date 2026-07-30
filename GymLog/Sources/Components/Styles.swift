import SwiftUI

extension View {
    /// Standard error alert bound to an optional message string.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Error",
            isPresented: Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } }),
            actions: { Button("OK") { message.wrappedValue = nil } },
            message: { Text(message.wrappedValue ?? "") }
        )
    }
}

extension String {
    /// Trims leading/trailing whitespace and newlines — the app's one
    /// consistent notion of "trimmed" for user-typed text (names, notes,
    /// search queries), used before every save/comparison so a
    /// value that's only whitespace reads the same as empty everywhere.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Mimics JS's default Number-to-string stringification: whole numbers print
/// without a decimal point, fractional values print minimally. Shared by
/// every place a logged weight/rep value is displayed or re-typed into an
/// editable field.
func formatNumber(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0, abs(value) < 1e15 {
        return String(Int64(value))
    }
    return String(value)
}

/// Placeholder auth/profile entry point (Todoist-style) — not wired up yet.
/// Shared by both tab roots' leading toolbar slot (`RoutinesListView`,
/// `ExerciseLibraryView`) so their chrome matches instead of one tab having
/// an identity/account affordance the other lacks.
struct AccountAvatarButton: View {
    var body: some View {
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
