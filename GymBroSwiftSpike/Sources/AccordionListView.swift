import SwiftUI

private struct Exercise: Identifiable {
    let id: String
    let name: String
    let cues: String
    let last: String
}

private let exercises: [Exercise] = [
    Exercise(id: "1", name: "Barbell Bench Press",
             cues: "• Grip just outside shoulders\n• Elbows ~45°\n• Bar to lower chest",
             last: "3x8 @ 135 lb"),
    Exercise(id: "2", name: "Incline Dumbbell Press",
             cues: "• 30° bench\n• Wrists stacked over elbows",
             last: "3x10 @ 50 lb"),
    Exercise(id: "3", name: "Cable Fly",
             cues: "• Slight forward lean\n• Squeeze at midline",
             last: "3x12 @ 20 lb"),
    Exercise(id: "4", name: "Overhead Triceps Extension",
             cues: "• Elbows pinned in\n• Full stretch at bottom",
             last: "3x12 @ 25 lb"),
    Exercise(id: "5", name: "Lateral Raise",
             cues: "• Lead with elbows\n• Stop at shoulder height",
             last: "3x15 @ 12 lb"),
]

struct AccordionListView: View {
    @State private var expandedId: String?
    @State private var toggleTap = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(exercises) { ex in
                        card(ex)
                            .id(ex.id)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .sensoryFeedback(.impact(weight: .light), trigger: toggleTap)
            .onChange(of: expandedId) { _, newValue in
                guard let id = newValue else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
    }

    private func card(_ ex: Exercise) -> some View {
        let isExpanded = expandedId == ex.id
        return VStack(spacing: 0) {
            Button {
                toggleTap += 1
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    expandedId = isExpanded ? nil : ex.id
                }
            } label: {
                HStack {
                    Text(ex.name)
                        .font(.system(size: 17, weight: .medium))
                    Spacer()
                    Text(isExpanded ? "︿" : "﹀")
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(CardHeaderButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cues")
                        .font(.system(size: 14, weight: .medium))
                    Text(ex.cues)
                        .font(.system(size: 14))
                        .lineSpacing(4)
                    Text("Last logged")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.top, 8)
                    Text(ex.last)
                        .font(.system(size: 14))
                }
                .foregroundColor(Theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.foreground), alignment: .top)
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

#Preview {
    AccordionListView()
}
