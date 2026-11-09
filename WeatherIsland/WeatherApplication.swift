import SwiftUI

@MainActor @Observable final class WeatherApplication {
    enum Tab: Hashable { case weather, map, cities, settings }
    enum CitySearchPurpose { case choose, save }
    var tab: Tab = .weather
    private(set) var theme: WeatherTheme
    private(set) var collection: CityCollection
    var searchPresented = false
    private(set) var citySearchPurpose: CitySearchPurpose = .choose
    private(set) var locationRefreshID = 0
    private(set) var citySelectionRevision = 0
    private(set) var usesManualCity: Bool
    private let defaults: UserDefaults
    private let live: Bool
    private let weatherLoader: (@Sendable (WeatherPlace) async throws -> Data)?
    private let airLoader: (@Sendable (WeatherPlace) async throws -> AirQualityReading)?
    private var weather: [String:WeatherStore] = [:]
    private var air: [String:AirQualityStore] = [:]
    private static let collectionKey = "WeatherIsland.CityCollection.v1"
    private static let manualCityKey = "WeatherIsland.ManualCity.v1"
    init(defaults:UserDefaults = .standard, live:Bool = true,
         weatherLoader: (@Sendable (WeatherPlace) async throws -> Data)? = nil,
         airLoader: (@Sendable (WeatherPlace) async throws -> AirQualityReading)? = nil) {
        self.defaults=defaults;self.live=live
        theme = live ? WeatherTheme(rawValue: defaults.string(forKey: WeatherTheme.storageKey) ?? "") ?? .system : .system
        self.weatherLoader=weatherLoader;self.airLoader=airLoader
        let saved = live ? defaults.data(forKey: Self.collectionKey).flatMap {
            try? JSONDecoder().decode(CityCollection.self, from: $0)
        } : nil
        var restored = saved ?? CityCollection()
        restored.validate(); collection = restored
        // Existing installations retain their chosen city. The built-in Shanghai
        // fallback on a fresh install is not an explicit user choice.
        usesManualCity = live && ((defaults.object(forKey: Self.manualCityKey) as? Bool)
            ?? (saved != nil && !restored.selected.isCurrentLocation))
    }
    var offline:Bool {!live}
    var selected: WeatherPlace {collection.selected}
    var places:[WeatherPlace] {collection.places}
    var style: PaperSceneStyle { PaperSceneStyle.named(collection.sceneID) ?? .automatic(for:selected) }
    var automaticScene: Bool {collection.sceneID == nil}
    func weather(for place:WeatherPlace) -> WeatherStore {
        if let store=weather[place.cacheID] {store.updateMetadata(place);return store}
        let loader: (@Sendable () async throws -> Data)? = weatherLoader.map { provider in
            { @Sendable in try await provider(place) }
        }
        let store=WeatherStore(live:live,place:place,defaults:defaults,loader:loader);weather[place.cacheID]=store;return store
    }
    func air(for place:WeatherPlace) -> AirQualityStore {
        if let store=air[place.cacheID] {return store}
        let loader: (@Sendable () async throws -> AirQualityReading)? = airLoader.map { provider in
            { @Sendable in try await provider(place) }
        }
        let store=AirQualityStore(place:place,defaults:defaults,live:live,loader:loader);air[place.cacheID]=store;return store
    }
    /// Owned by the foreground Tab container, so startup waits and retries survive
    /// tab changes but stop when backgrounded or when another city is selected.
    func loadSelectedWeather() async {
        guard live else { return }
        let forecast = weather(for: selected)
        let quality = air(for: selected)
        async let weatherRecovery: Void = WeatherConnection.recover {
            if forecast.loading { return true }
            guard forecast.dataset == nil || forecast.cached || forecast.error != nil ||
                    Date.now.timeIntervalSince(forecast.dataset?.fetchedAt ?? .distantPast) > 600 else { return false }
            await forecast.refresh()
            return forecast.connectionFailed
        }
        async let airRecovery: Void = WeatherConnection.recover {
            if quality.loading { return true }
            guard quality.reading == nil || quality.cached || quality.failed ||
                    Date.now.timeIntervalSince(quality.reading?.fetchedAt ?? .distantPast) > 600 else { return false }
            await quality.refresh()
            return quality.connectionFailed
        }
        _ = await (weatherRecovery, airRecovery)
    }
    func select(_ place: WeatherPlace) {
        guard place.valid else { return }
        collection.selected = place; tab = .weather
        usesManualCity = !place.isCurrentLocation
        if usesManualCity { citySelectionRevision += 1 }
        save()
    }
    func selectLocation(_ place:WeatherPlace) { select(place); locationRefreshID += 1 }
    func resolveLocation(_ place:WeatherPlace) {
        guard selected.isCurrentLocation,place.isCurrentLocation,place.valid,place.hasCityName,selected.cacheID == place.cacheID else{return}
        weather[place.cacheID]?.updateMetadata(place)
        collection.selected=place;save()
    }
    func presentCitySearch(_ purpose: CitySearchPurpose = .choose) {
        citySearchPurpose = purpose
        searchPresented = true
    }
    func add(_ place: WeatherPlace, selecting: Bool = true) {
        guard place.valid else { return }
        collection.add(place, selecting: selecting)
        if selecting {
            usesManualCity = true; citySelectionRevision += 1
            tab = .weather
        }
        searchPresented = false; save()
    }
    func remove(_ id: String) {
        let previous = selected
        collection.remove(id)
        if selected != previous {
            usesManualCity = !selected.isCurrentLocation
            citySelectionRevision += 1
        }
        save()
    }
    func setDefault(_ id:String) {guard places.contains(where:{$0.id==id})else{return};collection.defaultID=id;save()}
    func move(from:IndexSet,to:Int) {collection.places.move(fromOffsets:from,toOffset:to);save()}
    func setTheme(_ value: WeatherTheme) {
        theme = value
        if live { defaults.set(value.rawValue, forKey: WeatherTheme.storageKey) }
    }
    func apply(_ style:PaperSceneStyle?) {collection.sceneID=style?.id;save()}
    private func save() {guard live else{return};defaults.set(usesManualCity, forKey:Self.manualCityKey);if let data=try? JSONEncoder().encode(collection){defaults.set(data,forKey:Self.collectionKey)}}
}

