import Foundation

@MainActor func checkWeatherLocationEntry() throws {
    let suite = "WeatherIsland.LocationEntryChecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let fresh = WeatherApplication(defaults: defaults)
    precondition(!fresh.usesManualCity, "Built-in Shanghai is not a user selection")
    fresh.apply(nil)
    precondition(!WeatherApplication(defaults: defaults).usesManualCity, "Unrelated saves must not complete city setup")
    var entry = WeatherLocationEntry()
    precondition(entry.blocksWeather && entry.begin(usesManualCity: fresh.usesManualCity))
    precondition(!entry.begin(usesManualCity: false), "Repeated active events must not duplicate authorization requests")
    entry.backgrounded()
    precondition(entry.phase == .pending && entry.begin(usesManualCity: false))
    entry.failed()
    precondition(entry.phase == .needsCity && entry.blocksWeather)
    precondition(!entry.begin(usesManualCity: false), "Denial must not re-prompt on foreground")

    entry.retry()
    precondition(entry.phase == .locating && entry.blocksWeather)
    entry.failed()
    fresh.add(.tokyo)
    precondition(fresh.usesManualCity && fresh.citySelectionRevision == 1)
    entry.choseCity()
    precondition(!entry.blocksWeather)
    let restored = WeatherApplication(defaults: defaults)
    precondition(restored.usesManualCity && restored.selected == .tokyo)
    var nextLaunch = WeatherLocationEntry()
    precondition(!nextLaunch.begin(usesManualCity: restored.usesManualCity) && !nextLaunch.blocksWeather)
    nextLaunch.failed()
    precondition(!nextLaunch.blocksWeather, "A later location error keeps the chosen city's home usable")

    // Selecting even the same city invalidates a pending location request.
    let revision = fresh.citySelectionRevision
    fresh.select(.tokyo)
    precondition(fresh.citySelectionRevision > revision)
    var invalid = WeatherPlace.beijing
    invalid.latitude = .nan
    fresh.add(invalid); fresh.select(invalid)
    precondition(fresh.selected == .tokyo && fresh.citySelectionRevision == revision + 1)

    var coordinate = WeatherPlace.beijing
    coordinate.isCurrentLocation = true; coordinate.city = ""; coordinate.district = ""
    fresh.selectLocation(coordinate)
    precondition(!fresh.usesManualCity)
    let current = WeatherApplication(defaults: defaults)
    precondition(!current.usesManualCity && current.selected.isCurrentLocation)
    var currentEntry = WeatherLocationEntry()
    precondition(currentEntry.begin(usesManualCity: current.usesManualCity))
    currentEntry.located()
    precondition(!currentEntry.blocksWeather)
    fresh.select(.tokyo)
    var resolved = coordinate; resolved.city = "北京市"
    fresh.resolveLocation(resolved)
    precondition(fresh.selected == .tokyo, "Late reverse geocoding cannot replace a manual city")

    // Legacy users with a saved manual city are migrated without re-prompting.
    defaults.removePersistentDomain(forName: suite)
    var legacy = CityCollection(); legacy.add(.london)
    defaults.set(try JSONEncoder().encode(legacy), forKey: "WeatherIsland.CityCollection.v1")
    precondition(WeatherApplication(defaults: defaults).usesManualCity)
    legacy.selected = coordinate
    defaults.set(try JSONEncoder().encode(legacy), forKey: "WeatherIsland.CityCollection.v1")
    precondition(!WeatherApplication(defaults: defaults).usesManualCity)
    defaults.set(Data("corrupted".utf8), forKey: "WeatherIsland.CityCollection.v1")
    precondition(!WeatherApplication(defaults: defaults).usesManualCity)

    let preview = WeatherApplication(defaults: defaults, live: false)
    preview.add(.beijing)
    precondition(WeatherApplication(defaults: defaults).selected == .shanghai, "Previews cannot save a city preference")
    print("LOCATION ENTRY PASS: fresh authorization gate, duplicate prevention, denial, background recovery, manual persistence, same-city selection, invalid coordinates, current-location relaunch, stale naming and legacy migration")
}
