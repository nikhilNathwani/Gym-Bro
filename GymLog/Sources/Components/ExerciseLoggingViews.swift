import SwiftUI
import UIKit

/// Read-only summary shown *above* the logging controls in
/// `WorkoutSessionView`: target/subtitle and a peek at last time's numbers.
/// Kept separate from `ExerciseCuesSection` (cues + the full-page link,
/// shown *below* the logging controls) so the sets/notes UI always sits
/// directly under this, with nothing to scroll past to reach it — cues are
/// something you'd check before starting a set, not something that needs
/// to sit between "last time" and the actual inputs.
struct ExerciseSummarySection: View {
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
}

/// Cues + the link to the full exercise page — shown *below* the logging
/// controls (see `ExerciseSummarySection`), since cues are reference
/// material worth checking before a set, not something that needs to be
/// pinned above the inputs themselves.
struct ExerciseCuesSection: View {
    let controller: ExerciseLogController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let cues = controller.exercise.cues, !cues.isEmpty {
                cuesSection(cues)
            }

            openFullPageLink
        }
        .sensoryFeedback(.selection, trigger: controller.isCuesExpanded)
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

/// Which text field currently has keyboard focus, shared between the sets
/// section and the notes field so `WorkoutSessionView` can commit a value
/// the moment focus leaves it (see its `onChange(of:)`).
enum LoggingFocusField: Hashable {
    case weight(UUID)
    case reps(UUID)
    case notes
}

/// The current exercise's sets + notes, as native `List` `Section`s — meant
/// to be placed directly inside a `List` (see `WorkoutSessionView`), not
/// used standalone. Leans entirely on stock components rather than custom
/// ones: a real `Section` header instead of a hand-drawn all-caps label, a
/// real `Stepper` for each weight/reps value instead of a custom-drawn +/-
/// button pair, and real `.swipeActions` for undoing the last set instead
/// of a persistent trash icon. An earlier version of this screen reinvented
/// all three, which is most of why it read as a custom "fitness dashboard"
/// rather than an iOS form.
struct ExerciseLoggingSections: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    var body: some View {
        Section("Today's Log") {
            ForEach(controller.sets, id: \.setNumber) { set in
                setRow(set)
                    // The row's identifier lives on an invisible full-size
                    // background marker, not on the row's own content —
                    // putting it directly on the row (with or without
                    // `.accessibilityElement(children:)`) was found to
                    // either override the two child `Stepper`s' own
                    // identifiers, or make the weight/reps `TextField`s
                    // stop registering as hittable. A same-size background
                    // sibling carries an identity for tests to find and
                    // swipe without touching the real content's own
                    // accessibility tree at all.
                    .background(Color.clear.accessibilityIdentifier("set-\(set.setNumber)-row"))
                    .swipeActions(edge: .trailing) {
                        // Only the last set can be removed (undoing an
                        // accidental "Add Set") — deleting an arbitrary
                        // middle set would need to renumber every set after
                        // it, both locally and in the backend, which isn't
                        // worth the complexity for what's really just an
                        // "undo the last add" affordance.
                        if isLastRemovable(set) {
                            Button(role: .destructive, action: controller.deleteLastSet) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
            Button(action: controller.addSet) {
                Label("Add Set", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("addSetButton")
        }

        Section("Notes") {
            TextField(
                "Add a note for today…",
                text: Binding(get: { controller.notesDraft }, set: { controller.notesDraft = $0 }),
                axis: .vertical
            )
            .lineLimit(2...6)
            .focused(focusedField, equals: .notes)
            .accessibilityIdentifier("notesField")
        }
    }

    private func isLastRemovable(_ set: ExerciseLogController.EditableSet) -> Bool {
        set.setNumber == controller.sets.last?.setNumber && controller.sets.count > 1
    }

    private func previousSummary(for set: ExerciseLogController.EditableSet) -> String? {
        guard let lastTime = controller.lastTime else { return nil }
        guard let match = lastTime.setLogs.first(where: { $0.setNumber == set.setNumber }) else { return nil }
        let weight = match.weight.map(formatNumber) ?? "–"
        let reps = match.reps.map(String.init) ?? "–"
        return "Last: \(weight)×\(reps)"
    }

    private func setRow(_ set: ExerciseLogController.EditableSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set \(set.setNumber)")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let previous = previousSummary(for: set) {
                    Text(previous)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 14) {
                fieldStepper(
                    label: "Weight",
                    text: Binding(
                        get: { controller.setIndex(for: set.id).map { controller.sets[$0].weightText } ?? set.weightText },
                        set: { newValue in
                            if let i = controller.setIndex(for: set.id) { controller.sets[i].weightText = newValue }
                        }
                    ),
                    keyboardType: .decimalPad,
                    focusCase: .weight(set.id),
                    idPrefix: "weight-\(set.setNumber)",
                    onIncrement: { if let i = controller.setIndex(for: set.id) { controller.adjustWeight(at: i, by: 2.5) } },
                    onDecrement: { if let i = controller.setIndex(for: set.id) { controller.adjustWeight(at: i, by: -2.5) } }
                )
                fieldStepper(
                    label: "Reps",
                    text: Binding(
                        get: { controller.setIndex(for: set.id).map { controller.sets[$0].repsText } ?? set.repsText },
                        set: { newValue in
                            if let i = controller.setIndex(for: set.id) { controller.sets[i].repsText = newValue }
                        }
                    ),
                    keyboardType: .numberPad,
                    focusCase: .reps(set.id),
                    idPrefix: "reps-\(set.setNumber)",
                    onIncrement: { if let i = controller.setIndex(for: set.id) { controller.adjustReps(at: i, by: 1) } },
                    onDecrement: { if let i = controller.setIndex(for: set.id) { controller.adjustReps(at: i, by: -1) } }
                )
            }
        }
        .padding(.vertical, 4)
    }

    // idPrefix is keyed by set *number* (stable, e.g. "weight-1"), not the
    // set's UUID (which only exists once persisted) — lets UI tests target
    // "the first set's weight stepper" predictably regardless of
    // persistence state.
    //
    // The value is a plain, independent `TextField` next to a labelless
    // `Stepper`, not a `TextField` embedded as the Stepper's own label —
    // that was tried first (letting the Stepper host the editable value
    // directly, so tapping either the number or +/- lived in one visual
    // unit), but a `Stepper` apparently claims touch handling across its
    // whole reported frame, *including* over its label — the embedded
    // field stopped registering as tappable at all. Two plain siblings
    // (`Stepper("", ...)` + `.labelsHidden()` is the standard way to show
    // a stepper with no visible label text) sidesteps that entirely: the
    // system stepper still gives press-and-hold repeat and VoiceOver
    // support for free, and the field stays independently tappable for
    // jumping straight to a specific typed value.
    private func fieldStepper(
        label: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        focusCase: LoggingFocusField,
        idPrefix: String,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField("", text: text)
                    .keyboardType(keyboardType)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .focused(focusedField, equals: focusCase)
                    .frame(width: 34)
                    .accessibilityIdentifier("\(idPrefix)-field")
                Stepper("", onIncrement: onIncrement, onDecrement: onDecrement)
                    .labelsHidden()
                    .accessibilityIdentifier("\(idPrefix)-stepper")
            }
        }
    }
}
