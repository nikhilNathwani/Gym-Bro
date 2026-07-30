import SwiftUI
import UIKit

/// The whole exercise page's content — name, target, last time, today's
/// log, notes, cues, history — as one `List`. Shared by both places an
/// exercise is shown: `WorkoutSessionView` wraps this with a Prev/Next
/// toolbar for its routine context; `ExerciseDetailView` hosts it standalone
/// (no paging). Keeping this in one place is the whole point of the merge
/// these two used to be separate, overlapping pages before it — one set of
/// editable fields, not two copies that can drift out of sync.
struct ExercisePageList: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(
                        "Exercise name",
                        text: Binding(get: { controller.nameDraft }, set: { controller.nameDraft = $0 })
                    )
                    .font(.title.bold())
                    .focused(focusedField, equals: .name)
                    ExerciseSummarySection(controller: controller, focusedField: focusedField)
                }
                // Zero horizontal row insets (below) put this content flush
                // with the page's left margin, matching a plain page title
                // rather than an indented card — but `.insetGrouped` still
                // clips each section's first/last row to a rounded-corner
                // mask regardless of the (clear) row background, and this
                // is a single-row section, so both corners are rounded on
                // both edges. 4pt of vertical padding sat inside that
                // corner radius and clipped the corner off whatever glyph
                // (e.g. "25×10"'s "2") landed there; this needs to clear
                // the radius, not just add a little breathing room.
                .padding(.vertical, 14)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            // A log can legitimately have zero sets (see `seed()`'s doc
            // comment on `ExerciseLogController` — deleting the last set
            // leaves a real, childless row behind rather than deleting the
            // log outright), which would otherwise render this section with
            // a blank/empty-looking body. Nothing worth showing there, so
            // skip the section entirely rather than show an empty card.
            if let lastTime = controller.lastTime, !lastTime.setLogs.isEmpty {
                ExerciseLastTimeSection(log: lastTime)
            }
            ExerciseLoggingSections(controller: controller, focusedField: focusedField)
            ExerciseCuesSection(controller: controller, focusedField: focusedField)
            ExerciseHistorySection(controller: controller)
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Just the target field — shown *above* the logging controls, directly
/// under the name. A peek at last time's numbers used to live here too, as
/// hand-styled text; it's now its own real `Section` (`ExerciseLastTimeSection`,
/// below) so its header matches every other section's ("Cues", "Today's
/// Log", ...) instead of being a one-off bolded label.
struct ExerciseSummarySection: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    var body: some View {
        // Always an editable field, not a read-only Text shown only in
        // some page-level "Edit mode" — this page doesn't have one
        // (see `ExerciseLogController`'s type doc comment): a field
        // just commits on blur, same as the Notes field in "Today's Log".
        TextField(
            "Target — e.g. 3 sets × 6–10 reps",
            text: Binding(get: { controller.targetDraft }, set: { controller.targetDraft = $0 })
        )
        .font(.body)
        .foregroundStyle(.secondary)
        .focused(focusedField, equals: .target)
    }
}

/// Last time's logged numbers — a real `Section` with a native header, same
/// as "Cues"/"Today's Log" below it, rather than a hand-bolded `Text("Last
/// Time")` living inside the title/target block above (that read as visually
/// inconsistent with every other section header on the page).
struct ExerciseLastTimeSection: View {
    let log: ExerciseLog

    var body: some View {
        Section("Last Time") {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.setsSummary)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if let notes = log.notes, !notes.isEmpty {
                    Text("\u{201C}\(notes)\u{201D}")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Cues — shown *below* the logging controls (see `ExerciseSummarySection`),
/// since cues are reference material worth checking before a set, not
/// something that needs to be pinned above the inputs themselves. A plain
/// native `Section` — same styling as "Today's Log"/"Last Time" — with an
/// always-visible multi-line field, no separate collapse toggle: a hand-rolled
/// Button-with-rotating-chevron header (this section's original design, and
/// `ExerciseHistorySection`'s below) read as visually inconsistent with the
/// native section headers elsewhere on this page, sat at a different
/// indentation, and (found while writing an XCUITest regression check for
/// it) didn't reliably register taps at all. Cues text is short enough in
/// practice that collapsing it isn't worth reintroducing that for.
struct ExerciseCuesSection: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    var body: some View {
        Section("Cues") {
            TextField(
                "Add cues — form notes, setup reminders, etc.",
                text: Binding(get: { controller.cuesDraft }, set: { controller.cuesDraft = $0 }),
                axis: .vertical
            )
            .lineLimit(3...10)
            .focused(focusedField, equals: .cues)
        }
    }
}

/// Past logged sessions — collapsed by default (see the type doc comment on
/// `ExerciseLogController.isHistoryExpanded`), expanded via this page's own
/// "View history" link or by tapping the header here directly. Today's own
/// entry is excluded — that's already the "Today's Log" section above,
/// showing it again here would just be the same data twice. A native
/// `DisclosureGroup`, not a hand-rolled Button-with-rotating-chevron (this
/// section's original design) — same reasoning as `ExerciseCuesSection`'s
/// doc comment: visually inconsistent with real `Section` headers, and its
/// tap target didn't reliably register at all (an XCUITest regression check
/// written alongside this redesign caught it hanging three different ways —
/// by label, by identifier, even a raw coordinate tap — while the equivalent
/// `DisclosureGroup` here has had no such issue).
struct ExerciseHistorySection: View {
    let controller: ExerciseLogController

    private var pastLogs: [ExerciseLog] {
        controller.exercise.exerciseLogs
            .filter { !Calendar.current.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Section {
            DisclosureGroup(
                isExpanded: Binding(get: { controller.isHistoryExpanded }, set: { controller.isHistoryExpanded = $0 })
            ) {
                if pastLogs.isEmpty {
                    Text("No past sessions yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pastLogs) { log in
                        HistoryEntryView(
                            log: log,
                            onChanged: { await controller.reloadExercise() },
                            onError: controller.onError
                        )
                    }
                }
            } label: {
                Text("History")
            }
            .accessibilityIdentifier("historyToggle")
            .sensoryFeedback(.selection, trigger: controller.isHistoryExpanded)
        }
    }
}

/// Which text field currently has keyboard focus, shared across every
/// editable field on the exercise page (name, target, cues, sets, notes) so
/// the hosting view can commit a value the moment focus leaves it (see its
/// `onChange(of:)`).
enum LoggingFocusField: Hashable {
    case name
    case target
    case cues
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

    @State private var showDeleteSetConfirm = false

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
                    // Only the last set can be removed (undoing an
                    // accidental "Add Set") — deleting an arbitrary middle
                    // set would need to renumber every set after it, both
                    // locally and in the backend, which isn't worth the
                    // complexity for what's really just an "undo the last
                    // add" affordance. `allowsFullSwipe: false` forces an
                    // explicit tap on "Delete" rather than letting a full
                    // swipe silently auto-delete a set.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if isLastRemovable(set) {
                            Button(role: .destructive) { showDeleteSetConfirm = true } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
            Button(action: controller.addSet) {
                Label("Add Set", systemImage: "plus.circle.fill")
            }
            .accessibilityIdentifier("addSetButton")

            // Lives in "Today's Log" itself, not a separate "Notes"
            // section — a note is part of today's entry, not its own
            // topic, so no "Notes" label sits above it; the placeholder
            // text alone signals what the field is for.
            TextField(
                "Add a note for today…",
                text: Binding(get: { controller.notesDraft }, set: { controller.notesDraft = $0 }),
                axis: .vertical
            )
            .lineLimit(2...6)
            .focused(focusedField, equals: .notes)
            .accessibilityIdentifier("notesField")
        }
        .confirmationDialog(
            "Delete this set? This cannot be undone.",
            isPresented: $showDeleteSetConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: controller.deleteLastSet)
        }
    }