/// Startup never loads the fallback city's weather before location or an explicit
/// city choice. Once ready, later location failures leave the existing home usable.
struct WeatherLocationEntry {
    enum Phase { case pending, locating, needsCity, ready }
    private(set) var phase: Phase = .pending
    var blocksWeather: Bool { phase != .ready }
    mutating func begin(usesManualCity: Bool) -> Bool {
        guard phase == .pending else { return false }
        phase = usesManualCity ? .ready : .locating
        return !usesManualCity
    }
    mutating func retry() { if phase != .ready { phase = .locating } }
    mutating func located() { phase = .ready }
    mutating func failed() { if phase != .ready { phase = .needsCity } }
    mutating func choseCity() { phase = .ready }
    mutating func backgrounded() { if phase == .locating { phase = .pending } }
}

/// Stored independently of cities so appearance changes do not restart weather or GPS.
enum WeatherTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    static let storageKey = "WeatherIsland.Theme.v1"
    var id: String { rawValue }
    var title: String {
        switch self { case .system: "跟随系统"; case .light: "浅色 · 晴昼"; case .dark: "深色 · 夜墨" }
    }
    var detail: String {
        switch self {
        case .system: "随设备的浅色与深色外观自动切换。"
        case .light: "绢色纸面与青绿淡墨，适合白天阅读。"
        case .dark: "深色纸面与柔和文字，适合夜间查看。"
        }
    }
    var symbol: String {
        switch self { case .system: "circle.lefthalf.filled"; case .light: "sun.max"; case .dark: "moon.stars" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}
