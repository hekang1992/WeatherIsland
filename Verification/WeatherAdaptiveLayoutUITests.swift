import XCTest

/// Run on Duo and a compact iPhone. Uses explicit demo data, with no network or location prompts.
@MainActor final class WeatherAdaptiveLayoutQA: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertVisible(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(element.isHittable, "Control must remain reachable: \(element)", file: file, line: line)
        let bounds = app.frame.insetBy(dx: -1, dy: -1)
        XCTAssertTrue(bounds.contains(element.frame), "Control exceeds the current display: \(element.frame), display: \(bounds)", file: file, line: line)
    }

    func testHomeDetailAndTheatreAcrossRotation() {
        let app = launch(["--home-layout-check", "--temperature=-18"])
        assertVisible(app.buttons["home.city"], in: app)
        assertVisible(app.descendants(matching: .any).matching(identifier: "home.temperature").firstMatch, in: app)
        capture(app, "Home portrait")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "打开天气详情")).firstMatch.tap()
        assertVisible(app.buttons["返回气象岛"], in: app)
        capture(app, "Detail portrait")
        XCUIDevice.shared.orientation = .landscapeLeft
        assertVisible(app.buttons["返回气象岛"], in: app)
        capture(app, "Detail landscape")
        app.buttons["返回气象岛"].tap()
        assertVisible(app.buttons["home.city"], in: app)
        app.buttons["打开天气剧场"].tap()
        assertVisible(app.buttons["关闭天气剧场"], in: app)
        capture(app, "Theatre landscape")
        app.buttons["关闭天气剧场"].tap()
        XCUIDevice.shared.orientation = .portrait
        assertVisible(app.buttons["home.city"], in: app)
        app.terminate()
    }

    func testMapControlsRemainReachableAcrossRotation() {
        let app = launch(["--map-preview"])
        for name in ["降水图层", "气温图层", "风速图层", "云量图层", "回到所选城市", "未来66小时", "播放预报"] {
            assertVisible(app.buttons[name], in: app)
        }
        capture(app, "Map portrait")
        app.buttons["气温图层"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        for name in ["降水图层", "气温图层", "风速图层", "云量图层", "回到所选城市", "未来66小时", "播放预报"] {
            assertVisible(app.buttons[name], in: app)
        }
        app.buttons["未来66小时"].tap()
        assertVisible(app.sliders["预报时间"], in: app)
        app.sliders["预报时间"].adjust(toNormalizedSliderPosition: 0.5)
        capture(app, "Map landscape")
        XCUIDevice.shared.orientation = .portrait
        assertVisible(app.buttons["云量图层"], in: app)
        app.terminate()
    }
}
