import XCTest

@MainActor final class SettingsQA: XCTestCase {
    private func launch(reset: Bool = true, largeType: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--settings-check"]
        if reset { app.launchArguments.append("--reset-settings-check") }
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["settings.theme"].waitForExistence(timeout: 15))
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<80 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Could not reveal \(element)")
    }
    private func back(_ app: XCUIApplication) {
        let button = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5)); button.tap()
    }
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-Settings-\(name).png"))
    }
    func testThemePersistsAndNavigationRemainsUsable() throws {
        let app = launch()
        try capture(app, "Light")
        app.buttons["settings.theme"].tap()
        XCTAssertTrue(app.navigationBars["界面主题"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.theme.system"].isSelected)
        app.buttons["settings.theme.dark"].tap()
        XCTAssertTrue(app.buttons["settings.theme.dark"].isSelected)
        XCTAssertTrue(app.staticTexts["当前显示：深色"].waitForExistence(timeout: 5))
        try capture(app, "Theme-Dark")
        back(app)
        try capture(app, "Dark")
        app.terminate()
        _ = launch(reset: false)
        app.buttons["settings.theme"].tap()
        XCTAssertTrue(app.buttons["settings.theme.dark"].isSelected)
        XCTAssertTrue(app.staticTexts["当前显示：深色"].waitForExistence(timeout: 5))
        app.buttons["settings.theme.light"].tap()
        XCTAssertTrue(app.buttons["settings.theme.light"].isSelected)
        XCTAssertTrue(app.staticTexts["当前显示：浅色"].waitForExistence(timeout: 5))
        app.buttons["settings.theme.system"].tap()
        XCTAssertTrue(app.buttons["settings.theme.system"].isSelected)
        back(app)
        app.buttons["settings.scenes"].tap()
        XCTAssertTrue(app.navigationBars["宋韵画境"].waitForExistence(timeout: 5))
        try capture(app, "Gallery")
        back(app)
        XCTAssertTrue(app.buttons["settings.about"].exists)
        app.terminate()
    }
    func testAboutAndDocumentsHaveContentAndReturnPaths() throws {
        let app = launch()
        let about = app.buttons["settings.about"]
        reveal(about, in: app); about.tap()
        try capture(app, "About-Entry")
        XCTAssertTrue(app.navigationBars["关于我们"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["settings.about.version"].exists)
        try capture(app, "About")
        let source = app.descendants(matching: .any)["settings.source.weather"].firstMatch
        reveal(source, in: app)
        XCTAssertTrue(source.isHittable)
        let terms = app.buttons["settings.about.terms"]
        reveal(terms, in: app); terms.tap()
        XCTAssertTrue(app.navigationBars["服务协议"].waitForExistence(timeout: 5))
        let termsEnd = app.staticTexts["settings.terms.end"]
        reveal(termsEnd, in: app)
        XCTAssertTrue(termsEnd.isHittable)
        back(app); back(app)
        let privacy = app.buttons["settings.privacy"]
        reveal(privacy, in: app); privacy.tap()
        XCTAssertTrue(app.navigationBars["隐私政策"].waitForExistence(timeout: 5))
        try capture(app, "Privacy")
        let permission = app.buttons["settings.privacy.permissions"]
        reveal(permission, in: app)
        XCTAssertTrue(app.staticTexts["settings.privacy.end"].exists)
        permission.tap()
        XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.Preferences").wait(for: .runningForeground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.navigationBars["隐私政策"].waitForExistence(timeout: 5))
        back(app)
        let rootTerms = app.buttons["settings.terms"]
        reveal(rootTerms, in: app); rootTerms.tap()
        XCTAssertTrue(app.navigationBars["服务协议"].waitForExistence(timeout: 5))
        back(app)
        app.terminate()
    }
    func testLocalAgreementFullTextRemainsReadable() throws {
        let app = launch()
        for (kind, title) in [("terms", "服务协议"), ("privacy", "隐私政策")] {
            let entry = app.buttons["settings.\(kind)"]
            reveal(entry, in: app); entry.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            let end = app.staticTexts["settings.\(kind).end"]
            reveal(end, in: app)
            XCTAssertTrue(end.isHittable)
            back(app)
        }
        app.terminate()
    }

    func testPolicyWebLinksStayInsideApp() throws {
        let app = launch()
        let privacy = app.buttons["settings.privacy"]
        reveal(privacy, in: app); privacy.tap()
        XCTAssertTrue(app.navigationBars["隐私政策"].waitForExistence(timeout: 5))
        for (resource, title) in [
            ("dataPrivacy", "Open-Meteo · 隐私说明"),
            ("mapsPrivacy", "Apple 地图 · 隐私说明"),
            ("hostingPrivacy", "GitHub · 网站托管隐私声明")
        ] {
            let link = app.buttons["settings.source.\(resource)"]
            reveal(link, in: app); link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
            XCTAssertEqual(app.state, .runningForeground)
            XCTAssertNotEqual(XCUIApplication(bundleIdentifier: "com.apple.mobilesafari").state, .runningForeground)
            back(app)
            XCTAssertTrue(app.navigationBars["隐私政策"].waitForExistence(timeout: 5))
        }
        let online = app.buttons["settings.privacy.online"]
        reveal(online, in: app); online.tap()
        XCTAssertTrue(app.navigationBars["在线查看隐私政策"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.staticTexts["8. 在线协议网站"].waitForExistence(timeout: 30))
        try capture(app, "Privacy-Online")

        let termsLink = app.webViews.firstMatch.links["服务协议"]
        XCTAssertTrue(termsLink.waitForExistence(timeout: 5)); termsLink.tap()
        XCTAssertTrue(app.webViews.firstMatch.staticTexts["1. 服务范围"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.state, .runningForeground)
        back(app); back(app)
        let terms = app.buttons["settings.terms"]
        reveal(terms, in: app); terms.tap()
        let dataTerms = app.buttons["settings.source.dataTerms"]
        reveal(dataTerms, in: app); dataTerms.tap()
        XCTAssertTrue(app.navigationBars["Open-Meteo · 数据许可与条款"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.state, .runningForeground)
        back(app)
        XCTAssertTrue(app.navigationBars["服务协议"].waitForExistence(timeout: 5))
        app.terminate()
    }

    func testLargeTypeThemeAndPrivacyRemainReachable() throws {
        let app = launch(largeType: true)
        let theme = app.buttons["settings.theme"]
        reveal(theme, in: app); theme.tap()
        let dark = app.buttons["settings.theme.dark"]
        reveal(dark, in: app); dark.tap()
        XCTAssertTrue(dark.isSelected)
        XCTAssertTrue(app.staticTexts["当前显示：深色"].waitForExistence(timeout: 5))
        app.swipeUp()
        try capture(app, "Large-Type")
        back(app)
        let privacy = app.buttons["settings.privacy"]
        reveal(privacy, in: app); privacy.tap()
        let end = app.staticTexts["settings.privacy.end"]
        reveal(end, in: app)
        XCTAssertTrue(end.isHittable)
        back(app)
        app.terminate()
    }
    func testArtworkAcrossHomeCitiesAndGallery() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--home-layout-check"]
        app.launch()
        XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 15))
        try capture(app, "Artwork-Home")
        app.tabBars.buttons["我的"].tap()
        try capture(app, "Artwork-Cities")
        app.tabBars.buttons["设置"].tap()
        let gallery = app.buttons["settings.scenes"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5)); gallery.tap()
        XCTAssertTrue(app.navigationBars["宋韵画境"].waitForExistence(timeout: 5))
        try capture(app, "Artwork-Gallery")

        app.buttons.containing(.staticText, identifier: "江渚烟岚").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["试试不同的天空"].waitForExistence(timeout: 5))
        try capture(app, "Artwork-Detail")
        back(app); back(app)
        app.terminate()
    }


    func testSystemAppearanceRestoredAfterExplicitLight() throws {
        let app = launch()
        app.buttons["settings.theme"].tap()
        XCTAssertTrue(app.staticTexts["当前显示：深色"].waitForExistence(timeout: 5))
        app.buttons["settings.theme.light"].tap()
        XCTAssertTrue(app.staticTexts["当前显示：浅色"].waitForExistence(timeout: 5))
        app.buttons["settings.theme.system"].tap()
        XCTAssertTrue(app.staticTexts["当前显示：深色"].waitForExistence(timeout: 5))
        try capture(app, "System-Dark")
        app.terminate()
    }

}
