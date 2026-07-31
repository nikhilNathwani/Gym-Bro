import SwiftUI
import UIKit

/// The whole exercise page's content — name, target, today's log, notes,
/// last time, cues, history — as one `List`. Shared by both places an
/// exercise is shown: `WorkoutSessionView` wraps this with a Prev/Next
/// toolbar for its routine context; `ExerciseDetailView` hosts it standalone
/// (no paging). Keeping this in one place is the whole point of the merge
/// these two used to be separate, overlapping pages before it — one set of
/// editable fields, not two copies that can drift out of sync.
///
/// "Last Time" sits *below* "Today's Log" — it used to be pinned above so
/// it was always visible without scrolling, back when Today's Log started
/// pre-filled and could run long; now every exercise starts at zero sets
/// (an explicit "Add Set" tap is required — see `ExerciseLogController`'s
/// type doc comment), so Today's Log is short enough by default that
/// there's nothing left to scroll past.
struct ExercisePageList: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    var body: some View {
        List {
            // Name/target and the Add Set/notes controls now share ONE
            // native `Section` — one continuous white rounded card for
            // everything you actually *input* on this page, rather than a
            // plain flush title floating above an unrelated card below it.
            // Last Time/Cues/History stay exactly as they were (each its
            // own `Section` with a clear row background, flush against the
            // page background) — this only touches what's above them.
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
                .padding(.vertical, 6)
                // No native row separator below name/target — within the
                // card, name/target and Add Set are one continuous block,
                // not two things divided by a rule.
                .listRowSeparator(.hidden)

                ExerciseLoggingSections(controller: controller, focusedField: focusedField)
            }

            // No explicit divider below this card into "Last Time" — once
            // name/target/Add Set/notes became one shared white card (see
            // above), the card's own edge already reads as a clear boundary
            // against the plain background "Last Time"/"Cues"/"History"
            // sit on; a hand-drawn rule in that gap turned out to be
            // redundant on top of it, not an extra signal.

            // A log can legitimately have zero sets (see `seed()`'s doc
            // comment on `ExerciseLogController` — deleting the last set
            // leaves a real, childless row behind rather than deleting the
            // log outright), which would otherwise render this section with
            // a blank/empty-looking body. Nothing worth showing there, so
            // skip the section entirely rather than show an empty card.
            if let lastTime = controller.lastTime, !lastTime.setLogs.isEmpty {
                ExerciseLastTimeSection(log: lastTime)
            }
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
/// further down the page — see `ExercisePageList`'s doc comment for why)
/// so its header matches every other section's ("Cues", "Today's Log", ...)
/// instead of being a one-off bolded label.
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
///
/// Clear row background, same as the title/target block above it — this is
/// reference text, not something you act on, so it sits flush against the
/// app background rather than in a grouped card. That leaves the card
/// background meaning one thing on this page: "you can edit this."
///
/// The header-to-content gap used to come from *two* stacked negative
/// paddings — `-40` on the header, `-16` on the content `VStack` — and their
/// combined overlap wasn't a fixed amount: it came out much smaller whenever
/// the optional notes line was present (measured ~10pt with a note vs. ~34pt
/// without one on the same device), since the second negative padding was
/// pulling a *taller* two-line block up by the same nominal amount, not
/// pulling the gap itself to a fixed size. Only the header keeps a negative
/// pad now — content-height-independent, so the gap is identical whether or
/// not there's a note.
struct ExerciseLastTimeSection: View {
    let log: ExerciseLog

    var body: some View {
        Section(header: Text("Last Time").padding(.bottom, -40)) {
            VStack(alignment: .leading, spacing: 4) {
                Text(log.setsSummary)
                    .font(.body)
                    .monospacedDigit()
                if let notes = log.notes, !notes.isEmpty {
                    Text("\u{201C}\(notes)\u{201D}")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 2)
        }
        .listRowBackground(Color.clear)
    }
}

/// Cues — shown *below* the logging controls (see `ExerciseSummarySection`),
/// since cues are reference material worth checking before a set, not
/// something that needs to be pinned above the inputs themselves. A plain
/// native `Section` — same styling as "Today's Log"/"Last Time" — with an
/// always-visible multi-line field, no separate collapse toggle: a hand-rolled
/// Button-with-rotating-chevron header (this section's original design) read
/// as visually inconsistent with the native section headers elsewhere on
/// this page, sat at a different indentation, and (found while writing an
/// XCUITest regression check for it) didn't reliably register taps at all.
/// Cues text is short enough in practice that collapsing it isn't worth
/// reintroducing that for.
///
/// The field itself is always there and always tappable — no separate "Edit"
/// button or read/edit mode to juggle — but its row only takes on the
/// grouped-card background while it actually has keyboard focus, via the
/// same `focusedField` this page already tracks for commit-on-blur. Cues are
/// set once and read many times, so the row spends most of its life looking
/// like plain reference text (matching "Last Time" below it); the card only
/// appears for the moment you're actually typing into it, which is the same
/// visual state "Today's Log" is in all the time.
struct ExerciseCuesSection: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    private var isEditing: Bool { focusedField.wrappedValue == .cues }

