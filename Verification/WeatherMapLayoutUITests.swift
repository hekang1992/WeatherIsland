import XCTest

/// Offline geometry and interaction checks for the map's floating controls.
@MainActor final class WeatherMapLayoutQA: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let image = app.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try image.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-MapLayout-\(name).png"))
    }

    private func checkControls(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let names = ["降水图层", "气温图层", "风速图层", "云量图层", "切换底图", "回到所选城市", "未来66小时", "播放预报"]
        for name in names {
            let button = app.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 10), name, file: file, line: line)
            let reachable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [reachable], timeout: 10), .completed, name, file: file, line: line)
            XCTAssertTrue(app.frame.insetBy(dx: -1, dy: -1).contains(button.frame), "Outside display: \(name), \(button.frame)", file: file, line: line)
        }
        let pin = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "所选位置，")).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(app.frame.contains(pin.frame), "Selected pin outside display: \(pin.frame)", file: file, line: line)
        let map = app.maps.firstMatch
        if map.exists {
            XCTAssertTrue(map.frame.insetBy(dx: -1, dy: -1).contains(pin.frame), "Selected pin clipped by map edge: \(pin.frame), map: \(map.frame)", file: file, line: line)
        }
        for name in names {
            XCTAssertFalse(pin.frame.intersects(app.buttons[name].frame), "Selected pin covered by \(name)", file: file, line: line)
        }
        let tabBar = app.tabBars.firstMatch
        let source = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "数据来源及更新说明")).firstMatch
        XCTAssertTrue(source.isHittable, file: file, line: line)
        if tabBar.exists {
            XCTAssertLessThanOrEqual(source.frame.maxY + 17, tabBar.frame.minY, "Forecast card overlaps tab bar", file: file, line: line)
        }
    }

    func testMapRightRailAndCompactTimeline() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--map-preview"]
        app.launch()
        checkControls(app)
        let rail = ["查看此区域", "降水图层", "气温图层", "风速图层", "云量图层", "切换底图", "回到所选城市"]
        var previous: CGRect?
        for name in rail {
            let button = app.buttons[name]
            XCTAssertTrue(button.isHittable, name)
            XCTAssertGreaterThan(button.frame.midX, app.frame.width * 0.8, name)
            if let previous {
                XCTAssertEqual(button.frame.midX, previous.midX, accuracy: 2, name)
                XCTAssertGreaterThanOrEqual(button.frame.minY, previous.maxY, name)
            }
            previous = button.frame
        }
        let timeline = app.descendants(matching: .any).matching(identifier: "地图时间轴").firstMatch
        XCTAssertTrue(timeline.exists)
        XCTAssertLessThan(timeline.frame.height, 180, "Timeline should leave more height for the map")
        print("Map layout metrics: timeline=\(timeline.frame), map=\(app.maps.firstMatch.frame)")
        let map = app.maps.firstMatch
        XCTAssertGreaterThan(map.frame.height, app.frame.height * 0.5)
        for name in ["气温图层", "风速图层", "云量图层", "降水图层", "切换底图", "回到所选城市"] {
            app.buttons[name].tap()
        }
        app.buttons["未来66小时"].tap()
        app.sliders["预报时间"].adjust(toNormalizedSliderPosition: 0.5)
        app.buttons["播放预报"].tap()
        XCTAssertTrue(app.buttons["暂停预报播放"].waitForExistence(timeout: 5))
        app.buttons["暂停预报播放"].tap()
        app.buttons["查看此区域"].tap()
        try capture(app, "RightRail-Portrait")
        app.terminate()
    }

    func testMapLayerPresentations() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--map-preview", "--map-layer=temperature"]
        app.launch()
        for (name, unit, snapshot) in [("气温", "°C", "Temperature"), ("风速", "km/h", "Wind"), ("云量", "%", "Cloud")] {
            let button = app.buttons[name + "图层"]
            XCTAssertTrue(button.waitForExistence(timeout: 15))
            button.tap()
            XCTAssertTrue(button.isSelected)
            let pin = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "所选位置，" + name, unit)).firstMatch
            XCTAssertTrue(pin.waitForExistence(timeout: 10))
            checkControls(app)
            try capture(app, snapshot)
        }
        app.terminate()
    }

    func testMapCompactPortrait() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--map-preview"]
        app.launch()
        XCTAssertTrue(app.buttons["播放预报"].waitForExistence(timeout: 15))
        try capture(app, "Compact-Initial")
        checkControls(app)
        try capture(app, "Compact-Portrait")
        app.terminate()
    }

    func testMapControlsAndPinAcrossRotation() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--map-preview"]
        app.launch()
        checkControls(app)
        try capture(app, "Portrait")
        app.buttons["气温图层"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 15), .completed)
        try capture(app, "Landscape-Initial")
        checkControls(app)
        app.buttons["未来66小时"].tap()
        app.sliders["预报时间"].adjust(toNormalizedSliderPosition: 0.5)
        try capture(app, "Landscape")
        app.buttons["播放预报"].tap()
        XCTAssertTrue(app.buttons["暂停预报播放"].waitForExistence(timeout: 5))
        app.buttons["暂停预报播放"].tap()
        XCUIDevice.shared.orientation = .portrait
        checkControls(app)
        app.buttons["天气地图数据说明"].tap()
        XCTAssertTrue(app.buttons["完成"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()
        checkControls(app)
        app.terminate()
    }
}
