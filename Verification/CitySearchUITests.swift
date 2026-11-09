import XCTest

@MainActor final class CitySearchQA: XCTestCase {
    private func launch(live: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--cities-check", "--reset-cities-check"]
        if !live { app.launchArguments.append("--city-search-check") }
        app.launch()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 15))
        return app
    }
    private func add(_ app: XCUIApplication) {
        let button = app.buttons["cities.add"]
        for _ in 0..<8 {
            if button.exists && button.isHittable { break }
            app.swipeUp()
        }
        button.tap()
        XCTAssertTrue(app.textFields["cities.search.query"].waitForExistence(timeout: 5))
    }
    private func search(_ query: String, in field: XCUIElement) {
        field.tap()
        if let current = field.value as? String, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(query)
    }
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let image = app.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-Search-\(name).png"))
    }
    func testChineseAndEnglishSearchAndSave() throws {
        let app = launch()
        add(app)
        let field = app.textFields["cities.search.query"]
        for (query, id, country) in [("东京", 1850147, "日本"), ("Tokyo", 1850147, "日本"),
                                      ("纽约", 5128581, "美国"), ("New York", 5128581, "美国"),
                                      ("洛杉矶", 5368361, "美国"), ("Los Angeles", 5368361, "美国")] {
            search(query, in: field)
            let result = app.buttons["cities.search.global.\(id)"]
            XCTAssertTrue(result.waitForExistence(timeout: 8), query)
            XCTAssertTrue(result.label.contains(country), result.label)
        }
        try capture(app, "LosAngeles")
        app.buttons["cities.search.global.5368361"].tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["cities.row.Tokyo"].value as? String, "正在查看")
        XCTAssertTrue(app.buttons["cities.row.洛杉矶"].exists)
        XCTAssertEqual(app.buttons["cities.row.上海市"].value as? String, "默认城市")
        app.terminate()
        app.launchArguments = ["--cities-check", "--city-search-check"]
        app.launch()
        XCTAssertTrue(app.buttons["cities.row.洛杉矶"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons["cities.row.Tokyo"].value as? String, "正在查看")
    }
    func testChangedQueryEmptyFailureAndRetry() throws {
        let app = launch()
        add(app)
        let field = app.textFields["cities.search.query"]
        search("Tokyo", in: field)
        search("New York", in: field)
        XCTAssertTrue(app.buttons["cities.search.global.5128581"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["cities.search.global.1850147"].exists)
        search("zzzzunknown", in: field)
        XCTAssertTrue(app.staticTexts["cities.search.empty"].waitForExistence(timeout: 5))
        search("networkerror", in: field)
        XCTAssertTrue(app.staticTexts["cities.search.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["cities.search.empty"].exists)
        XCTAssertTrue(app.buttons["cities.search.retry"].exists)
        app.buttons["cities.search.retry"].tap()
        XCTAssertTrue(app.staticTexts["cities.search.error"].waitForExistence(timeout: 5))
        search("Los Angeles", in: field)
        XCTAssertTrue(app.buttons["cities.search.global.5368361"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["cities.search.error"].exists)
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
    }
    func testExistingCityInAnotherLanguageDoesNotDuplicate() throws {
        let app = launch()
        add(app)
        search("東京", in: app.textFields["cities.search.query"])
        let result = app.buttons["cities.search.global.1850147"]
        XCTAssertTrue(result.waitForExistence(timeout: 8)); result.tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["cities.count"].label, "收藏城市 · 3")
        XCTAssertEqual(app.buttons["cities.row.Tokyo"].value as? String, "正在查看")
        XCTAssertFalse(app.buttons["cities.row.东京"].exists)
    }
    func testLiveForeignCitySearch() throws {
        let app = launch(live: true)
        add(app)
        let field = app.textFields["cities.search.query"]
        for (query, id) in [("东京", 1850147), ("Tokyo", 1850147), ("纽约", 5128581),
                            ("New York", 5128581), ("洛杉矶", 5368361), ("Los Angeles", 5368361)] {
            search(query, in: field)
            XCTAssertTrue(app.buttons["cities.search.global.\(id)"].waitForExistence(timeout: 20), query)
        }
        try capture(app, "LiveLosAngeles")
        app.buttons["cities.search.global.5368361"].tap()
        XCTAssertTrue(app.buttons["cities.row.洛杉矶"].waitForExistence(timeout: 5))
    }
    func testMapUsesGlobalResults() throws {
        let app = launch()
        app.tabBars.buttons["地图"].tap()
        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "搜索或切换城市")).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 8)); picker.tap()
        let field = app.textFields["map.search.query"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        search("纽约", in: field)
        let result = app.buttons["map.search.global.5128581"]
        XCTAssertTrue(result.waitForExistence(timeout: 8)); result.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "当前纽约市")).firstMatch.waitForExistence(timeout: 8))
        app.tabBars.buttons["我的"].tap()
        XCTAssertEqual(app.buttons["cities.row.Tokyo"].value as? String, "正在查看")
    }
}
