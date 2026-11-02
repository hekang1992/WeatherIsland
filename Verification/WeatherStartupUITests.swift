import XCTest

@MainActor final class StartupQA: XCTestCase {
    func testPendingNetworkThenAutomaticEntry() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--startup-connection-check"]
        app.launch()
        XCTAssertTrue(app.staticTexts["正在接通天空"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.tabBars.buttons["天气"].exists, "Empty home must remain hidden while access is pending")
        capture(app, name: "Startup connecting")
        XCTAssertTrue(app.staticTexts["等待天气来信"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["检查网络设置"].exists)
        XCTAssertTrue(app.buttons["稍后进入"].exists)
        capture(app, name: "Startup waiting")
        XCTAssertTrue(app.tabBars.buttons["天气"].waitForExistence(timeout: 65), "Home should enter automatically when weather arrives")
        XCTAssertTrue(app.staticTexts["未来怎么变"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["正在接通天空"].exists)
        capture(app, name: "Startup recovered")
        app.tabBars.buttons["地图"].tap()
        app.tabBars.buttons["天气"].tap()
        XCTAssertTrue(app.staticTexts["未来怎么变"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testContinueWhileOffline() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--startup-connection-check"]
        app.launch()
        XCTAssertTrue(app.buttons["稍后进入"].waitForExistence(timeout: 15))
        app.buttons["稍后进入"].tap()
        XCTAssertTrue(app.tabBars.buttons["天气"].waitForExistence(timeout: 5))
        app.tabBars.buttons["设置"].tap()
        XCTAssertTrue(app.staticTexts["宋韵画境"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testManualRetryDuringRecovery() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--startup-connection-check"]
        app.launch()
        XCTAssertTrue(app.buttons["重新连接"].waitForExistence(timeout: 15))
        app.buttons["重新连接"].tap()
        XCTAssertTrue(app.tabBars.buttons["天气"].waitForExistence(timeout: 65))
        XCTAssertTrue(app.staticTexts["未来怎么变"].waitForExistence(timeout: 10))
        app.terminate()
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
