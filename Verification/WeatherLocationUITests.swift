import XCTest
import CoreLocation

@MainActor final class LocationEntryQA: XCTestCase {
    private func supplyLocation() {
        let fix = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 39.96, longitude: 116.30),
                             altitude: 0, horizontalAccuracy: 50, verticalAccuracy: 50, timestamp: .now)
        XCUIDevice.shared.location = XCUILocation(location: fix)
    }
    override func tearDown() {
        XCUIDevice.shared.location = nil
        super.tearDown()
    }
    private func launchFresh(noFix: Bool = false, namingRecovery: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.resetAuthorizationStatus(for: .location)
        supplyLocation()
        app.launchArguments = ["--location-startup-check", "--reset-city-choice"] + (noFix ? ["--location-no-fix-check"] : []) + (namingRecovery ? ["--location-name-recovery-check"] : [])
        app.launch()
        return app
    }
    private func respondToLocation(_ allow: Bool) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Startup should request system location authorization")
        let names = allow ? ["Allow While Using App", "Allow While Using the App", "使用 App 时允许", "使用App时允许"] : ["Don’t Allow", "Don't Allow", "不允许"]
        let button = alert.buttons.matching(NSPredicate(format: "label IN %@", names)).firstMatch
        XCTAssertTrue(button.exists, alert.debugDescription)
        button.tap()
    }
    private func enterHome(_ app: XCUIApplication) {
        let home = app.tabBars.buttons["天气"]

        if !home.waitForExistence(timeout: 20), app.buttons["稍后进入"].exists { app.buttons["稍后进入"].tap() }
        XCTAssertTrue(home.waitForExistence(timeout: 45))
    }
    func testDenialManualCityAndRelaunch() throws {
        let app = launchFresh()
        respondToLocation(false)
        let alert = app.alerts["请选择天气城市"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["天气"].exists)
        capture(app, "Location denied")
        alert.buttons["手动选择城市"].tap()
        XCTAssertTrue(app.navigationBars["寻找一座小岛"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["完成"].exists)
        app.buttons["Tokyo"].tap()
        enterHome(app)
        XCTAssertTrue(app.buttons["切换城市，当前Tokyo"].waitForExistence(timeout: 5))
        capture(app, "Manual city home")
        app.terminate()
        app.launchArguments = ["--location-startup-check"]
        app.launch()
        enterHome(app)
        XCTAssertTrue(app.buttons["切换城市，当前Tokyo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["切换城市，当前Tokyo"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts.firstMatch.exists)


        app.buttons["切换城市，当前Tokyo"].tap()
        app.buttons["使用我的位置"].tap()
        let laterAlert = app.alerts["暂时无法定位"]
        XCTAssertTrue(laterAlert.waitForExistence(timeout: 5))
        laterAlert.buttons["保留当前城市"].tap()
        XCTAssertTrue(app.buttons["切换城市，当前Tokyo"].waitForExistence(timeout: 5))
        app.terminate()
    }
    func testAllowLoadsCurrentLocation() throws {
        let app = launchFresh()
        respondToLocation(true)
        enterHome(app)
        let metadata = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '坐标天气' OR label CONTAINS '近似位置' OR label CONTAINS '解析地区' OR label CONTAINS '地区名称'")).firstMatch
        XCTAssertTrue(metadata.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture(app, "Current location home")
        app.terminate()
    }


    func testNameRecoversAfterNetworkFailureWithoutRelocating() throws {
        let app = launchFresh(namingRecovery: true)
        respondToLocation(true)
        enterHome(app)
        XCTAssertTrue(app.staticTexts["未来怎么变"].waitForExistence(timeout: 45))
        let city = app.buttons["home.city"]
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        XCTAssertEqual(city.label, "切换城市，当前当前位置", "The fixture must expose weather before its delayed name")
        capture(app, "Naming recovery coordinate weather")
        let named = NSPredicate(format: "label == %@", "切换城市，当前北京市 · 海淀区")
        expectation(for: named, evaluatedWith: city)
        waitForExpectations(timeout: 35)
        XCTAssertTrue(app.staticTexts["未来怎么变"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture(app, "Naming recovery completed")
        app.terminate()
    }
    func testManualCityWinsDuringNameRecovery() throws {
        let app = launchFresh(namingRecovery: true)
        respondToLocation(true)
        enterHome(app)
        let city = app.buttons["home.city"]
        XCTAssertTrue(city.waitForExistence(timeout: 5)); city.tap()
        let savedCity = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "上海市")).firstMatch
        XCTAssertTrue(savedCity.waitForExistence(timeout: 5)); savedCity.tap()
        XCTAssertTrue(app.buttons["切换城市，当前上海市"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.buttons["切换城市，当前上海市"].waitForExistence(timeout: 5))
        let stale = app.buttons["切换城市，当前北京市 · 海淀区"]
        XCTAssertFalse(stale.waitForExistence(timeout: 8))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture(app, "Manual city during naming recovery")
        app.terminate()
    }
    func testNameRecoveryResumesAfterBackground() throws {
        let app = launchFresh(namingRecovery: true)
        respondToLocation(true)
        enterHome(app)
        XCUIDevice.shared.press(.home)
        app.activate()
        let city = app.buttons["home.city"]
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label == %@", "切换城市，当前北京市 · 海淀区"), evaluatedWith: city)
        waitForExpectations(timeout: 35)
        XCTAssertTrue(app.staticTexts["未来怎么变"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture(app, "Naming recovery after foreground")
        app.terminate()
    }
    func testTimeoutOffersManualCity() throws {
        let app = launchFresh(noFix: true)
        respondToLocation(true)
        let alert = app.alerts["请选择天气城市"]
        XCTAssertTrue(alert.waitForExistence(timeout: 16))
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS '定位超时'")).firstMatch.exists)
        alert.buttons["手动选择城市"].tap()
        XCTAssertTrue(app.buttons["Tokyo"].waitForExistence(timeout: 5))
        app.buttons["Tokyo"].tap()
        enterHome(app)
        XCTAssertTrue(app.buttons["切换城市，当前Tokyo"].exists)
        app.terminate()
    }
    func testManualChoiceCancelsPendingLocation() throws {
        let app = launchFresh(noFix: true)
        respondToLocation(true)
        app.buttons["手动选择城市"].tap()
        XCTAssertTrue(app.buttons["Tokyo"].waitForExistence(timeout: 5))
        app.buttons["Tokyo"].tap()
        enterHome(app)
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 14), "Cancelled location must not surface a late timeout")
        XCTAssertTrue(app.buttons["切换城市，当前Tokyo"].exists)
        app.terminate()
    }
    func testSettingsGrantContinuesLocation() throws {
        let app = launchFresh()
        respondToLocation(false)
        let alert = app.alerts["请选择天气城市"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["前往系统设置"].tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        let whileUsing = settings.cells["LOCATION_SERVICES_AUTH_WHEN_IN_USE"]


        if !whileUsing.waitForExistence(timeout: 2) {
            let location = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["Location", "位置", "定位"])).firstMatch
            if location.exists {
                location.tap()
            } else {
                let privacy = settings.buttons["com.apple.settings.privacyAndSecurity"]
                for _ in 0..<6 { if privacy.exists { break }; settings.swipeUp() }
                XCTAssertTrue(privacy.exists, settings.debugDescription); privacy.tap()
                let services = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["定位服务", "Location Services"])).firstMatch
                XCTAssertTrue(services.waitForExistence(timeout: 5)); services.tap()
                let appRow = settings.staticTexts.matching(NSPredicate(format: "label IN %@", ["气象岛", "WeatherIsland"])).firstMatch
                for _ in 0..<6 { if appRow.exists { break }; settings.swipeUp() }
                XCTAssertTrue(appRow.exists, settings.debugDescription); appRow.tap()
            }
        }
        XCTAssertTrue(whileUsing.waitForExistence(timeout: 5), settings.debugDescription)
        whileUsing.tap()
        XCTAssertTrue(whileUsing.isSelected, settings.debugDescription)
        supplyLocation()
        app.activate()
        enterHome(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '坐标天气' OR label CONTAINS '近似位置' OR label CONTAINS '解析地区' OR label CONTAINS '地区名称'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture(app, "Settings granted home")
        app.terminate()
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}

@MainActor final class TemperatureQA: XCTestCase {
    func testTemperatureValuesStayInsideHome() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        for value in [0, 9, 23, -28, -100, 100] {
            app.launchArguments = ["--home-layout-check", "--temperature=\(value)"]
            app.launch()
            let reading = app.descendants(matching: .any).matching(identifier: "home.temperature").firstMatch
            let condition = app.descendants(matching: .any).matching(identifier: "home.condition").firstMatch
            let range = app.staticTexts["home.temperatureRange"]
            XCTAssertTrue(reading.waitForExistence(timeout: 10))
            XCTAssertEqual(reading.label, "\(value)摄氏度")
            XCTAssertTrue(range.exists && condition.exists)
            let screen = app.frame
            for element in [reading, condition, range] {
                XCTAssertGreaterThanOrEqual(element.frame.minX, screen.minX)
                XCTAssertLessThanOrEqual(element.frame.maxX, screen.maxX)
                XCTAssertGreaterThan(element.frame.height, 0)
            }
            XCTAssertFalse(reading.frame.intersects(condition.frame), "Temperature and description overlap for \(value)")
            XCTAssertFalse(reading.frame.intersects(range.frame))
            let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Temperature \(value)"; image.lifetime = .keepAlways; add(image)
            app.terminate()
        }
    }
}



@MainActor final class AccessibilityTemperatureQA: XCTestCase {
    func testLargestTypeKeepsTemperatureAndDetailsSeparate() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--home-layout-check", "--temperature=-100", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let reading = app.descendants(matching: .any).matching(identifier: "home.temperature").firstMatch
        let condition = app.staticTexts["home.condition"]
        let range = app.staticTexts["home.temperatureRange"]
        XCTAssertTrue(reading.waitForExistence(timeout: 10))
        XCTAssertEqual(reading.label, "-100摄氏度")
        let readingFrame = reading.frame
        XCTAssertGreaterThanOrEqual(condition.frame.minY, readingFrame.maxY)
        for frame in [readingFrame, condition.frame, range.frame] {
            XCTAssertGreaterThanOrEqual(frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX)
            XCTAssertGreaterThan(frame.height, 0)
        }
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "Largest accessibility temperature"; image.lifetime = .keepAlways; add(image)
        app.terminate()
    }
}
