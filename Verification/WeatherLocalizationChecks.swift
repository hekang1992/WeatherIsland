import Foundation

@MainActor func checkWeatherLocalization(fixture: Data) async throws {
    let cases: [(AppLanguage, [String], AppLanguage)] = [
        (.system, ["fr-FR", "vi-VN", "en-US"], .vietnamese),
        (.system, ["zh-Hant-TW", "en"], .chinese),
        (.system, ["de", "fr"], .english),
        (.system, ["en-GB", "zh-Hans"], .english),
        (.system, ["vi", "zh"], .vietnamese),
        (.system, [], .english), (.english, ["zh-Hans"], .english),
        (.vietnamese, ["en"], .vietnamese), (.chinese, ["vi"], .chinese)
    ]
    for (preference, list, expected) in cases {
        precondition(AppLanguage.resolve(preference, preferredLanguages: list) == expected)
    }
    precondition(WeatherLocalization.text("气象岛", language: .english) == "Weather Island")
    precondition(WeatherLocalization.text("气象岛", language: .vietnamese) == "Đảo Thời Tiết")
    precondition(WeatherLocalization.text("气象岛", language: .chinese) == "气象岛")
    precondition(WeatherLocalization.count("duration.hours", 1, language: .english) == "1 hour")
    precondition(WeatherLocalization.count("duration.hours", 2, language: .english) == "2 hours")
    precondition(WeatherLocalization.count("duration.minutes", 2, language: .vietnamese) == "2 phút")
    let injected = WeatherLocalization.format("比参照城市快 %1$@", ["A %2$@"], language: .english)
    precondition(injected == "A %2$@ ahead of the reference city")
    // A pre-localization widget cache without conditionID remains readable.
    let encoded = try JSONEncoder().encode(IslandWidgetWeather.sample)
    var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    object.removeValue(forKey: "conditionID")
    object["condition"] = "多云"
    let legacy = try JSONDecoder().decode(IslandWidgetWeather.self, from: JSONSerialization.data(withJSONObject: object))
    precondition(legacy.conditionID == nil && legacy.localizedCondition == WL("多云"))
    let dataset = try WeatherService.decode(fixture)
    let identity = dataset.current.place.cacheID
    for language in [AppLanguage.chinese, .english, .vietnamese] {
        let request = CityGeocodingService.endpoint(for: "Hanoi", language: language)
        let query = URLComponents(url: request, resolvingAgainstBaseURL: false)!.queryItems!
        precondition(query.first { $0.name == "language" }?.value == (language == .chinese ? "zh" : language.rawValue))
        precondition(dataset.current.place.cacheID == identity)
        precondition(!WeatherLocalization.text(PaperSceneStyle.all[0].name, language: language).isEmpty)
    }
    precondition(IslandWidgetClient.conditionID(2) == WeatherKind.partlyCloudy.rawValue)
    precondition(IslandWidgetClient.conditionID(65) == WeatherKind.heavyRain.rawValue)
    // Language preferences must never replace the selected city, scene or store/cache.
    let suite = "WeatherIsland.LocalizationChecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    let shared = UserDefaults(suiteName: AppLanguage.group)!
    let prior = shared.object(forKey: AppLanguage.storageKey)
    defer {
        defaults.removePersistentDomain(forName: suite)
        if let prior { shared.set(prior, forKey: AppLanguage.storageKey) }
        else { shared.removeObject(forKey: AppLanguage.storageKey) }
    }
    let app = WeatherApplication(defaults: defaults, weatherLoader: { _ in fixture })
    app.add(.tokyo); app.apply(PaperSceneStyle.all[12]); app.setTheme(.dark)
    let selected = app.selected, places = app.places, scene = app.collection.sceneID
    let store = app.weather(for: selected)
    await store.refresh()
    let fetchedAt = store.dataset!.fetchedAt
    let cacheKey = "WeatherIsland.OpenMeteo.v2." + selected.cacheID
    for language in [AppLanguage.vietnamese, .english, .chinese, .system] {
        app.setLanguage(language)
        precondition(app.languagePreference == language)
        precondition(defaults.string(forKey: AppLanguage.storageKey) == language.rawValue)
        precondition(app.selected == selected && app.places == places && app.collection.sceneID == scene && app.theme == .dark)
        precondition(app.weather(for: selected) === store && store.dataset?.fetchedAt == fetchedAt)
        precondition(defaults.data(forKey: cacheKey) == fixture)
    }
    // Known native names in an old display cache still have an offline translation.
    let englishNameKey = WeatherPlaceNames.key(.shanghai, language: .english)
    let oldName = UserDefaults.standard.object(forKey: englishNameKey)
    defer {
        if let oldName { UserDefaults.standard.set(oldName, forKey: englishNameKey) }
        else { UserDefaults.standard.removeObject(forKey: englishNameKey) }
    }
    UserDefaults.standard.set(try JSONEncoder().encode(WeatherPlaceNames.Name(city: "上海市", district: "", region: "上海市")), forKey: englishNameKey)
    precondition(WeatherPlaceNames.display(.shanghai, language: .english).city == "Shanghai")
    print("Localization checks passed: preferred-language ordering, fallback, explicit translations, plurals, safe interpolation, legacy widget cache, stable city identity and request language, switching preserves cities/scenes/theme/store/cache and offline place names.")
}
