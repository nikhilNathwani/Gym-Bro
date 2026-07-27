import SwiftUI

struct KeypadSuggestion: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

private enum KeyKind {
    case digit(String)
    case decimal
    case comma
    case backspace
}

private let keys: [(label: String, kind: KeyKind)] = [
    ("1", .digit("1")), ("2", .digit("2")), ("3", .digit("3")), ("⌫", .backspace),
    ("4", .digit("4")), ("5", .digit("5")), ("6", .digit("6")), (".", .decimal),
    ("7", .digit("7")), ("8", .digit("8")), ("9", .digit("9")), (",", .comma),
]

/// Custom on-screen keypad backing the Weight/Reps fields in SetFieldsEditor.
/// A deliberate exception to "prefer native controls" — same rationale as
/// Apple's own Calculator/Phone dialer using bespoke keypads: the
/// comma-multi-set entry with suggestion chips has no system-keyboard
/// equivalent. Port of components/NumericKeypad.tsx; ownership of `value`
/// lives in the caller (SetFieldsEditor), this view is purely presentational.
struct NumericKeypadView: View {
    let value: String
    let suggestions: [KeypadSuggestion]
    let onDigit: (String) -> Void
    let onDecimal: () -> Void
    let onComma: () -> Void
    let onBackspace: () -> Void
    let onSuggestion: (String) -> Void
    let onDone: () -> Void

    @State private var lightTap = 0
    @State private var mediumTap = 0
    @State private var doneTap = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(value.isEmpty ? " " : value)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Theme.foreground)
                    .monospacedDigit()
                Spacer()
                Button {
                    doneTap += 1
                    onDone()
                } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.background)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.foreground)
                }
                .accessibilityIdentifier("keypadDone")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.foreground), alignment: .bottom)

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { s in
                            Button {
                                mediumTap += 1
                                onSuggestion(s.value)
                            } label: {
                                Text(s.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Theme.foreground)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyButton(label: key.label, kind: key.kind) {
                        lightTap += 1
                        switch key.kind {
                        case .digit(let d): onDigit(d)
                        case .decimal: onDecimal()
                        case .comma: onComma()
                        case .backspace: onBackspace()
                        }
                    }
                }
            }
            .padding(.horizontal, 11)

            KeyButton(label: "0", kind: .digit("0")) {
                lightTap += 1
                onDigit("0")
            }
            .padding(.horizontal, 11)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .background(Theme.background)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.foreground), alignment: .top)
        .sensoryFeedback(.impact(weight: .light), trigger: lightTap)
        .sensoryFeedback(.impact(weight: .medium), trigger: mediumTap)
        .sensoryFeedback(.success, trigger: doneTap)
    }
}

private struct KeyButton: View {
    let label: String
    let kind: KeyKind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if case .backspace = kind {
                    Image(systemName: "delete.left")
                        .font(.system(size: 18, weight: .medium))
                } else {
                    Text(label)
                        .font(.system(size: 20, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(KeyButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private var identifier: String {
        switch kind {
        case .digit(let d): return "key-\(d)"
        case .decimal: return "keyDecimal"
        case .comma: return "keyComma"
        case .backspace: return "keyBackspace"
        }
    }
}

private struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.background : Theme.foreground)
            .background(configuration.isPressed ? Theme.foreground : Theme.background)
            .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
    }
}

#Preview {
    NumericKeypadView(
        value: "10,12",
        suggestions: [
            KeypadSuggestion(label: "12 last time", value: "12"),
            KeypadSuggestion(label: "same", value: "10"),
        ],
        onDigit: { _ in },
        onDecimal: {},
        onComma: {},
        onBackspace: {},
        onSuggestion: { _ in },
        onDone: {}
    )
}
