import SwiftUI

/// Generalized from the spike's AccordionListView: a bordered card whose body
/// expands/collapses on header tap. Used for the routine-detail exercise list
/// in view mode.
struct AccordionCard<Header: View, Content: View>: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    header()
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardHeaderButtonStyle())

            if isExpanded {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .overlay(
                        Rectangle().frame(height: 1).foregroundColor(Theme.foreground), alignment: .top
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
    }
}

private struct CardHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? Theme.background : Theme.foreground)
            .background(configuration.isPressed ? Theme.foreground : Theme.background)
    }
}
