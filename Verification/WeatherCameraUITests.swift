import XCTest

@MainActor final class WeatherCameraQA: XCTestCase {
    func testCameraEntryInAllLanguages() throws {
        continueAfterFailure = false
        for (language, title, unavailable, request, denied) in [
            ("zh-Hans", "拍照记录天气", "此设备暂不支持拍照，请使用带相机的设备。", "点击拍照时，将申请相机权限，用于记录此时的天气。", "相机权限未开启，请前往系统设置允许访问相机。"),
            ("en", "Weather photos", "This device cannot take photos. Please use a device with a camera.", "When you tap Take photo, you will be asked for camera access to record the weather right now.", "Camera access is off. Allow camera access in system Settings."),
            ("vi", "Chụp ảnh thời tiết", "Thiết bị này không hỗ trợ chụp ảnh. Vui lòng dùng thiết bị có máy ảnh.", "Khi bạn nhấn Chụp ảnh, ứng dụng sẽ xin quyền truy cập máy ảnh để ghi lại thời tiết lúc này.", "Chưa cho phép truy cập máy ảnh. Hãy cho phép truy cập máy ảnh trong Cài đặt hệ thống.")
        ] {
            let app = XCUIApplication(bundleIdentifier: "com.weather.app.ios")
            app.launchArguments = ["--settings-check", "--reset-settings-check", "--app-language", language]
            app.launch()
            let entry = app.buttons["settings.camera"]
            XCTAssertTrue(entry.waitForExistence(timeout: 15))
            for _ in 0..<8 where !entry.isHittable { app.swipeUp() }
            entry.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            let status = app.staticTexts["settings.camera.status"]
            let capture = app.buttons["settings.camera.capture"]
            XCTAssertFalse(app.alerts.firstMatch.exists)
            if status.label == unavailable {
                XCTAssertFalse(capture.isEnabled)
            } else {
                XCTAssertTrue([request, denied, ["zh-Hans": "相机权限已开启，可以拍照记录此时的天气。", "en": "Camera access is enabled. You can take a photo to record the weather right now.", "vi": "Đã cho phép truy cập máy ảnh. Bạn có thể chụp ảnh ghi lại thời tiết lúc này."][language]!].contains(status.label))
                XCTAssertTrue(capture.isEnabled)
            }
            XCTAssertFalse(app.buttons["settings.camera.share"].exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Camera-\(language)"; attachment.lifetime = .keepAlways; add(attachment)
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/WeatherIsland-Camera-\(language).png"))
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["settings.camera"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }
}
