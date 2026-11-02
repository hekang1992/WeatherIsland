import XCTest

@MainActor final class WeatherWidgetQA: XCTestCase {
    func testAllNineWidgetLayouts() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        for (style, title) in [("landscape", "山水天气"), ("rain", "带伞提醒"), ("daylight", "日出日落")] {
            app.launchArguments = ["--widget-gallery"]
            app.launch()
            XCTAssertTrue(app.navigationBars["桌面小组件"].waitForExistence(timeout: 15))
            app.segmentedControls.buttons[title].tap()
            for size in ["small", "medium", "large"] {
                let preview = app.descendants(matching: .any).matching(identifier: "widgets.preview.\(style).\(size)").firstMatch
                XCTAssertTrue(preview.waitForExistence(timeout: 5))
                for _ in 0..<5 {
                    if preview.frame.minY >= 100 && preview.frame.maxY <= app.frame.maxY - 40 { break }
                    app.swipeUp(velocity: .slow)
                }
                XCTAssertGreaterThan(preview.frame.width, 100)
                XCTAssertGreaterThan(preview.frame.height, 100)
                XCTAssertGreaterThanOrEqual(preview.frame.minX, 0)
                XCTAssertLessThanOrEqual(preview.frame.maxX, app.frame.maxX)
                XCTAssertGreaterThanOrEqual(preview.frame.minY, 70)
                XCTAssertLessThanOrEqual(preview.frame.maxY, app.frame.maxY - 20)
                let screenshot = app.screenshot()
                let attachment = XCTAttachment(screenshot: screenshot)
                attachment.name = "Widget-\(style)-\(size)"
                attachment.lifetime = .keepAlways
                add(attachment)
                try screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-Widget-\(style)-\(size).png"))
            }
            app.terminate()
        }
    }

    func testSettingsGalleryAndWidgetLinks() throws {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
        app.launchArguments = ["--map-preview"]
        app.launch()
        let settings = app.tabBars.buttons["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let entry = app.buttons["settings.widgets"]
        for _ in 0..<4 {
            if entry.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(entry.isHittable)
        entry.tap()
        XCTAssertTrue(app.navigationBars["桌面小组件"].waitForExistence(timeout: 5))
        for style in ["landscape", "rain", "daylight"] {
            app.open(URL(string: "weatherisland://widget/\(style)")!)
            let title = ["landscape": "山水天气", "rain": "带伞提醒", "daylight": "日出日落"][style]!
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            app.buttons["完成"].tap()
        }
    }
}
