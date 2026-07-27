import SwiftUI

/// Shared wireframe button style: bordered rectangle, colors invert on press.
/// Matches the web app's `active:bg-foreground active:text-background` utility.
struct BorderedRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.background : Theme.foreground)
            .background(configuration.isPressed ? Theme.foreground : Theme.background)
            .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
    }
}

struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.foreground : Theme.background)
            .background(configuration.isPressed ? Theme.background : Theme.foreground)
            .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
    }
}

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
