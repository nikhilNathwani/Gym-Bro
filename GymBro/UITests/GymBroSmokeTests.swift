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

        // 1. Routines list -> Routine A
        screenshot("00-home")
        waitAndTap("Routine A")
        screenshot("01-routine-detail")

        // 2. Expand first exercise accordion card
        waitAndTap("Seated Dumbbell Overhead Press")
        screenshot("02-accordion-expanded")

        // 3. Log a set via the custom keypad, driven by identifiers (not
        // labels) so it's stable regardless of prior test-run data changing
        // the suggestion chips shown.
        app.buttons["weightField"].tap()
        screenshot("03-weight-keypad-open")
        app.buttons["key-2"].tap()
        app.buttons["key-5"].tap()
        app.buttons["keypadDone"].tap()

        app.buttons["repsField"].tap()
        app.buttons["key-1"].tap()
        app.buttons["key-2"].tap()
        app.buttons["keypadDone"].tap()
        screenshot("04-sets-entered")

        waitAndTap("Save entry", exact: true)
        sleep(2)
        screenshot("05-after-log-save")

        // 4. Edit mode: native List with delete/reorder controls.
        waitAndTap("Edit", exact: true)
        screenshot("06-edit-mode")
        waitAndTap("Done", exact: true)

        // 5. Re-expand and open the full exercise page.
        waitAndTap("Seated Dumbbell Overhead Press")
        waitAndTap("Open full exercise page")
        screenshot("07-exercise-detail")

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(" (edited)")
        waitAndTap("History")
        screenshot("08-name-edited")

        // 6. Back to routines list, then Exercises library.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        sleep(1)
        screenshot("09-back-to-routines")

        waitAndTap("Exercises", exact: true)
        screenshot("10-exercise-library")

        // 7. Create a new exercise via the sheet (before touching search, so
        // there's no need to programmatically dismiss search focus after).
        app.buttons["newExerciseButton"].tap()
        screenshot("11-new-exercise-sheet")
        let newNameField = app.textFields.firstMatch
        XCTAssertTrue(newNameField.waitForExistence(timeout: 5))
        newNameField.tap()
        newNameField.typeText("UITest Cable Curl")
        waitAndTap("Create", exact: true)
        sleep(1)
        screenshot("12-exercise-created")

        // 8. Search, as the final step.
        app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("Dumbbell")
        screenshot("13-search-results")
    }
}
