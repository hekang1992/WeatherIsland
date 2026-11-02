import Foundation

private actor PermissionFixture {
    private(set) var calls = 0
    let failures: Int
    let data: Data
    init(data: Data, failures: Int) { self.data = data; self.failures = failures }
    func fetch() throws -> Data {
        calls += 1
        if calls <= failures { throw URLError(.dataNotAllowed) }
        return data
    }
}

private actor InterruptedFixture {
    private(set) var calls = 0
    let data: Data
    init(data: Data) { self.data = data }
    func fetch() async throws -> Data {
        calls += 1
        if calls == 1 { try await Task.sleep(for: .seconds(60)) }
        return data
    }
}

@MainActor func checkWeatherConnection(fixture: Data) async throws {
    let suite = "WeatherIsland.ConnectionChecks." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    // Pending per-app access may fail despite an available route. Even a long
    // wait recovers, without the user refreshing and without inventing weather.
    let permission = PermissionFixture(data: fixture, failures: 7)
    let store = WeatherStore(live: true, defaults: defaults, loader: { try await permission.fetch() })
    var delays: [Duration] = []
    await WeatherConnection.recover(sleep: { delay in
        precondition(store.dataset == nil && store.connectionFailed && !store.loading)
        delays.append(delay)
    }) {
        await store.refresh()
        return store.connectionFailed
    }
    let calls = await permission.calls
    precondition(calls == 8 && store.dataset != nil && store.error == nil && !store.connectionFailed)
    precondition(delays == [1, 2, 4, 8, 15, 15, 15].map { .seconds($0) })

    // Service/decoding failures are not permission failures and must not poll.
    let malformed = WeatherStore(live: true, place: .london, defaults: defaults, loader: { Data() })
    var unexpectedRetry = false
    await WeatherConnection.recover(sleep: { _ in unexpectedRetry = true }) {
        await malformed.refresh()
        return malformed.connectionFailed
    }
    precondition(malformed.dataset == nil && malformed.error != nil && !unexpectedRetry)
    precondition(!WeatherConnection.canRetry(URLError(.cancelled)))
    precondition(!WeatherConnection.canRetry(WeatherServiceError.response(403)))

    // Background/city change cancels a pending backoff without one more attempt.
    var sleeping = false
    var attempts = 0
    let pending = Task { @MainActor in
        await WeatherConnection.recover(sleep: { _ in
            sleeping = true
            try await Task.sleep(for: .seconds(60))
        }) { attempts += 1; return true }
    }
    while !sleeping { await Task.yield() }
    pending.cancel()
    await pending.value
    precondition(attempts == 1)

    // Exercise the same coordinator used by the Tab container. Weather and air
    // recover independently; an air failure must not hold up the home page.
    let airData = Data(#"{"current":{"time":1793325600,"us_aqi":37,"pm2_5":8,"pm10":12}}"#.utf8)
    let forecastSource = PermissionFixture(data: fixture, failures: 1)
    let airSource = PermissionFixture(data: airData, failures: 2)
    let app = WeatherApplication(defaults: defaults,
        weatherLoader: { _ in try await forecastSource.fetch() },
        airLoader: { _ in try AirQualityService.decode(await airSource.fetch()) })
    // Use another place to avoid the successful cache created above.
    app.select(.tokyo)
    let load = Task { await app.loadSelectedWeather() }
    let weather = app.weather(for: app.selected)
    let air = app.air(for: app.selected)
    while weather.dataset == nil { await Task.yield() }
    precondition(air.reading == nil && weather.error == nil)
    await load.value
    let forecastCalls = await forecastSource.calls
    let airCalls = await airSource.calls
    precondition(forecastCalls == 2 && airCalls == 3)
    precondition(air.reading != nil && !air.failed && !air.connectionFailed)
    let cached = WeatherApplication(defaults: defaults)
    precondition(cached.weather(for: .tokyo).dataset != nil)

    // Cancel an actual suspended request, then resume the same city's stores.
    // This models leaving the app to grant network access in Settings.
    let interrupted = InterruptedFixture(data: fixture)
    let resumeApp = WeatherApplication(defaults: defaults,
        weatherLoader: { _ in try await interrupted.fetch() },
        airLoader: { _ in try AirQualityService.decode(airData) })
    resumeApp.select(.newYork)
    let resumedWeather = resumeApp.weather(for: resumeApp.selected)
    let suspended = Task { await resumeApp.loadSelectedWeather() }
    while !resumedWeather.loading { await Task.yield() }
    suspended.cancel()
    await suspended.value
    precondition(!resumedWeather.loading && resumedWeather.dataset == nil && resumedWeather.error == nil)
    await resumeApp.loadSelectedWeather()
    let resumedCalls = await interrupted.calls
    precondition(resumedCalls == 2 && resumedWeather.dataset != nil)

    // Offline previews must never run injected network providers.
    let offline = WeatherApplication(defaults: defaults, live: false,
        weatherLoader: { _ in preconditionFailure("Offline preview fetched weather") },
        airLoader: { _ in preconditionFailure("Offline preview fetched air") })
    await offline.loadSelectedWeather()
    precondition(offline.weather(for: offline.selected).dataset == nil)
    print("CONNECTION PASS: pending access, long wait/backoff, automatic recovery, independent air retry, cancellation, cached launch and offline preview")
}
