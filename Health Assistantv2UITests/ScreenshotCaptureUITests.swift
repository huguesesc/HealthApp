import XCTest

/// Captures deterministic simulator screenshots of representative app states
/// for the visual-quality pass. Runs only against the DEBUG demo store
/// (launch argument `-nell-screenshot-demo`); it never touches a real user
/// store and never contacts an AI service.
final class ScreenshotCaptureUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-nell-screenshot-demo",
            "-nell.onboarding.completed", "YES",
        ]
        app.launch()
        return app
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifecycle = .keepAlways
        add(attachment)
    }

    private func selectTab(_ app: XCUIApplication, identifier: String) {
        let tab = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "missing tab \(identifier)")
        tab.tap()
        sleep(1)
    }

    func testCaptureRepresentativeStatesInDemoData() throws {
        let app = launchApp()

        // Today (populated demo day).
        _ = app.staticTexts.firstMatch.waitForExistence(timeout: 10)
        sleep(1)
        capture("01-today-populated")

        // Nell conversation with the deterministic demo transcript.
        selectTab(app, identifier: "shell.tab.nell")
        sleep(1)
        capture("02-nell-conversation")

        // Nutrition.
        selectTab(app, identifier: "shell.tab.nutrition")
        sleep(1)
        capture("03-nutrition")

        // Train home.
        selectTab(app, identifier: "shell.tab.train")
        sleep(1)
        capture("04-train-home")

        // Exercise catalogue via its tool link.
        let catalogueLink = app.staticTexts["Exercise catalogue"]
        if catalogueLink.waitForExistence(timeout: 5) {
            catalogueLink.tap()
            sleep(2)
            capture("05-exercise-catalogue")

            // First catalogue row's detail screen.
            let firstRow = app.buttons.firstMatch
            if firstRow.exists {
                firstRow.tap()
                sleep(2)
                capture("06-exercise-detail")
                app.navigationBars.buttons.firstMatch.tap()
            }
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // Active workout mid-execution from Today's resume card.
        selectTab(app, identifier: "shell.tab.today")
        let resumeTitle = app.staticTexts["Full-body reset"]
        if resumeTitle.waitForExistence(timeout: 5) {
            resumeTitle.tap()
            sleep(2)
            capture("07-active-workout")
        }

        // Settings via the logo profile button.
        let settingsButton = app.buttons["Profile and settings"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            capture("08-settings")
        }
    }
}
