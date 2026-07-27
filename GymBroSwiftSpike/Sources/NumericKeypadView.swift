import SwiftUI

private struct Suggestion {
    let label: String
    let value: String
}

private let suggestions = [
    Suggestion(label: "Same as last", value: "12"),
    Suggestion(label: "+5 lb", value: "17"),
    Suggestion(label: "-5 lb", value: "7"),
]

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

struct NumericKeypadView: View {
    let onDone: () -> Void

    @State private var value = ""
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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.foreground), alignment: .bottom)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.label) { s in
                        Button {
                            mediumTap += 1
                            value = s.value
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                    KeyButton(label: key.label) {
                        lightTap += 1
                        switch key.kind {
                        case .digit(let d): value += d
                        case .decimal: if !value.contains(".") { value += "." }
                        case .comma: value += ", "
                        case .backspace: if !value.isEmpty { value.removeLast() }
                        }
                    }
                }
            }
            .padding(.horizontal, 11)

            KeyButton(label: "0") {
                lightTap += 1
                value += "0"
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 20, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(KeyButtonStyle())
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
    NumericKeypadView(onDone: {})
}
