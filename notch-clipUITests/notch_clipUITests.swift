import XCTest

final class notch_clipUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMenuBarUtilityLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        let launchedForeground = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(launchedForeground || app.state == .runningBackground)
    }
}
