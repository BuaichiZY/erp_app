import XCTest

final class LayoutTests: XCTestCase {
    func testDesktopNavigationOnWideIPad() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-skipIntroduction"]
        app.launch()
        XCTAssertTrue(app.buttons["探索"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["广场"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "iPad desktop layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
