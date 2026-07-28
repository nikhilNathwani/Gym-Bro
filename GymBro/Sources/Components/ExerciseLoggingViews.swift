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
                    .font(.caption)
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
            Text(controller.setsSummary(log))
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var openFullPageLink: some View {
        VStack(spacing: 10) {
            Divider()
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
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("SET")
                    .frame(width: 34, alignment: .leading)
                Text("WEIGHT")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(controller.sets) { set in
                    setRow(set)
                }
                HStack {
                    Spacer()
                    addSetButton
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
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
    }

    // Looks up the row's *current* index by id on every access rather than
    // capturing a fixed index — a deleted-last-set can shrink `sets` while a
    // stale closure for the removed row is still momentarily reachable
    // (SwiftUI/FocusState's own location-tracking machinery re-evaluates
    // bindings during the transition), and indexing with a captured Int
    // that's now out of bounds crashes. Resolving by id instead just quietly
    // no-ops once the row is gone.
    private func setRow(_ set: ExerciseLogController.EditableSet) -> some View {
        HStack(spacing: 6) {
            Text("\(set.setNumber)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)

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

            // Only the last set can be removed (undoing an accidental "Add
            // set") — deleting an arbitrary middle set would need to
            // renumber every set after it, both locally and in the backend,
            // which isn't worth the complexity for what's really just an
            // "undo the last add" affordance.
            if set.id == controller.sets.last?.id && controller.sets.count > 1 {
                Button(action: controller.deleteLastSet) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("deleteLastSetButton")
            }
        }
    }

    // idPrefix is keyed by set *number* (stable, e.g. "weight-1"), not the
    // set's UUID (which only exists once persisted) — lets UI tests target
    // "the first set's weight stepper" predictably regardless of
    // persistence state.
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
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var addSetButton: some View {
        Button(action: controller.addSet) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                Text("Add set")
            }
            .font(.caption.weight(.semibold))
        }
        .accessibilityIdentifier("addSetButton")
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
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
