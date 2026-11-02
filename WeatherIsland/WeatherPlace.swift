import Foundation
import Observation

struct WeatherPlace: Codable, Hashable, Identifiable, Sendable {
    var city: String
    var district: String = ""
    var region: String = ""
    var country: String
    var countryCode: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String = "UTC"
    var isCurrentLocation = false
    var approximate = false

    var id: String {
        let components = [countryCode, region, city, district].map { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
        let name = components.joined(separator: "|")
        return city.isEmpty ? name + String(format: "|%.3f|%.3f", latitude, longitude) : name
    }
    var cacheID: String {
        if isCurrentLocation { return String(format: "current|%.5f|%.5f", latitude, longitude) }
        return id + String(format: "|%.3f|%.3f", latitude, longitude)
    }
    var hasCityName: Bool { !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var title: String { [!hasCityName ? "当前位置" : city, approximate ? "" : district].filter { !$0.isEmpty }.joined(separator: " · ") }
    var subtitle: String { [region == city ? "" : region, country].filter { !$0.isEmpty }.joined(separator: " · ") }
    var valid: Bool { latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude) }
    static let shanghai = WeatherPlace(city: "上海市", region: "上海市", country: "中国", countryCode: "CN", latitude: 31.2304, longitude: 121.4737, timeZoneIdentifier: "Asia/Shanghai")
    static let beijing = WeatherPlace(city: "北京市", district: "海淀区", region: "北京市", country: "中国", countryCode: "CN", latitude: 39.96, longitude: 116.30, timeZoneIdentifier: "Asia/Shanghai")
    static let london = WeatherPlace(city: "London", region: "England", country: "英国", countryCode: "GB", latitude: 51.5074, longitude: -0.1278, timeZoneIdentifier: "Europe/London")
    static let tokyo = WeatherPlace(city: "Tokyo", country: "日本", countryCode: "JP", latitude: 35.6762, longitude: 139.6503, timeZoneIdentifier: "Asia/Tokyo")
    static let newYork = WeatherPlace(city: "New York", region: "New York", country: "美国", countryCode: "US", latitude: 40.7128, longitude: -74.006, timeZoneIdentifier: "America/New_York")
}

/// All collection edits keep a valid selected/default city and at least one saved place.
struct CityCollection: Codable {
    var places: [WeatherPlace] = [.shanghai]
    var defaultID: String = WeatherPlace.shanghai.id
    var selected: WeatherPlace = .shanghai
    var sceneID: String? = nil

    mutating func validate() {
        var seen = Set<String>()
        places = places.filter { $0.valid && !$0.isCurrentLocation && seen.insert($0.id).inserted }
        if places.isEmpty { places = [.shanghai] }
        if !places.contains(where: { $0.id == defaultID }) { defaultID = places[0].id }
        if !selected.valid || (!selected.isCurrentLocation && !places.contains(where: { $0.id == selected.id })) { selected = defaultPlace }
    }
    var defaultPlace: WeatherPlace { places.first { $0.id == defaultID } ?? places[0] }
    mutating func add(_ place: WeatherPlace) {
        guard place.valid else { return }
        var saved = place; saved.isCurrentLocation = false
        if let existing = places.first(where: { $0.id == saved.id }) { selected = existing }
        else { places.append(saved); selected = saved }
    }
    mutating func remove(_ id: String) {
        guard places.count > 1, places.contains(where: { $0.id == id }) else { return }
        places.removeAll { $0.id == id }
        if defaultID == id { defaultID = places[0].id }
        if !selected.isCurrentLocation && selected.id == id { selected = defaultPlace }
    }
}

/// Naming is independent of GPS and weather. The foreground view owns this
/// operation, so an unresolved coordinate can recover after network consent.
@MainActor @Observable final class WeatherLocationNaming {
    private(set) var resolving = false
    private(set) var waiting = false
    private var generation = 0

    func cancel() {
        generation += 1
        resolving = false; waiting = false
    }

    func resolve(
        _ place: WeatherPlace,
        lookup: @MainActor (WeatherPlace) async throws -> WeatherPlace?,
        sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        onResolved: @MainActor (WeatherPlace) -> Void
    ) async {
        guard !Task.isCancelled, place.valid, place.isCurrentLocation, !place.hasCityName else { return }
        generation += 1
        let token = generation
        resolving = true; waiting = false
        defer {
            if token == generation { resolving = false; waiting = false }
        }
        while !Task.isCancelled, token == generation {
            do {
                if let named = try await lookup(place), !Task.isCancelled, token == generation,
                   named.valid, named.isCurrentLocation, named.cacheID == place.cacheID, named.hasCityName {
                    onResolved(named)
                    return
                }
            } catch is CancellationError { return }
            catch { /* Keep coordinate weather and retry naming independently. */ }
            guard !Task.isCancelled, token == generation else { return }
            resolving = false; waiting = true
            // Geocoding is rate limited. Weather success or a foreground return
            // can restart sooner; prolonged failures get at most one retry/minute.
            do { try await sleep(.seconds(60)) } catch { return }
            guard !Task.isCancelled, token == generation else { return }
            waiting = false; resolving = true
        }
    }
}
