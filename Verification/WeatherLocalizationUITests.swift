import XCTest

@MainActor final class LocalizationQA: XCTestCase {
    private func launch(_ language: String?, flags: [String] = ["--home-layout-check"], large: Bool = false, system: [String]? = nil) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = flags
        if let language { app.launchArguments += ["--app-language", language] }
        if let system { app.launchArguments += ["-AppleLanguages", "(" + system.joined(separator: ",") + ")"] }
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        return app
    }
    private func capture(_ app: XCUIApplication, _ locale: String, _ name: String) throws {
        let url = URL(fileURLWithPath: "/tmp/WeatherIsland-Localization/\(locale)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: url.appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = locale + "-" + name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 90 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap() }
    func testLocalizedStoreCaptures() throws {
        for (code, locale, settings, _) in [("en", "en-US", "Settings", "Weather"), ("vi", "vi", "Cài đặt", "Thời tiết"), ("zh-Hans", "zh-Hans", "设置", "天气")] {
            var app = launch(code)
            XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 15))
            try capture(app, locale, "Weather-Artwork-Home")
            app.tabBars.buttons[settings].tap()
            XCTAssertTrue(app.buttons["settings.scenes"].waitForExistence(timeout: 5))
            app.buttons["settings.scenes"].tap()
            XCTAssertTrue(app.buttons["scene.0"].waitForExistence(timeout: 8))
            try capture(app, locale, "Weather-Artwork-Gallery")
            app.buttons["scene.0"].tap()
            XCTAssertTrue(app.buttons["scene.apply"].waitForExistence(timeout: 5))
            try capture(app, locale, "Weather-Artwork-Detail")
            app.terminate()
            app = launch(code, flags: ["--map-preview"])
            XCTAssertTrue(app.tabBars.firstMatch.exists)
            try capture(app, locale, "Weather-Map-Layout-Phone")
            app.terminate()
            app = launch(code, flags: ["--cities-check", "--cities-preview"])
            XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 10))
            try capture(app, locale, "Weather-Artwork-Cities")
            app.terminate()
            app = launch(code, flags: ["--home-layout-check"])
            XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 15))
            try capture(app, locale, "Weather-Home-Manual-City")
            app.terminate()
        }
    }
    func testSwitchPersistenceAndSystemFallback() throws {
        let app = launch("en", flags: ["--settings-check", "--reset-settings-check"])
        XCTAssertTrue(app.buttons["settings.language"].waitForExistence(timeout: 10))
        app.buttons["settings.language"].tap()
        try capture(app, "en-US", "Settings-Language-Entry")
        XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 15))
        app.buttons["language.vi"].tap()
        XCTAssertTrue(app.buttons["language.vi"].isSelected)
        try capture(app, "vi", "Settings-Language")
        back(app)
        XCTAssertTrue(app.staticTexts["Đảo Thời Tiết"].exists)
        app.terminate()
        let restored = launch(nil, flags: ["--settings-check"])
        restored.buttons["settings.language"].tap()
        XCTAssertTrue(restored.buttons["language.vi"].waitForExistence(timeout: 5))
        XCTAssertTrue(restored.buttons["language.vi"].isSelected)
        restored.buttons["language.zh-Hans"].tap()
        XCTAssertTrue(restored.buttons["language.zh-Hans"].isSelected)
        back(restored)
        XCTAssertTrue(restored.staticTexts["气象岛"].exists)
        restored.buttons["settings.language"].tap()
        restored.buttons["language.system"].tap()
        XCTAssertTrue(restored.buttons["language.system"].isSelected)
        restored.terminate()
        let fallback = launch("system", system: ["fr-FR", "en-US"])
        XCTAssertTrue(fallback.tabBars.buttons["Settings"].exists)
        fallback.terminate()
        let ordered = launch("system", system: ["fr-FR", "vi-VN", "en-US"])
        XCTAssertTrue(ordered.tabBars.buttons["Cài đặt"].exists)
        ordered.terminate()
    }
    func testThreeLanguagesLargeTypePortraitAndDark() throws {
        for (code, locale, settings) in [("en", "en-US", "Settings"), ("vi", "vi", "Cài đặt"), ("zh-Hans", "zh-Hans", "设置")] {
            let app = launch(code, large: true)
            XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 15))
            try capture(app, locale, "QA-Large-Type")
            XCTAssertGreaterThan(app.frame.height, app.frame.width)
            try capture(app, locale, "QA-Portrait")
            app.tabBars.buttons[settings].tap()
            reveal(app.buttons["settings.theme"], app); app.buttons["settings.theme"].tap()
            XCTAssertTrue(app.buttons["settings.theme.dark"].waitForExistence(timeout: 5))
            app.buttons["settings.theme.dark"].tap()
            app.tabBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 10))
            try capture(app, locale, "QA-Dark")
            app.terminate()
        }
    }
}
