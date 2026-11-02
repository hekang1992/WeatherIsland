import SwiftUI

@main
struct WeatherIslandApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--widget-gallery") {
                NavigationStack { WeatherWidgetGallery() }
            } else {
                WeatherRootView()
            }
            #else
            WeatherRootView()
            #endif
        }
    }
}