    private func isLastRemovable(_ set: ExerciseLogController.EditableSet) -> Bool {
        set.setNumber == controller.sets.last?.setNumber
    }

    private func setRow(_ set: ExerciseLogController.EditableSet) -> some View {
        Group {
            if set.setNumber == controller.effectiveExpandedSetNumber {
                expandedSetRow(set)
            } else {
                collapsedSetRow(set)
            }
        }
    }

    /// The active set: full weight/reps steppers, editable. No "last
    /// time" peek here — the "Last Time" summary at the top of the page
    /// already shows that, and repeating it per-row was clutter, not
    /// useful reference: you'd have to scroll away from it to compare
    /// against a value you're actively adjusting anyway.
    private func expandedSetRow(_ set: ExerciseLogController.EditableSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set \(set.setNumber)")
                .font(.subheadline.weight(.medium))

            HStack(spacing: 14) {
                fieldStepper(
                    label: "Weight (lbs)",
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

    /// A completed set — collapsed to one line, no stepper. Tapping it
    /// brings the steppers back for the rare case of correcting an
    /// already-logged set — same tap-to-expand convention as the "Cues"/
    /// "History" headers below (`ExerciseCuesSection`/`ExerciseHistorySection`),
    /// not a new idiom.
    private func collapsedSetRow(_ set: ExerciseLogController.EditableSet) -> some View {
        Button {
            controller.expandedSetNumber = set.setNumber
        } label: {
            HStack {
                Text("Set \(set.setNumber)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(formatNumber(set.weight)) × \(set.reps)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func fieldStepper(
        label: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType,
        focusCase: LoggingFocusField,
        idPrefix: String,
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) -> some View {
        SetValueStepper(
            label: label, text: text, keyboardType: keyboardType, idPrefix: idPrefix,
            focusedField: focusedField, focusCase: focusCase,
            onIncrement: onIncrement, onDecrement: onDecrement)
    }
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
//
// Shared between "Today's Log" (this file, focus tied to the page-wide
// `LoggingFocusField`) and `HistoryEntryView`'s past-entry editor (its own
// private, unrelated focus enum) — generic over the focus value's type so
// both can plug in their own `FocusState` without this view knowing about
// either. `focusedField`/`focusCase` are optional so a caller with no
// commit-on-blur behavior to wire up (none currently) could skip focus
// entirely.
struct SetValueStepper<Field: Hashable>: View {
    let label: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let idPrefix: String
    var focusedField: FocusState<Field?>.Binding? = nil
    var focusCase: Field? = nil
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            textField
                .keyboardType(keyboardType)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                // Fixed width, generous enough for a value like "137.5"
                // without ever needing to grow — a `.fixedSize()` field
                // (tried first, to fix truncation on longer values) resized
                // on every keystroke/increment, which shifted the stepper's
                // +/- buttons out from under a finger mid rapid-tap.
                .frame(width: 64)
                .accessibilityIdentifier("\(idPrefix)-field")
            Stepper("", onIncrement: onIncrement, onDecrement: onDecrement)
                .labelsHidden()
                .padding(.top, 10)
                .accessibilityIdentifier("\(idPrefix)-stepper")
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var textField: some View {
        if let focusedField, let focusCase {
            TextField("", text: $text).focused(focusedField, equals: focusCase)
        } else {
            TextField("", text: $text)
        }
    }
}
