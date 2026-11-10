import Foundation
import SwiftUI

@MainActor func checkWeatherSettings() throws {
    let suite = "WeatherIsland.SettingsChecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }


    defaults.set("unknown-future-theme", forKey: WeatherTheme.storageKey)
    let app = WeatherApplication(defaults: defaults)
    precondition(app.theme == .system && !app.usesManualCity)
    app.add(.tokyo)
    app.apply(PaperSceneStyle.all[12])
    let collection = app.collection
    let revision = app.citySelectionRevision
    let refreshID = app.locationRefreshID
    let store = app.weather(for: app.selected)
    app.setTheme(.dark)
    let restored = WeatherApplication(defaults: defaults)
    precondition(restored.theme == .dark && restored.theme.colorScheme == .dark)
    precondition(restored.selected == collection.selected && restored.collection.sceneID == collection.sceneID)
    precondition(restored.usesManualCity && app.citySelectionRevision == revision && app.locationRefreshID == refreshID)
    precondition(app.weather(for: app.selected) === store)

    app.setTheme(.light)
    precondition(WeatherApplication(defaults: defaults).theme == .light)
    app.setTheme(.system)
    precondition(WeatherApplication(defaults: defaults).theme.colorScheme == nil)


    app.setTheme(.dark)
    let preview = WeatherApplication(defaults: defaults, live: false)
    precondition(preview.theme == .system)
    preview.setTheme(.light)
    precondition(preview.theme == .light && WeatherApplication(defaults: defaults).theme == .dark)
    precondition(app.selected == collection.selected && app.collection.sceneID == collection.sceneID)
    print("SETTINGS PASS: corrupt preference fallback, theme persistence, city/scene/weather preservation and preview isolation")
}
