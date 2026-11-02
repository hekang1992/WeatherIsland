import Foundation

struct IslandWidgetPlace: Codable, Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZone: String
    var key: String { "\(latitude),\(longitude)" }
}

struct IslandWidgetHour: Codable, Sendable, Identifiable {
    let date: Date
    let temperature: Int
    let symbol: String
    let probability: Double?
    let precipitation: Double?
    var id: Date { date }
}

struct IslandWidgetDay: Codable, Sendable, Identifiable {
    let date: Date
    let low: Int
    let high: Int
    let symbol: String
    let sunrise: Date?
    let sunset: Date?
    var id: Date { date }
}

struct IslandWidgetWeather: Codable, Sendable {
    let place: IslandWidgetPlace
    let fetchedAt: Date
    let observedAt: Date
    let temperature: Int
    let feelsLike: Int
    let condition: String
    let symbol: String
    let hours: [IslandWidgetHour]
    let days: [IslandWidgetDay]

    func clock(_ date: Date, _ format: String = "HH:mm") -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: place.timeZone) ?? .gmt
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    func today(at date: Date) -> IslandWidgetDay? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: place.timeZone) ?? .gmt
        return days.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    func upcoming(at date: Date) -> [IslandWidgetHour] {
        // Use complete future forecast hours; do not sum current 15-minute observations.
        hours.filter { $0.date > date }
    }
    func stale(at date: Date) -> Bool { date.timeIntervalSince(fetchedAt) > 7200 || today(at: date) == nil }

    static let sample: IslandWidgetWeather = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let base = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 14))!
        let symbols = ["cloud.sun.fill", "cloud.fill", "cloud.drizzle.fill", "cloud.rain.fill", "cloud.rain.fill", "cloud.fill"]
        let rain = [10.0, 20, 65, 85, 70, 25]
        return IslandWidgetWeather(place: .init(name: "上海", latitude: 31.23, longitude: 121.47, timeZone: "Asia/Shanghai"),
            fetchedAt: base, observedAt: base, temperature: 22, feelsLike: 21, condition: "多云", symbol: "cloud.sun.fill",
            hours: (0..<24).map { i in .init(date: base.addingTimeInterval(Double(i) * 3600), temperature: [22, 23, 22, 21, 20, 19][i % 6], symbol: symbols[i % 6], probability: rain[i % 6], precipitation: [0, 0, 0.4, 1.6, 0.8, 0][i % 6]) },
            days: (0..<3).map { i in
                let day = calendar.startOfDay(for: base).addingTimeInterval(Double(i) * 86400)
                return .init(date: day, low: 16 + i, high: 24 - i, symbol: symbols[i],
                    sunrise: day.addingTimeInterval(6 * 3600 + 12 * 60), sunset: day.addingTimeInterval(17 * 3600 + 8 * 60))
            })
    }()
}

enum IslandWidgetCache {
    static let group = "group.com.weather.app.ios"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }
    static var place: IslandWidgetPlace? {
        guard let data = defaults?.data(forKey: "widget.place") else { return nil }
        return try? JSONDecoder().decode(IslandWidgetPlace.self, from: data)
    }
    @discardableResult static func select(_ place: IslandWidgetPlace) -> Bool {
        guard self.place != place, let data = try? JSONEncoder().encode(place) else { return false }
        defaults?.set(data, forKey: "widget.place")
        return true
    }
    static func read(for place: IslandWidgetPlace) -> IslandWidgetWeather? {
        guard let data = defaults?.data(forKey: "widget.weather." + place.key) else { return nil }
        return try? JSONDecoder().decode(IslandWidgetWeather.self, from: data)
    }
    static func save(_ weather: IslandWidgetWeather) {
        guard let data = try? JSONEncoder().encode(weather) else { return }
        defaults?.set(data, forKey: "widget.weather." + weather.place.key)
    }
}

