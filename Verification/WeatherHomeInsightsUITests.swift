import XCTest

@MainActor final class WeatherHomeInsightsQA: XCTestCase {
    private func launch(largeType: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--home-layout-check"]
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 15))
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, limit: Int = 22) {
        for _ in 0..<limit {
            // Hittable may include a card whose center is behind the floating tabs.
            if element.exists && element.isHittable,
               element.frame.midY > app.frame.minY + 64,
               element.frame.midY < app.frame.maxY - 115 { return }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        XCTFail("Cannot reach \(element)")
    }
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-Home-\(name).png"))
    }
    private func close(_ app: XCUIApplication) {
        let button = app.buttons["home.sheet.close"]
        XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
        XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 5))
    }
    private func open(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier]
        reveal(button, in: app); button.tap()
        let opened = app.buttons["home.sheet.close"].waitForExistence(timeout: 5)
        if !opened { try? capture(app, "Failed-" + identifier); print(app.debugDescription) }
        XCTAssertTrue(opened)
        XCTAssertTrue(app.staticTexts["home.sheet.headline"].waitForExistence(timeout: 5))
    }
    func testQuickEntriesAndSheetDismissal() throws {
        let app = launch()
        try capture(app, "Refined")
        for topic in ["rain", "uv", "air"] {
            open("home.glance.\(topic)", in: app)
            try capture(app, "Sheet-\(topic)")
            close(app)
        }
        // Swipe-to-dismiss follows the same path as the close button.
        open("home.glance.rain", in: app)
        let closeButton = app.buttons["home.sheet.close"]
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: closeButton.frame.minY - 10))
        let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.maxY - 15))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(closeButton.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.glance.rain"].isHittable)
        app.terminate()
    }
    func testChecklistPersistsAndFullDetailReturns() throws {
        let app = launch()
        open("home.briefing", in: app)
        let item = app.buttons["home.packing.0"]
        reveal(item, in: app)
        if item.isSelected { item.tap() }
        item.tap(); XCTAssertTrue(item.isSelected)
        close(app)
        open("home.briefing", in: app)
        reveal(item, in: app); XCTAssertTrue(item.isSelected)
        try capture(app, "Checklist")
        let full = app.buttons["home.sheet.fullDetail"]
        reveal(full, in: app); full.tap()
        XCTAssertTrue(app.buttons["返回气象岛"].waitForExistence(timeout: 5))
        app.buttons["返回气象岛"].tap()
        XCTAssertTrue(app.buttons["home.sheet.close"].waitForExistence(timeout: 5))
        close(app)
        app.terminate()
    }
    func testHourlyDailyAndEnvironmentCards() throws {
        let app = launch()
        let hour = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.hour.")).firstMatch
        reveal(hour, in: app); hour.tap()
        XCTAssertTrue(app.buttons["home.sheet.close"].waitForExistence(timeout: 5))
        try capture(app, "Sheet-Hour")
        close(app)
        open("home.day.1", in: app)
        try capture(app, "Sheet-Day")
        close(app)
        for identifier in ["home.air", "home.metric.wind", "home.metric.humidity", "home.metric.uv", "home.metric.visibility", "home.metric.precipitation", "home.metric.feelsLike", "home.daylight", "home.life.outfit", "home.life.commute", "home.life.outdoor", "home.life.uv"] {
            open(identifier, in: app)
            close(app)
        }
        app.terminate()
    }
    func testLargeTypeSheets() throws {
        let app = launch(largeType: true)
        open("home.glance.rain", in: app)
        try capture(app, "LargeType-Rain")
        reveal(app.buttons["home.sheet.fullDetail"], in: app)
        try capture(app, "LargeType-Rain-Detail")
        close(app)
        open("home.outdoor", in: app)
        reveal(app.buttons["home.sheet.fullDetail"], in: app)
        try capture(app, "LargeType-Outdoor")
        close(app)
        // iPhone supports portrait only; inspect the scrolled card at the supported orientation.
        open("home.air", in: app)
        XCTAssertTrue(app.buttons["home.sheet.close"].isHittable)
        try capture(app, "LargeType-Air")
        close(app)
        XCUIDevice.shared.orientation = .portrait
        app.terminate()
    }
}
