import SwiftUI

enum Tab {
    case accordion
    case keypad
}

struct ContentView: View {
    @State private var tab: Tab = .accordion
    @State private var keypadOpen = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton("Accordion", isActive: tab == .accordion) {
                    tab = .accordion
                }
                tabButton("Keypad", isActive: tab == .keypad) {
                    tab = .keypad
                    keypadOpen = true
                }
            }
            .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.foreground), alignment: .bottom)

            switch tab {
            case .accordion:
                AccordionListView()
            case .keypad:
                VStack {
                    Spacer()
                    if !keypadOpen {
                        Button {
                            keypadOpen = true
                        } label: {
                            Text("Reopen keypad")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.foreground)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .overlay(Rectangle().stroke(Theme.foreground, lineWidth: 1))
                        }
                        .padding(.bottom, 24)
                    }
                    if keypadOpen {
                        NumericKeypadView(onDone: { keypadOpen = false })
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
        }
        .background(Theme.background)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func tabButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isActive ? Theme.background : Theme.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isActive ? Theme.foreground : Theme.background)
        }
    }
}

#Preview {
    ContentView()
}
