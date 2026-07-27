import SwiftUI

private enum Field {
    case weight, reps
}

private let weightStep = 5.0
private let repStep = 1.0

/// Renders the Weight/Reps comma-list fields plus the NumericKeypadView that
/// backs them. Port of SetFieldsEditor.tsx. Unlike the web version (plain
/// `<input>`s read via FormData on submit), the two text values are owned by
/// the caller and passed in as bindings, since SwiftUI has no form-submission
/// equivalent.
struct SetFieldsEditor: View {
    @Binding var weightText: String
    @Binding var repsText: String
    var previousSets: [SetLog] = []

    @State private var active: Field?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldRow(
                label: "Weight",
                text: weightText,
                placeholder: previousLine(.weight).isEmpty ? "e.g. 25,25,27.5" : previousLine(.weight),
                isActive: active == .weight,
                identifier: "weightField"
            ) {
                active = (active == .weight) ? nil : .weight
            }

            fieldRow(
                label: "Reps",
                text: repsText,
                placeholder: previousLine(.reps).isEmpty ? "e.g. 10,10,8" : previousLine(.reps),
                isActive: active == .reps,
                identifier: "repsField"
            ) {
                active = (active == .reps) ? nil : .reps
            }

            if let active {
                NumericKeypadView(
                    value: text(for: active),
                    suggestions: suggestions(for: active),
                    onDigit: { appendDigit(active, $0) },
                    onDecimal: { applyDecimal(active) },
                    onComma: { applyComma(active) },
                    onBackspace: { applyBackspace(active) },
                    onSuggestion: { applySuggestion(active, $0) },
                    onDone: { self.active = nil }
                )
            }
        }
        .onChange(of: active) { oldValue, _ in
            if let oldValue { trimTrailingComma(oldValue) }
        }
    }

    private func fieldRow(
        label: String, text: String, placeholder: String, isActive: Bool, identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Theme.foreground)
                .frame(width: 56, alignment: .leading)
            Button(action: action) {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 16))
                    .foregroundColor(text.isEmpty ? Theme.foreground.opacity(0.4) : Theme.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .overlay(
                        Rectangle().stroke(Theme.foreground, lineWidth: isActive ? 2 : 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
        }
    }

    // MARK: - Text access

    private func text(for field: Field) -> String {
        field == .weight ? weightText : repsText
    }

    private func setText(_ field: Field, _ value: String) {
        if field == .weight { weightText = value } else { repsText = value }
    }

    // MARK: - Comma-segment editing (port of SetFieldsEditor.tsx helpers)

    private func lastSegment(_ value: String) -> String {
        value.components(separatedBy: ",").last ?? ""
    }

    private func priorSegment(_ value: String) -> String {
        let segments = value.components(separatedBy: ",")
        return segments.count > 1 ? segments[segments.count - 2] : ""
    }

    private func replaceLastSegment(_ value: String, with replacement: String) -> String {
        var segments = value.components(separatedBy: ",")
        if segments.isEmpty { segments = [""] }
        segments[segments.count - 1] = replacement
        return segments.joined(separator: ",")
    }

    private func appendDigit(_ field: Field, _ digit: String) {
        setText(field, text(for: field) + digit)
    }

    private func applyDecimal(_ field: Field) {
        let value = text(for: field)
        let current = lastSegment(value)
        if current.contains(".") { return }
        setText(field, replaceLastSegment(value, with: current.isEmpty ? "0." : current + "."))
    }

    private func applyComma(_ field: Field) {
        let value = text(for: field)
        if value.isEmpty || value.hasSuffix(",") { return }
        setText(field, value + ",")
    }

    private func applyBackspace(_ field: Field) {
        let value = text(for: field)
        guard !value.isEmpty else { return }
        setText(field, String(value.dropLast()))
    }

    private func applySuggestion(_ field: Field, _ value: String) {
        setText(field, replaceLastSegment(text(for: field), with: value) + ",")
    }

    private func trimTrailingComma(_ field: Field) {
        let value = text(for: field)
        if value.hasSuffix(",") { setText(field, String(value.dropLast())) }
    }

    // MARK: - Suggestions / placeholders

    private func previousLine(_ field: Field) -> String {
        guard !previousSets.isEmpty else { return "" }
        return previousSets
            .map { set in
                field == .weight
                    ? set.weight.map(formatNumber) ?? ""
                    : set.reps.map { String($0) } ?? ""
            }
            .joined(separator: ",")
    }

    private func suggestions(for field: Field) -> [KeypadSuggestion] {
        let value = text(for: field)
        let segmentIndex = value.components(separatedBy: ",").count - 1
        var chips: [KeypadSuggestion] = []

        if let lastTimeSet = previousSets.first(where: { $0.setNumber == segmentIndex + 1 }) {
            let lastTimeValue: String? =
                field == .weight ? lastTimeSet.weight.map(formatNumber) : lastTimeSet.reps.map { String($0) }
            if let lastTimeValue {
                chips.append(KeypadSuggestion(label: "\(lastTimeValue) last time", value: lastTimeValue))
            }
        }

        let prior = priorSegment(value)
        if !prior.isEmpty {
            chips.append(KeypadSuggestion(label: "same", value: prior))
            if let n = Double(prior) {
                let step = field == .reps ? repStep : weightStep
                chips.append(KeypadSuggestion(label: "+\(formatNumber(step))", value: formatNumber(n + step)))
                chips.append(
                    KeypadSuggestion(label: "-\(formatNumber(step))", value: formatNumber(max(0, n - step))))
            }
        }

        if chips.isEmpty {
            let fallback = field == .reps ? ["8", "10", "12", "15"] : ["10", "25", "45"]
            chips.append(contentsOf: fallback.map { KeypadSuggestion(label: $0, value: $0) })
        }

        return Array(chips.prefix(4))
    }
}

/// Mimics JS's default Number-to-string stringification: whole numbers print
/// without a decimal point, fractional values print minimally.
func formatNumber(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0, abs(value) < 1e15 {
        return String(Int64(value))
    }
    return String(value)
}

#Preview {
    SetFieldsEditor(weightText: .constant("10,12"), repsText: .constant("10,10"))
        .padding()
}
