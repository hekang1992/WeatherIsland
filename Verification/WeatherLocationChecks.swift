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


/// Exercises the production naming state machine with controlled lookup results.
@MainActor func checkWeatherLocationNaming() async {
    var coordinate = WeatherPlace.beijing
    coordinate.isCurrentLocation = true
    coordinate.city = ""; coordinate.district = ""; coordinate.region = ""
    coordinate.country = ""; coordinate.countryCode = ""
    var named = WeatherPlace.beijing; named.isCurrentLocation = true
    var whitespace = coordinate; whitespace.city = " \n "
    var countryOnly = coordinate; countryOnly.country = "中国"
    var invalid = named; invalid.latitude = .nan
    var other = named; other.longitude += 1
    let resolver = WeatherLocationNaming()
    var attempts = 0
    var sleeps = 0
    var received: [WeatherPlace] = []
    let replies: [WeatherPlace?] = [nil, whitespace, countryOnly, invalid, .tokyo, other, named]
    await resolver.resolve(coordinate, lookup: { _ in
        precondition(resolver.resolving && !resolver.waiting)
        attempts += 1
        if attempts == 1 { throw URLError(.notConnectedToInternet) }
        return replies[attempts - 2]
    }, sleep: { delay in
        precondition(delay == .seconds(60) && resolver.waiting && !resolver.resolving)
        sleeps += 1
    }, onResolved: { received.append($0) })
    precondition(attempts == 8 && sleeps == 7 && received == [named])
    precondition(!resolver.resolving && !resolver.waiting)
    precondition(!whitespace.hasCityName && whitespace.title == "当前位置")

    // Both the network request and the retry delay must end promptly on cancellation.
    let waitingTask = Task { @MainActor in
        await resolver.resolve(coordinate, lookup: { _ in nil }, onResolved: { _ in
            preconditionFailure("Cancelled retry may not deliver a city")
        })
    }
    await waitForNamingState { resolver.waiting }
    waitingTask.cancel()
    await waitingTask.value
    precondition(!resolver.waiting && !resolver.resolving)
    let lookupTask = Task { @MainActor in
        await resolver.resolve(coordinate, lookup: { _ in
            try await Task.sleep(for: .seconds(3600))
            return named
        }, onResolved: { _ in preconditionFailure("Cancelled lookup may not deliver a city") })
    }
    await waitForNamingState { resolver.resolving }
    lookupTask.cancel()
    await lookupTask.value
    precondition(!resolver.waiting && !resolver.resolving)

    // A late, non-cooperative lookup cannot complete or reset a newer operation.
    var oldContinuation: CheckedContinuation<WeatherPlace?, Never>?
    let oldTask = Task { @MainActor in
        await resolver.resolve(coordinate, lookup: { _ in
            await withCheckedContinuation { oldContinuation = $0 }
        }, onResolved: { _ in preconditionFailure("Superseded lookup delivered a city") })
    }
    await waitForNamingState { oldContinuation != nil }
    resolver.cancel(); oldTask.cancel()
    var newContinuation: CheckedContinuation<WeatherPlace?, Never>?
    var recovered: WeatherPlace?
    let newTask = Task { @MainActor in
        await resolver.resolve(coordinate, lookup: { _ in
            await withCheckedContinuation { newContinuation = $0 }
        }, onResolved: { recovered = $0 })
    }
    await waitForNamingState { newContinuation != nil }
    oldContinuation!.resume(returning: named)
    await oldTask.value
    precondition(resolver.resolving && recovered == nil)
    newContinuation!.resume(returning: named)
    await newTask.value
    precondition(recovered == named && !resolver.resolving)

    // Application-level checks reject unusable or stale administrative metadata.
    let suite = "WeatherIsland.NamingChecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let app = WeatherApplication(defaults: defaults)
    app.selectLocation(coordinate)
    let revision = app.citySelectionRevision
    for rejected in [coordinate, whitespace, invalid, other, .tokyo] {
        app.resolveLocation(rejected)
        precondition(app.selected == coordinate)
    }
    app.resolveLocation(named)
    precondition(app.selected == named && app.citySelectionRevision == revision)
    precondition(app.selected.cacheID == coordinate.cacheID && !app.usesManualCity)
    precondition(WeatherApplication(defaults: defaults).selected == named)
    app.add(.tokyo)
    app.resolveLocation(named)
    precondition(app.selected == .tokyo)
    print("LOCATION NAMING PASS: offline/empty/invalid recovery, 60-second cadence, cancellation during lookup and wait, superseded callback isolation, restart, persistence and manual-city protection")
}

@MainActor private func waitForNamingState(_ condition: @MainActor () -> Bool) async {
    for _ in 0..<1000 {
        if condition() { return }
        await Task.yield()
    }
    preconditionFailure("Naming operation did not reach the expected state")
}
