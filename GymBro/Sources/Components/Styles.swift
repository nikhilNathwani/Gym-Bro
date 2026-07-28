import SwiftUI

extension Color {
    /// Foreground color that reliably contrasts against a solid
    /// `Color.accentColor` background in both appearances. The accent asset
    /// (`Assets.xcassets/AccentColor`) is a dark, saturated purple in light
    /// mode (RGB 106,27,154 — white text clears WCAG AA easily at ~9.4:1)
    /// but a much lighter lavender in dark mode (RGB 149,117,205 — white
    /// text only reaches ~3.7:1 there, failing AA's 4.5:1 for normal-sized
    /// text; black text reaches ~5.7:1 instead). Use this instead of a
    /// fixed `.white`/`.black` anywhere content sits directly on an
    /// accent-colored background.
    static func onAccent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
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
