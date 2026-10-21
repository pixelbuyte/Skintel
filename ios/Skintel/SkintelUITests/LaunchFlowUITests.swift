import XCTest

/// Runs against a fresh simulator (empty Keychain → signed-out). No network needed.
final class LaunchFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testWelcomeShowsAndRoutesToSignUpAndSignIn() {
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 8), "Welcome screen should appear after the splash")
        next.tap()
        XCTAssertTrue(app.staticTexts["Create an account and you get:"].waitForExistence(timeout: 4), "Page 2 lists the free benefits")
        app.buttons["Next"].tap()
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 4), "Last page ends on Get started")
        getStarted.tap()
        XCTAssertTrue(app.staticTexts["Create your account."].waitForExistence(timeout: 4))

        app.buttons["Back"].firstMatch.tap()
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.staticTexts["Welcome back."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Continue with Apple"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS 'Apple'")).firstMatch.exists)
    }

    func testSignInFormValidatesBeforeSubmitting() {
        app.buttons["I already have an account"].tap()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 4))
        XCTAssertFalse(continueButton.isEnabled, "Submit stays disabled until email + 8-char password")

        app.textFields["you@email.com"].tap()
        app.textFields["you@email.com"].typeText("riya@example.com")
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("hunter2hunter2")
        XCTAssertTrue(continueButton.isEnabled)
    }

    func testForgotPasswordSwitchesMode() {
        app.buttons["I already have an account"].tap()
        XCTAssertTrue(app.buttons["Forgot password?"].waitForExistence(timeout: 4))
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.staticTexts["Reset your password."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Send reset link"].exists)
    }
}

/// Not a correctness test: drives a signed-in tour of the app for the Codemagic
/// `ios-recording` workflow, which records the simulator screen while this runs.
/// Skips unless the demo account is passed in (xcodebuild forwards
/// TEST_RUNNER_SKINTEL_DEMO_EMAIL / _PASSWORD to the runner without the prefix),
/// so `ios-ci` never signs in. Steps are best-effort: a missing element is
/// skipped rather than failing, because the point is the footage.
final class AppTourRecording: XCTestCase {
    func testRecordAppTour() throws {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["SKINTEL_DEMO_EMAIL"], let password = env["SKINTEL_DEMO_PASSWORD"],
              !email.isEmpty, !password.isEmpty else {
            throw XCTSkip("No demo account; this only runs in the ios-recording workflow.")
        }
        continueAfterFailure = true

        let app = XCUIApplication()
        app.launch()

        // Sign in through the real form.
        let haveAccount = app.buttons["I already have an account"]
        if haveAccount.waitForExistence(timeout: 12) {
            pause(1.5)
            haveAccount.tap()
            let emailField = app.textFields["you@email.com"]
            if emailField.waitForExistence(timeout: 5) {
                emailField.tap()
                emailField.typeText(email)
            }
            let passwordField = app.secureTextFields["Password"]
            if passwordField.waitForExistence(timeout: 3) {
                passwordField.tap()
                passwordField.typeText(password)
            }
            pause(0.8)
            app.buttons["Continue"].tap()
        }

        guard app.buttons["Today"].waitForExistence(timeout: 30) else {
            XCTFail("Never reached the main tabs; check the demo account has finished onboarding.")
            return
        }
        pause(2)
        dismissExtras(app)
        browse(app)

        for tab in ["Shelf", "Ask", "Insights"] {
            let button = app.buttons[tab]
            guard button.exists else { continue }
            button.tap()
            pause(2.5)
            dismissExtras(app)
            browse(app)
        }

        // You → Skintel+ plans.
        let you = app.buttons["You"]
        if you.exists {
            you.tap()
            pause(2)
            let upgrade = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Get Skintel+'")).firstMatch
            if upgrade.waitForExistence(timeout: 3) {
                upgrade.tap()
                pause(4)
                app.swipeUp()
                pause(3)
            }
        }
    }

    /// Scroll down and back so the screen's content shows on video.
    private func browse(_ app: XCUIApplication) {
        app.swipeUp()
        pause(1.5)
        app.swipeDown()
        pause(1.2)
    }

    /// Closes first-visit tips and prompts that would cover the screen.
    private func dismissExtras(_ app: XCUIApplication) {
        for label in ["Not now", "Later", "Maybe later", "Skip", "Got it", "Continue with Free"] {
            let button = app.buttons[label].firstMatch
            if button.exists && button.isHittable {
                button.tap()
                pause(0.8)
            }
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pause")], timeout: seconds)
    }
}
