import XCTest

final class GymBroSmokeTests: XCTestCase {
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

        // Non-asserting existence check, for loop conditions (unlike tapId,
        // which fails the test if the element is missing).
        func exists(id identifier: String) -> Bool {
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == %@", identifier))
                .firstMatch
                .exists
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

        // 2. "Start Workout" -> full-screen one-exercise-at-a-time flow (see
        // WorkoutSessionView), landing on the routine's first exercise. The
        // one we just created is appended last (highest sort_order), so
        // page forward with Next until it's reached rather than assuming a
        // fixed exercise count.
        waitAndTap("Start Workout", exact: true)
        screenshot("02-workout-session-start")

        var advanceGuard = 0
        while exists(id: "nextExerciseButton") && advanceGuard < 20 {
            tapId("nextExerciseButton")
            advanceGuard += 1
        }
        XCTAssertTrue(app.staticTexts[exerciseName].waitForExistence(timeout: 5), "Did not page to the new exercise")
        screenshot("02b-reached-new-exercise")

        // 3. Log a set via the stepper controls, driven by identifiers keyed
        // by set number (stable regardless of persistence state). Nudging
        // weight/reps lazily creates today's exercise_log on first touch.
        tapId("weight-1-plus")
        tapId("weight-1-plus")
        tapId("reps-1-plus")
        sleep(1)
        screenshot("03-after-stepper-nudge")

        // 3b. Regression check for the reported bug: tapping inert card
        // content (a column header here, not a control and not the "Open
        // full exercise page" link) must NOT navigate away. This used to
        // happen because InlineExerciseCard sat inside a List row that also
        // contained a NavigationLink, and List makes the whole row
        // tappable-through to any NavigationLink nested in it — fixed by
        // moving this content out of a List entirely (WorkoutSessionView is
        // a plain ScrollView).
        waitAndTap("WEIGHT", exact: true)
        XCTAssertTrue(app.staticTexts[exerciseName].exists, "Tapping inert card content should not navigate away")

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
        // NavigationStack), then "Done" to exit the session back to the
        // routine's plain list.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        waitAndTap("Done", exact: true)
        sleep(1)
        screenshot("06-checkmark-in-list")

        // 5. Edit mode: native List with delete/reorder controls, checkmark
        // should still show there too.
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
    }
}
