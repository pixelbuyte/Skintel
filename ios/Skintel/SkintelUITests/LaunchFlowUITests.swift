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
        let getStarted = app.buttons["Get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 8), "Welcome screen should appear after the splash")
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