/// A compact independent client: the extension can refresh while the app is closed.
enum IslandWidgetClient {
    struct Response: Decodable {
        struct Current: Decodable {
            let time: Double
            let temperature_2m: Double
            let apparent_temperature: Double
            let weather_code: Int
            let is_day: Int
        }
        struct Hourly: Decodable {
            let time: [Double]
            let temperature_2m: [Double?]
            let weather_code: [Int?]
            let precipitation_probability: [Double?]
            let precipitation: [Double?]
        }
        struct Daily: Decodable {
            let time: [Double]
            let temperature_2m_min: [Double?]
            let temperature_2m_max: [Double?]
            let weather_code: [Int?]
            let sunrise: [Double?]
            let sunset: [Double?]
        }
        let timezone: String
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }
    static func fetch(_ place: IslandWidgetPlace) async throws -> IslandWidgetWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(place.latitude)), .init(name: "longitude", value: String(place.longitude)),
            .init(name: "timezone", value: place.timeZone), .init(name: "timeformat", value: "unixtime"),
            .init(name: "forecast_days", value: "3"),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,precipitation"),
            .init(name: "daily", value: "temperature_2m_min,temperature_2m_max,weather_code,sunrise,sunset")
        ]
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: components.url!, timeoutInterval: 20))
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try decode(data, place: place)
    }
    static func decode(_ data: Data, place: IslandWidgetPlace, fetchedAt: Date = .now) throws -> IslandWidgetWeather {
        let r = try JSONDecoder().decode(Response.self, from: data)
        let h = r.hourly, d = r.daily
        guard h.time.count == h.temperature_2m.count, h.time.count == h.weather_code.count,
              h.time.count == h.precipitation_probability.count, h.time.count == h.precipitation.count,
              d.time.count == d.temperature_2m_min.count, d.time.count == d.temperature_2m_max.count,
              d.time.count == d.weather_code.count, d.time.count == d.sunrise.count, d.time.count == d.sunset.count,
              r.current.temperature_2m.isFinite, r.current.apparent_temperature.isFinite else { throw URLError(.cannotParseResponse) }
        let hours: [IslandWidgetHour] = h.time.indices.compactMap { i in
            guard let t = h.temperature_2m[i], let code = h.weather_code[i], t.isFinite else { return nil }
            return .init(date: Date(timeIntervalSince1970: h.time[i]), temperature: Int(t.rounded()), symbol: condition(code).1,
                         probability: h.precipitation_probability[i], precipitation: h.precipitation[i])
        }
        let days: [IslandWidgetDay] = d.time.indices.compactMap { i in
            guard let low = d.temperature_2m_min[i], let high = d.temperature_2m_max[i], let code = d.weather_code[i], low.isFinite, high.isFinite else { return nil }
            return .init(date: Date(timeIntervalSince1970: d.time[i]), low: Int(low.rounded()), high: Int(high.rounded()),
                symbol: condition(code).1, sunrise: d.sunrise[i].flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
                sunset: d.sunset[i].flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil })
        }
        guard !hours.isEmpty, !days.isEmpty else { throw URLError(.cannotParseResponse) }
        let current = condition(r.current.weather_code, night: r.current.is_day == 0)
        return .init(place: .init(name: place.name, latitude: place.latitude, longitude: place.longitude, timeZone: r.timezone),
            fetchedAt: fetchedAt, observedAt: Date(timeIntervalSince1970: r.current.time), temperature: Int(r.current.temperature_2m.rounded()),
            feelsLike: Int(r.current.apparent_temperature.rounded()), condition: current.0, symbol: current.1, hours: hours, days: days)
    }
    static func condition(_ code: Int, night: Bool = false) -> (String, String) {
        switch code {
        case 0, 1: ("晴", night ? "moon.stars.fill" : "sun.max.fill")
        case 2: ("多云", night ? "cloud.moon.fill" : "cloud.sun.fill")
        case 3: ("阴", "cloud.fill")
        case 45, 48: ("雾", "cloud.fog.fill")
        case 51, 53, 55: ("小雨", "cloud.drizzle.fill")
        case 56, 57, 66, 67: ("冻雨", "cloud.sleet.fill")
        case 61, 63, 80, 81: ("雨", "cloud.rain.fill")
        case 65, 82: ("大雨", "cloud.heavyrain.fill")
        case 71, 73, 75, 77, 85, 86: ("雪", "cloud.snow.fill")
        case 95, 96, 99: ("雷雨", "cloud.bolt.rain.fill")
        default: ("天气待更新", "cloud.fill")
        }
    }
}