    var body: some View {
        Section(header: Text("Cues").padding(.bottom, -28)) {
            TextField(
                "Add cues — form notes, setup reminders, etc.",
                text: Binding(get: { controller.cuesDraft }, set: { controller.cuesDraft = $0 }),
                axis: .vertical
            )
            .lineLimit(3...10)
            .focused(focusedField, equals: .cues)
            .padding(.top, isEditing ? 0 : -8)
        }
        .listRowBackground(isEditing ? nil : Color.clear)
        .animation(.default, value: isEditing)
    }
}

/// Past logged sessions — always expanded, same as "Last Time"/"Cues" above
/// it. Used to be a collapsed `DisclosureGroup` (a hand-rolled toggle before
/// that, which had its own tap-reliability problems — see git history), but
/// sitting at the bottom of the page it never pushes anything else down by
/// staying open, so the collapse/expand toggle wasn't buying anything besides
/// a visual mismatch with every other section header on the page. Today's
/// own entry is excluded — that's already the "Today's Log" section above,
/// showing it again here would just be the same data twice.
///
/// Clear row background, same as "Last Time"/"Cues" — reference material,
/// not something you edit, so it sits flush against the app background
/// rather than in a grouped card.
struct ExerciseHistorySection: View {
    let controller: ExerciseLogController

    private var pastLogs: [ExerciseLog] {
        controller.exercise.exerciseLogs
            .filter { !Calendar.current.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Section(header: Text("History").padding(.bottom, -28)) {
            if pastLogs.isEmpty {
                Text("No past sessions yet.")
                    .foregroundStyle(.secondary)
                    .padding(.top, -8)
            } else {
                ForEach(Array(pastLogs.enumerated()), id: \.element.id) { index, log in
                    HistoryEntryView(
                        log: log,
                        onChanged: { await controller.reloadExercise() },
                        onError: controller.onError
                    )
                    .padding(.top, index == 0 ? -8 : 0)
                }
            }
        }
        .listRowBackground(Color.clear)
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

/// The current exercise's sets + notes, as native `List` rows — meant to be
/// placed directly inside a `Section` alongside name/target (see
/// `ExercisePageList`, which now shares one `Section`/card between the two),
/// not used standalone. Leans entirely on stock components rather than
/// custom ones: a real `Stepper` for each weight/reps value instead of a
/// custom-drawn +/- button pair, and real `.swipeActions` for undoing the
/// last set instead of a persistent trash icon. An earlier version of this
/// screen reinvented both, which is most of why it read as a custom
/// "fitness dashboard" rather than an iOS form.
struct ExerciseLoggingSections: View {
    let controller: ExerciseLogController
    var focusedField: FocusState<LoggingFocusField?>.Binding

    @State private var showDeleteSetConfirm = false

    var body: some View {
        Group {
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
                            // No `role: .destructive` here — that role makes
                            // List perform its own optimistic row-collapse
                            // animation the instant the button is tapped,
                            // *before* this closure runs, regardless of
                            // whether the underlying data actually changes
                            // yet. Since nothing is deleted until the
                            // confirmation dialog below is confirmed, the row
                            // then snapped back after that animation finished
                            // — reading as "deleted, then un-deleted itself."
                            // A plain button tinted red keeps the same visual
                            // without the automatic animation.
                            //
                            // Setting `showDeleteSetConfirm` synchronously here
                            // races the swipe action's own dismissal animation —
                            // on-device (not always reproducible in the
                            // simulator), the confirmation dialog flashes and
                            // is immediately torn down before it can be tapped,
                            // and a tap landing during that window falls through
                            // to whatever's underneath rather than the dialog's
                            // own button. Deferring past the current run loop
                            // turn lets the swipe-close animation finish first.
                            Button {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    showDeleteSetConfirm = true
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
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
    /// time" peek here — the "Last Time" section elsewhere on the page
    /// already shows that, and repeating it per-row was clutter, not
    /// useful reference: you'd have to scroll away from it to compare
    /// against a value you're actively adjusting anyway.
    private func expandedSetRow(_ set: ExerciseLogController.EditableSet) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set \(set.setNumber)")
                .font(.body.weight(.medium))

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
    /// already-logged set — same tap-to-focus convention as the "Cues"
    /// field below (`ExerciseCuesSection`), not a new idiom.
    private func collapsedSetRow(_ set: ExerciseLogController.EditableSet) -> some View {
        Button {
            controller.expandedSetNumber = set.setNumber
        } label: {
            HStack {
                Text("Set \(set.setNumber)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(formatNumber(set.weight)) × \(set.reps)")
                    .font(.body)
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
                .font(.body)
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
