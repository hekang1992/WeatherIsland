import SwiftUI

@main
struct WeatherIslandApp: App {
    var body: some Scene {
        WindowGroup {
            WeatherHomeView(useLiveData: true)
        }
    }
}
