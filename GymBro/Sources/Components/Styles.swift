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
