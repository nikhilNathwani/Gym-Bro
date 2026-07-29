import XCTest

final class GymLogSmokeTests: XCTestCase {
    func testGoldenPath() throws {
        let app = XCUIApplication()
        app.launch()

        func screenshot(_ name: String) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        func waitAndTap(_ predicate: String, timeout: TimeInterval = 8, exact: Bool = false) {
            let format = exact ? "label == %@" : "label CONTAINS[c] %@"
            let element = app.descendants(matching: .any)
                .matching(NSPredicate(format: format, predicate))
                .firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing element: \(predicate)")
            element.tap()
        }

        // Custom-styled SwiftUI buttons sometimes get misclassified as a
        // non-Button automation type, so `app.buttons["id"]` (typed query)
        // can spuriously miss them — search all descendants by identifier
        // instead, same as waitAndTap does for labels.
        func tapId(_ identifier: String, timeout: TimeInterval = 8) {
            let element = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", identifier))
                .firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing identifier: \(identifier)")
            element.tap()
        }

        // A real SwiftUI `Stepper` bridges to UIKit's `UIStepper` under the
        // hood, which exposes its decrement/increment halves as two child
        // buttons (boundBy 0/1) rather than a single `.increment()`-able
        // element. Giving it a custom (interactive) label view — needed
        // here so the value stays directly editable — means it doesn't
        // reliably show up under the typed `app.steppers` query, so this
        // searches all descendants by identifier like `tapId` does.
        func stepperIncrement(_ identifier: String, times: Int = 1) {
            let stepper = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", identifier))
                .firstMatch
            XCTAssertTrue(stepper.waitForExistence(timeout: 8), "Missing stepper: \(identifier)")
            let incrementButton = stepper.buttons.element(boundBy: 1)
            for _ in 0..<times { incrementButton.tap() }
        }

        // RootTabView keeps both tabs' view hierarchies always mounted (to
        // preserve each tab's own nav state across switches), so a hidden
        // tab's fields still turn up in `app.textFields` queries even though
        // they're `.accessibilityHidden` — a bare `.firstMatch` is
        // ambiguous. Scope by placeholder instead.
        func textField(placeholder: String, timeout: TimeInterval = 8) -> XCUIElement {
            let element = app.textFields
                .matching(NSPredicate(format: "placeholderValue == %@", placeholder))
                .firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing text field: \(placeholder)")
            return element
        }

        // 1. Routines tab (default) -> first routine. Routine names are now
        // real stored labels the user can freely rename (not a derived
        // "Routine A - Label" pairing) — match today's actual label rather
        // than a positional string. Update this if it's renamed again.
        screenshot("00-home")
        waitAndTap("Day A - Vertical")
        screenshot("01-routine-detail")

        // 1b. The floating "+" is context-aware down to the pushed screen:
        // inside a routine it should open "Add Exercise" here, not create a
        // new routine on the list behind it. Create a disposable exercise
        // here (rather than reusing "Seated Dumbbell Overhead Press" or any
        // other real seeded exercise) and use it for all the logging/editing
        // steps below — a real exercise might already have a real "today"
        // log from the user's own phone use, and stepper taps update
        // whatever today's log already contains rather than creating
        // separate test data, so touching a real exercise here risks
        // silently mutating genuine workout data (this happened once during
        // development — see INLINE_LOGGING_HANDOFF.md).
        waitAndTap("Add", exact: true)
        waitAndTap("Add Exercise", exact: true)
        screenshot("01b-add-exercise-sheet")
        let exerciseName = "UITest Inline Logging"
        let addExerciseField = textField(placeholder: "Search or create an exercise…")
        addExerciseField.tap()
        addExerciseField.typeText(exerciseName)
        waitAndTap("Create", exact: true)
        sleep(1)
        screenshot("01c-exercise-added")

        // 2. Tapping the exercise row itself now jumps straight into the
        // workout flow AT that exercise (WorkoutSessionView with
        // startIndex set to this row's position) instead of the old full
        // edit page — exercises that specific behavior directly, rather
        // than only ever entering via Start/Continue Workout (startIndex 0)
        // and paging with Next to reach a non-first exercise.
        waitAndTap(exerciseName)
        screenshot("02-workout-session-start")

        // Also checks isHittable, not just existence — the covered routine
        // list screen underneath can still expose a matching row's text to
        // element queries even while off-screen, which would otherwise let
        // this assertion pass without actually verifying what's visible.
        let reachedTitle = app.staticTexts[exerciseName].firstMatch
        XCTAssertTrue(reachedTitle.waitForExistence(timeout: 5), "Tapping the row did not land on that exercise")
        XCTAssertTrue(reachedTitle.isHittable, "Matched exercise title isn't actually visible on screen")
        screenshot("02b-reached-new-exercise")

        // 2c. Prev/Next paging via the native bottom toolbar. We're on the
        // last exercise, so tapping Next must be a no-op (it's `.disabled`,
        // but a bottom-bar toolbar button's `.isEnabled` isn't reliably
        // exposed to XCUITest, so this checks the actual behavior instead
        // of the flag); Previous moves to the previous exercise; Next then
        // returns to this one. (An earlier version of this screen also
        // supported a swipe-over-the-reference-area shortcut for the same
        // thing, but that custom gesture fought with List's own built-in
        // swipe handling once the reference content moved into a List row
        // — dropped in favor of relying solely on the native toolbar,
        // which is always reachable anyway.)
        tapId("nextExerciseButton")
        sleep(1)
        XCTAssertTrue(app.staticTexts[exerciseName].exists, "Next should be a no-op on the last exercise")

        tapId("previousExerciseButton")
        sleep(1)
        XCTAssertFalse(app.staticTexts[exerciseName].exists, "Previous should move to the previous exercise")

        tapId("nextExerciseButton")
        sleep(1)
        XCTAssertTrue(
            app.staticTexts[exerciseName].waitForExistence(timeout: 5),
            "Next should return to the new exercise")
        screenshot("02c-after-paging")

        // 3. Log a set via the real Stepper controls, driven by identifiers
        // keyed by set number (stable regardless of persistence state).
        // Nudging weight/reps lazily creates today's exercise_log on first
        // touch.
        stepperIncrement("weight-1-stepper", times: 2)
        stepperIncrement("reps-1-stepper")
        sleep(1)
        screenshot("03-after-stepper-nudge")

        // Regression check: the weight field's width is fixed (not sized
        // to its current content — a `.fixedSize()` field was tried and
        // reverted, since it resized on every increment and shifted the
        // stepper's +/- buttons out from under a finger mid rapid-tap), so
        // it needs to already be wide enough for a longer value, or that
        // value visually truncates. Driven entirely via the stepper
        // (already proven reliable above) rather than typed keyboard
        // input — simulating keystrokes on a `.decimalPad` field via
        // XCUITest proved too unreliable to trust for this (deletes
        // silently dropped, corrupting the value instead of clearing it).
        let weightField = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "weight-1-field"))
            .firstMatch
        let widthAtOneDigit = weightField.frame.width
        stepperIncrement("weight-1-stepper", times: 38) // 5 -> 100
        screenshot("03a-weight-value-not-truncated")
        XCTAssertEqual(
            weightField.frame.width, widthAtOneDigit, accuracy: 0.5,
            "Weight field's width shouldn't change with its content — that's what shifts the stepper buttons mid-tap")
        XCTAssertGreaterThan(
            weightField.frame.width, 45,
            "Weight field should be wide enough to show a 3-digit value without truncating")

        // 3a-pre. Tapping into the weight field brings up the native
        // keyboard — it should cover the content from the bottom, not push
        // the Previous/Next bar up to stay visible above it. Dismiss via
        // the keyboard's own accessory "Done" (app.toolbars, not a generic
        // search — scoping to the keyboard toolbar specifically is what
        // makes this reliable regardless of what other "Done"-labeled
        // controls might exist elsewhere on screen).
        tapId("weight-1-field")
        sleep(1)
        screenshot("03a-pre-keyboard-open")
        let keyboardDone = app.toolbars.buttons["Done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5), "Missing keyboard accessory Done button")
        keyboardDone.tap()
        sleep(1)
        screenshot("03a-pre-keyboard-dismissed")

        tapId("addSetButton")
        sleep(1)
        let set1Row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "set-1-row"))
            .firstMatch
        let set2Row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "set-2-row"))
            .firstMatch
        XCTAssertTrue(set2Row.waitForExistence(timeout: 5), "Add set should create a second row")

        // 3a-collapse. Only one set shows its stepper at a time — adding a
        // new set should collapse the previous one (no more `weight-1-*`
        // controls visible) and make the new set the active, steppered one.
        let weight1Stepper = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "weight-1-stepper"))
            .firstMatch
        let weight2Stepper = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "weight-2-stepper"))
            .firstMatch
        XCTAssertFalse(weight1Stepper.exists, "Completed Set 1 should collapse to a read-only row")
        XCTAssertTrue(weight2Stepper.waitForExistence(timeout: 5), "New Set 2 should be the active, steppered row")
        screenshot("03a-set2-active-set1-collapsed")

        // 3a-tap-to-edit. Tapping a collapsed set's row (not a swipe — see
        // `ExerciseLoggingSections.collapsedSetRow`) re-expands its
        // steppers and collapses whichever set was previously active. Same
        // tap-to-expand convention as the "Cues" header lower on this
        // screen, not a new one-off gesture.
        //
        // `set1Row` is the invisible full-size background marker (see the
        // comment where it's built), not the row's real frontmost content —
        // `.tap()` on it fails XCUITest's "isHittable" check for that
        // reason (same non-issue `.swipeLeft()` below sidesteps by being a
        // coordinate-based gesture, not a hittability-checked one), so this
        // taps its center coordinate directly instead.
        set1Row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(weight1Stepper.waitForExistence(timeout: 5), "Tapping Set 1's row should re-expand its steppers")
        XCTAssertFalse(weight2Stepper.exists, "Only one set should be expanded at a time")
        screenshot("03a-set1-reexpanded-via-tap")

        // Real `.swipeActions`, not a persistent trash icon — swipe the row
        // to reveal the destructive "Delete" action, then tap it. Set 2 is
        // collapsed at this point (Set 1 is the active one above), which
        // also exercises that the swipe/delete affordance still works on a
        // collapsed row, not just an active one.
        set2Row.swipeLeft()
        waitAndTap("Delete", exact: true)
        sleep(1)
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "set-2-row"))
                .firstMatch.exists,
            "Deleting the last set should remove its row")
        screenshot("03b-set-added-then-deleted")

        // 3b. Regression check for the reported bug: tapping inert row
        // content ("Set 1" here, not a control and not the "Open full
        // exercise page" link) must NOT navigate away. This used to happen
        // because InlineExerciseCard sat inside a List row that also
        // contained a NavigationLink, and List makes the whole row
        // tappable-through to any NavigationLink nested in it — the Sets
        // section's rows here have no NavigationLink in them at all, so
        // this is now structurally not possible, but the assertion stays
        // as regression insurance.
        waitAndTap("Set 1", exact: true)
        XCTAssertTrue(app.staticTexts[exerciseName].exists, "Tapping inert row content should not navigate away")

        // 4. Open the full exercise page from its explicit link only.
        waitAndTap("Open full exercise page")
        screenshot("04-exercise-detail")

        let nameField = textField(placeholder: "Exercise name")
        nameField.tap()
        nameField.typeText(" (edited)")
        waitAndTap("History")
        sleep(1)
        screenshot("05-name-edited")

        // Back to the workout session (single pop within the same
        // NavigationStack), then back again to exit the session to the
        // routine's plain list. No separate "Done" button anymore — this
        // screen is pushed, not presented as a sheet, so the standard back
        // chevron is the only exit affordance now (see WorkoutSessionView).
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        // The button relabels to "Continue Workout" once today has any
        // logged sets in the routine, and the exercise row shows an inline
        // "100×1" preview of what's been logged (weight ends at "100"
        // after the truncation regression check above drove it there via
        // the stepper; reps-1-plus x1 from step 3, starting from 0)
        // instead of a bare checkmark.
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", "Continue Workout"))
                .firstMatch.waitForExistence(timeout: 5),
            "Start Workout should relabel to Continue Workout once something's logged today")
        XCTAssertTrue(app.staticTexts["100×1"].waitForExistence(timeout: 5), "Missing inline logged-sets preview in the list")
        screenshot("06-logged-preview-in-list")

        // 4b. The Start/Continue Workout button is a separate entry point
        // (always startIndex 0) from tapping a row directly — confirm it
        // still navigates correctly too, now that step 2 no longer
        // exercises it.
        waitAndTap("Workout")
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", "previousExerciseButton"))
                .firstMatch.waitForExistence(timeout: 5),
            "Continue Workout button did not navigate into the workout flow")
        screenshot("06b-continue-workout-button")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)

        // 5. Edit mode: native List with delete/reorder controls, the
        // inline logged preview should still show there too.
        waitAndTap("Edit", exact: true)
        screenshot("07-edit-mode")
        waitAndTap("Done", exact: true)

        // Back to the routines list.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        screenshot("08-back-to-routines")

        // 7. Tab-bar-inline "+" creates a routine (context-aware: Routines
        // tab is active), then delete it via the Edit view's "Delete this
        // routine" button (self-cleaning). Replaces the old "..." menu,
        // which felt like overkill for a single destructive action.
        waitAndTap("Add", exact: true)
        sleep(1)
        screenshot("09-new-routine-created")
        waitAndTap("Edit", exact: true)
        waitAndTap("Delete this routine", exact: true)
        waitAndTap("Delete", exact: true)
        sleep(1)
        screenshot("10-back-after-delete")

        // 8. Exercises tab.
        waitAndTap("Exercises", exact: true)
        sleep(1)
        screenshot("11-exercise-library")

        // 9. Same tab-bar "+", now context-aware for creating an exercise.
        waitAndTap("Add", exact: true)
        screenshot("12-new-exercise-sheet")
        let newNameField = textField(placeholder: "Name")
        newNameField.tap()
        newNameField.typeText("UITest Cable Curl")
        waitAndTap("Create", exact: true)
        sleep(1)
        screenshot("13-exercise-created")

        // 10. Cleanup — delete both disposable exercises this run created
        // (the inline-logging one from step 3, and this one) via the
        // library's real `.swipeActions` + confirmation dialog. Previously
        // missing: a prior run's leftover "UITest Inline Logging" and
        // "UITest Cable Curl" rows piled up across repeated runs (five
        // stale copies found and manually purged from Supabase while
        // debugging this), and two same-named exercises sitting in the
        // same routine at once broke the Prev/Next assertions above
        // (`exists` no longer distinguishes "moved away" from "landed on
        // the other copy"). Deleting an exercise cascades to its
        // exercise_logs/set_logs/routine_exercises rows, so this is enough
        // to fully undo everything this test created.
        // Substring match, not exact — step 4 above renamed the first
        // exercise mid-string (typed " (edited)" wherever the cursor
        // landed after `.tap()`, not necessarily at the end), so its
        // persisted name is no longer the literal `exerciseName` value.
        func deleteExercise(matching substring: String) {
            let row = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@", substring))
                .firstMatch
            guard row.waitForExistence(timeout: 5) else { return }
            row.swipeLeft()
            waitAndTap("Delete", exact: true)
            waitAndTap("Delete", exact: true) // confirmationDialog's own button
            sleep(1)
        }
        deleteExercise(matching: "UITest Cable Curl")
        deleteExercise(matching: "UITest Inline")
        screenshot("14-cleanup-complete")
    }
}
