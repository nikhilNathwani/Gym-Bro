import SwiftUI
import UIKit

/// Read-only reference material for the exercise currently on screen in
/// `WorkoutSessionView`: target/subtitle, a peek at last time's numbers,
/// cues, and the link to the full exercise page. Lives in the session's
/// independently-scrolling top region — separate from `ExerciseLoggingDock`,
/// which is fixed at the bottom alongside Prev/Next, since the user only
/// ever needs to glance at this material, not interact with it.
struct ExerciseReferenceSection: View {
    let controller: ExerciseLogController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let subtitle = controller.exercise.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let lastTime = controller.lastTime {
                lastTimeSection(lastTime)
            }

            if let cues = controller.exercise.cues, !cues.isEmpty {
                cuesSection(cues)
            }

            openFullPageLink
        }
        .sensoryFeedback(.selection, trigger: controller.isCuesExpanded)
    }

    private func lastTimeSection(_ log: ExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Last Time").font(.subheadline.weight(.semibold))
                Spacer()
                // Not wired up yet — deliberately left as a placeholder.
                Text("View history")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(log.setsSummary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let notes = log.notes, !notes.isEmpty {
                Text("\u{201C}\(notes)\u{201D}")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func cuesSection(_ cues: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                controller.isCuesExpanded.toggle()
            } label: {
                HStack {
                    Text("Cues").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(controller.isCuesExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if controller.isCuesExpanded {
                Text(cues)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var openFullPageLink: some View {
        NavigationLink(value: AppRoute.exercise(controller.exercise.id)) {
            HStack(spacing: 4) {
                Text("Open full exercise page")
                Image(systemName: "chevron.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }
}

/// The fixed bottom "input toolbar" for the current exercise: WEIGHT/REPS
/// set steppers, "Add set", and Notes — collocated with
/// `WorkoutSessionView`'s own Prev/Next in one dock (see that file), since
/// the user only ever works with one exercise at a time and wanted the
/// controls for it grouped as a single widget rather than scrolling apart
/// from each other.
struct ExerciseLoggingDock: View {
    let controller: ExerciseLogController

    private enum FocusField: Hashable {
        case weight(UUID)
        case reps(UUID)
        case notes
    }
    @FocusState private var focusedField: FocusField?

    // Fixed card size — the point of the carousel is that the dock's height
    // stops growing as sets are added, so every card (including the
    // trailing "Add set" tile) must agree on one size regardless of content.
    private let cardWidth: CGFloat = 168
    private let cardHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            setsCarousel

            VStack(alignment: .leading, spacing: 5) {
                Text("NOTES")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                notesField
            }
        }
        .onChange(of: focusedField) { oldValue, _ in
            guard let oldValue else { return }
            switch oldValue {
            case .weight(let id): if let i = controller.setIndex(for: id) { controller.commitWeightText(at: i) }
            case .reps(let id): if let i = controller.setIndex(for: id) { controller.commitRepsText(at: i) }
            case .notes: controller.commitNotes()
            }
        }
        .toolbar {
            if focusedField != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        // Covers both "Add set" and the per-row delete — both change the
        // set count, and matching the stepper buttons' own light-impact
        // feel keeps the whole dock's haptic language consistent.
        .sensoryFeedback(.impact(weight: .light), trigger: controller.sets.count)
    }

    // Sets ride in a horizontally-scrolling row of fixed-size cards instead
    // of a vertical list of rows — a vertical list kept growing the whole
    // dock taller with every set added, pushing Notes/Prev/Next further
    // down; a fixed-height carousel keeps the dock's height constant
    // regardless of set count, and gives each stepper more room. Weight and
    // reps are stacked within a card (the "transpose") rather than side by
    // side in a row. Adding a set scrolls the new (rightmost) card to the
    // center automatically; earlier sets are still reachable by scrolling
    // left.
    private var setsCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Keyed by setNumber, not Identifiable's UUID — a set's
                    // id changes from a local placeholder to the real
                    // database id the moment it's first persisted (see
                    // ExerciseLogController), and setNumber is the stable
                    // identity used everywhere else in this file for
                    // exactly that reason.
                    ForEach(controller.sets, id: \.setNumber) { set in
                        setCard(set)
                            .id(set.setNumber)
                    }
                    addSetCard
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .onChange(of: controller.sets.count) { _, _ in
                guard let lastSetNumber = controller.sets.last?.setNumber else { return }
                withAnimation(.snappy(duration: 0.3)) {
                    proxy.scrollTo(lastSetNumber, anchor: .center)
                }
            }
        }
        .frame(height: cardHeight)
    }

    // Looks up the card's *current* index by id on every access rather than
    // capturing a fixed index — a deleted-last-set can shrink `sets` while a
    // stale closure for the removed card is still momentarily reachable
    // (SwiftUI/FocusState's own location-tracking machinery re-evaluates
    // bindings during the transition), and indexing with a captured Int
    // that's now out of bounds crashes. Resolving by id instead just quietly
    // no-ops once the card is gone.
    private func setCard(_ set: ExerciseLogController.EditableSet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SET \(set.setNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                // Only the last set can be removed (undoing an accidental
                // "Add set") — deleting an arbitrary middle set would need
                // to renumber every set after it, both locally and in the
                // backend, which isn't worth the complexity for what's
                // really just an "undo the last add" affordance.
                if set.setNumber == controller.sets.last?.setNumber && controller.sets.count > 1 {
                    Button(action: controller.deleteLastSet) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("deleteLastSetButton")
                }
            }

            numericStepper(
                text: Binding(
                    get: { controller.setIndex(for: set.id).map { controller.sets[$0].weightText } ?? set.weightText },
                    set: { newValue in
                        if let i = controller.setIndex(for: set.id) { controller.sets[i].weightText = newValue }
                    }
                ),
                keyboardType: .decimalPad,
                focusField: .weight(set.id),
                idPrefix: "weight-\(set.setNumber)",
                onDecrement: { if let i = controller.setIndex(for: set.id) { controller.adjustWeight(at: i, by: -2.5) } },
                onIncrement: { if let i = controller.setIndex(for: set.id) { controller.adjustWeight(at: i, by: 2.5) } }
            )
            numericStepper(
                text: Binding(
                    get: { controller.setIndex(for: set.id).map { controller.sets[$0].repsText } ?? set.repsText },
                    set: { newValue in
                        if let i = controller.setIndex(for: set.id) { controller.sets[i].repsText = newValue }
                    }
                ),
                keyboardType: .numberPad,
                focusField: .reps(set.id),
                idPrefix: "reps-\(set.setNumber)",
                onDecrement: { if let i = controller.setIndex(for: set.id) { controller.adjustReps(at: i, by: -1) } },
                onIncrement: { if let i = controller.setIndex(for: set.id) { controller.adjustReps(at: i, by: 1) } }
            )

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: cardWidth, height: cardHeight, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    // idPrefix is keyed by set *number* (stable, e.g. "weight-1"), not the
    // set's UUID (which only exists once persisted) — lets UI tests target
    // "the first set's weight stepper" predictably regardless of
    // persistence state.
    // No "WEIGHT"/"REPS" text label on this control — three different ways
    // of adding one (a wrapping VStack sibling, an overlay with extra top
    // padding, a size-neutral offset overlay) all reproduced the exact same
    // bug: a second rapid tap on the +/- buttons would silently fail to
    // persist (see HANDOFF.md for the full repro). Root cause wasn't
    // pinned down — it wasn't specific to any one structural pattern, just
    // to the presence of any extra view here — so labels were dropped
    // rather than shipped broken. Weight/reps are still distinguishable by
    // position (weight always first) and format (decimal vs. integer).
    private func numericStepper(
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        focusField: FocusField,
        idPrefix: String,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 2) {
            RepeatingStepperButton(systemImage: "minus", identifier: "\(idPrefix)-minus", action: onDecrement)

            TextField("", text: text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.center)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .focused($focusedField, equals: focusField)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("\(idPrefix)-field")

            RepeatingStepperButton(systemImage: "plus", identifier: "\(idPrefix)-plus", action: onIncrement)
        }
        .padding(3)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var addSetCard: some View {
        Button(action: controller.addSet) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                Text("Add set")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color.accentColor)
            .frame(width: cardWidth * 0.6, height: cardHeight)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addSetButton")
    }

    private var notesField: some View {
        TextField("Add a note for today…", text: Binding(get: { controller.notesDraft }, set: { controller.notesDraft = $0 }), axis: .vertical)
            .font(.subheadline)
            .lineLimit(2...6)
            .focused($focusedField, equals: .notes)
            .padding(9)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityIdentifier("notesField")
    }
}

/// A +/- button that increments/decrements once immediately on tap, and
/// auto-repeats while held down (after a short delay, so a normal tap isn't
/// mistaken for a hold) — for jumping a weight/rep value by a lot without
/// mashing the button. Each tick fires a light haptic, echoing a real
/// mechanical stepper.
private struct RepeatingStepperButton: View {
    let systemImage: String
    let identifier: String
    let action: () -> Void

    @State private var repeatTask: Task<Void, Never>?

    private let holdDelay: Duration = .milliseconds(450)
    private let repeatInterval: Duration = .milliseconds(120)

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .bold))
            .frame(width: 44, height: 44)
            .foregroundStyle(Color.accentColor)
            .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
            .accessibilityIdentifier(identifier)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: 30, pressing: { pressing in
                if pressing {
                    tick()
                    startHoldTimer()
                } else {
                    stopHoldTimer()
                }
            }, perform: {})
    }

    private func tick() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }

    private func startHoldTimer() {
        repeatTask = Task {
            try? await Task.sleep(for: holdDelay)
            guard !Task.isCancelled else { return }
            while !Task.isCancelled {
                tick()
                try? await Task.sleep(for: repeatInterval)
            }
        }
    }

    private func stopHoldTimer() {
        repeatTask?.cancel()
        repeatTask = nil
    }
}
