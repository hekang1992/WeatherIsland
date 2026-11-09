import XCTest

@MainActor final class WeatherSavedCitiesQA: XCTestCase {
    private func launch(reset: Bool = true, location: Bool = false, largeType: Bool = false, preview: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--cities-check"]
        if reset { app.launchArguments.append("--reset-cities-check") }
        if preview { app.launchArguments.append("--cities-preview") }
        if location { app.launchArguments.append("--cities-current-location") }
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 15))
        return app
    }
    private func row(_ city: String, _ app: XCUIApplication) -> XCUIElement { app.buttons["cities.row." + city] }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<24 {
            if element.exists && element.isHittable && element.frame.midY < app.frame.maxY - 95 && element.frame.midY > 100 { return }
            let reverse = element.exists && element.frame.midY < 100
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: reverse ? 0.4 : 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: reverse ? 0.72 : 0.4))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        try? capture(app, "Unreachable")
        print(app.debugDescription)
        XCTFail("Cannot reach \(element)")
    }
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-Cities-\(name).png"))
    }
    private func addLondon(_ app: XCUIApplication) {
        let add = app.buttons["cities.add"]; reveal(add, app); add.tap()
        let shortcut = app.buttons["cities.search.add.London"]
        XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
        shortcut.tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
    }
    func testSaveStaysOnMyAndPersistsWithoutSelecting() throws {
        let app = launch()
        XCTAssertEqual(row("Tokyo", app).value as? String, "正在查看")
        XCTAssertEqual(row("上海市", app).value as? String, "默认城市")
        try capture(app, "Overview")
        let add = app.buttons["cities.add"]; reveal(add, app); add.tap()
        XCTAssertTrue(app.buttons["cities.search.add.London"].waitForExistence(timeout: 5))
        try capture(app, "Add")
        app.buttons["cities.search.add.London"].tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
        XCTAssertEqual(row("Tokyo", app).value as? String, "正在查看")
        XCTAssertTrue(row("London", app).exists)
        app.terminate()
        _ = launch(reset: false)
        XCTAssertTrue(row("London", app).exists)
        XCTAssertEqual(row("Tokyo", app).value as? String, "正在查看")
        XCTAssertEqual(app.staticTexts["cities.count"].label, "收藏城市 · 4")
    }
    func testEditDisablesNavigationAndCanDelete() throws {
        let app = launch()
        app.buttons["cities.edit"].tap()
        XCTAssertFalse(row("Tokyo", app).exists)
        XCTAssertFalse(app.buttons["cities.location"].isEnabled)
        XCTAssertFalse(app.buttons["cities.add"].exists)
        try capture(app, "Editing")
        // List editing must retain native delete controls while the row has no navigation button.
        let delete = app.images.matching(identifier: "minus.circle.fill").firstMatch
        XCTAssertTrue(delete.exists, app.debugDescription)
        let reorder = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reorder ' OR label BEGINSWITH '重新排序'")).firstMatch
        XCTAssertTrue(reorder.exists)
        app.staticTexts["cities.row.Tokyo"].tap()
        XCTAssertEqual(app.buttons["cities.edit"].label, "完成")
        delete.tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Delete' OR label == '删除'" )).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3)); confirm.tap()
        XCTAssertEqual(app.staticTexts["cities.count"].label, "收藏城市 · 2")
        app.buttons["cities.edit"].tap()
        XCTAssertTrue(row("Tokyo", app).isEnabled)
        row("Tokyo", app).tap()
        XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.city"].label.contains("Tokyo"))
    }
    func testDefaultAndDeletingViewedCity() throws {
        let app = launch()
        row("北京市", app).press(forDuration: 1)
        let makeDefault = app.buttons["设为默认城市"]
        XCTAssertTrue(makeDefault.waitForExistence(timeout: 3)); makeDefault.tap()
        XCTAssertEqual(row("北京市", app).value as? String, "默认城市")
        XCTAssertEqual(row("Tokyo", app).value as? String, "正在查看")
        row("Tokyo", app).press(forDuration: 1)
        app.buttons["删除城市"].tap()
        XCTAssertFalse(row("Tokyo", app).exists)
        XCTAssertEqual(row("北京市", app).value as? String, "正在查看，默认城市")
        XCTAssertTrue(app.buttons["cities.edit"].exists)
        app.terminate(); _ = launch(reset: false)
        XCTAssertEqual(row("北京市", app).value as? String, "正在查看，默认城市")
    }
    func testSavePreservesCurrentLocation() throws {
        let app = launch(location: true)
        XCTAssertTrue(app.buttons["cities.location"].label.contains("正在查看"))
        addLondon(app)
        XCTAssertTrue(app.buttons["cities.location"].label.contains("正在查看"))
        XCTAssertFalse((row("上海市", app).value as? String ?? "").contains("正在查看"))
        app.terminate(); _ = launch(reset: false)
        XCTAssertTrue(app.buttons["cities.location"].label.contains("正在查看"))
        XCTAssertTrue(row("London", app).exists)
    }
    func testLargeTypeControlsAndSavedSelection() throws {
        let app = launch(largeType: true)
        try capture(app, "LargeType")
        let tokyo = row("Tokyo", app); reveal(tokyo, app)
        try capture(app, "LargeType-Cities")
        addLondon(app)
        let london = row("London", app); reveal(london, app)
        XCTAssertTrue(london.isHittable)
        london.tap()
        XCTAssertTrue(app.buttons["home.city"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.city"].label.contains("London"))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("London", app).isEnabled)
    }
    private func manage(_ city: String, _ app: XCUIApplication) {
        let button = app.buttons["cities.manage." + city]
        reveal(button, app); button.tap()
        XCTAssertTrue(app.staticTexts["cities.management.title"].waitForExistence(timeout: 5))
    }
    func testVisibleManagementDeletesDefaultAndExplainsLastCity() throws {
        let app = launch()
        manage("上海市", app)
        let explanation = app.staticTexts["cities.management.explanation"].label
        XCTAssertTrue(explanation.contains("北京市") && explanation.contains("将接替默认城市"), explanation)
        try capture(app, "Manage-Default")
        app.buttons["cities.management.delete"].tap()
        XCTAssertFalse(row("上海市", app).exists)
        XCTAssertEqual(row("北京市", app).value as? String, "默认城市")
        XCTAssertEqual(row("Tokyo", app).value as? String, "正在查看")
        manage("Tokyo", app)
        XCTAssertTrue(app.staticTexts["cities.management.explanation"].label.contains("切换到北京市"))
        app.buttons["cities.management.delete"].tap()
        XCTAssertEqual(row("北京市", app).value as? String, "正在查看，默认城市")
        manage("北京市", app)
        XCTAssertFalse(app.buttons["cities.management.delete"].exists)
        XCTAssertTrue(app.staticTexts["cities.management.explanation"].label.contains("最后一座"))
        try capture(app, "Manage-Last")
        app.buttons["cities.management.add"].tap()
        XCTAssertTrue(app.buttons["cities.search.add.London"].waitForExistence(timeout: 5))
        app.buttons["cities.search.add.London"].tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
        XCTAssertEqual(row("北京市", app).value as? String, "正在查看，默认城市")
        app.terminate(); _ = launch(reset: false)
        XCTAssertEqual(row("北京市", app).value as? String, "正在查看，默认城市")
        XCTAssertTrue(row("London", app).exists)
        XCTAssertFalse(row("上海市", app).exists)
    }
    func testPersonalToolsAndPackingPersistence() throws {
        let app = launch()
        try capture(app, "Overview")
        manage("北京市", app)
        app.buttons["cities.management.default"].tap()
        XCTAssertFalse(app.buttons["cities.management.default"].exists)
        app.buttons["完成"].tap()
        XCTAssertEqual(row("北京市", app).value as? String, "默认城市")
        XCTAssertEqual(row("Tokyo", app).value as? String, "正在查看")
        let trip = app.buttons["my.trip"]; reveal(trip, app)
        try capture(app, "Daily")
        trip.tap()
        let item = app.buttons["home.packing.0"]
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        // Open the sheet fully before interacting with its lower content.
        app.swipeUp()
        let wasSelected = item.isSelected
        item.tap()
        XCTAssertEqual(item.isSelected, !wasSelected)
        try capture(app, "Packing")
        app.buttons["完成"].tap()
        trip.tap()
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        XCTAssertEqual(item.isSelected, !wasSelected)
        app.buttons["完成"].tap()
        let compare = app.buttons["my.compare"]; reveal(compare, app)
        try capture(app, "Personal")
        XCTAssertFalse(app.buttons["my.scenes"].exists)
        XCTAssertFalse(app.buttons["my.widgets"].exists)
        XCTAssertFalse(app.buttons["my.theme"].exists)
        compare.tap()
        XCTAssertTrue(app.navigationBars["双城天气对比"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["my.compare.unavailable"].waitForExistence(timeout: 5))
        let second = app.buttons["my.compare.second"]
        second.tap(); app.buttons["北京市 · 海淀区"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["my.compare.weather.北京市"].waitForExistence(timeout: 5))
        try capture(app, "Comparison")
        app.buttons["完成"].tap()
        let clocks = app.buttons["my.clocks"]; reveal(clocks, app); clocks.tap()
        XCTAssertTrue(app.navigationBars["城市时钟"].waitForExistence(timeout: 5))
        app.swipeUp()
        let slider = app.sliders["my.clocks.slider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssertNotEqual(slider.value as? String, "现在")
        app.buttons["my.clocks.now"].tap()
        XCTAssertEqual(slider.value as? String, "现在")
        try capture(app, "Clocks")
        app.buttons["完成"].tap()
        let tokyo = row("Tokyo", app); reveal(tokyo, app)
        XCTAssertEqual(tokyo.value as? String, "正在查看")
    }
    func testComparisonWithWeatherPreview() throws {
        let app = launch(preview: true)
        let compare = app.buttons["my.compare"]; reveal(compare, app); compare.tap()
        XCTAssertTrue(app.staticTexts["离线示例，仅供体验。"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["my.compare.unavailable"].exists)
        XCTAssertFalse(app.buttons["my.compare.refresh"].exists)
        try capture(app, "Comparison-Weather")
        app.buttons["完成"].tap()
        let tokyo = row("Tokyo", app); reveal(tokyo, app)
        XCTAssertEqual(tokyo.value as? String, "正在查看")
    }
    func testSingleCityComparisonAddsWithoutChangingSelection() throws {
        let app = launch()
        manage("上海市", app); app.buttons["cities.management.delete"].tap()
        manage("北京市", app); app.buttons["cities.management.delete"].tap()
        let compare = app.buttons["my.compare"]; reveal(compare, app); compare.tap()
        XCTAssertTrue(app.buttons["my.compare.add"].waitForExistence(timeout: 5))
        try capture(app, "Compare-Empty")
        app.buttons["my.compare.add"].tap()
        let london = app.buttons["cities.search.add.London"]
        XCTAssertTrue(london.waitForExistence(timeout: 5)); london.tap()
        XCTAssertTrue(app.buttons["cities.edit"].waitForExistence(timeout: 5))
        let tokyo = row("Tokyo", app); reveal(tokyo, app)
        XCTAssertEqual(tokyo.value as? String, "正在查看，默认城市")
        reveal(compare, app); compare.tap()
        XCTAssertTrue(app.buttons["my.compare.second"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["my.compare.add"].exists)
    }
    func testLargeTypeManagementAndPacking() throws {
        let app = launch(largeType: true)
        manage("上海市", app)
        try capture(app, "LargeType-Manage")
        let delete = app.buttons["cities.management.delete"]; reveal(delete, app); delete.tap()
        let trip = app.buttons["my.trip"]; reveal(trip, app); trip.tap()
        let item = app.buttons["home.packing.2"]; reveal(item, app)
        let selected = item.isSelected; item.tap()
        XCTAssertEqual(item.isSelected, !selected)
        try capture(app, "LargeType-Packing")
        app.buttons["完成"].tap()
        let compare = app.buttons["my.compare"]; reveal(compare, app); compare.tap()
        let secondWeather = app.descendants(matching: .any)["my.compare.weather.北京市"]
        reveal(secondWeather, app)
        try capture(app, "LargeType-Comparison")
        app.buttons["完成"].tap()
        let clocks = app.buttons["my.clocks"]; reveal(clocks, app); clocks.tap()
        let slider = app.sliders["my.clocks.slider"]; reveal(slider, app)
        slider.adjust(toNormalizedSliderPosition: 0.25)
        let now = app.buttons["my.clocks.now"]; reveal(now, app); now.tap()
        XCTAssertEqual(slider.value as? String, "现在")
        let beijing = app.descendants(matching: .any)["my.clocks.city.北京市"]; reveal(beijing, app)
        try capture(app, "LargeType-Clocks")
    }

}
