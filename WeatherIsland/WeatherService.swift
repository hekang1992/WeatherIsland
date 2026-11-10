import Foundation
import SwiftUI

struct WeatherMetrics: Hashable {
    let time: Date
    let uv: Double?
    let probability: Double?
    let precipitation: Double?
    let precipitationUnit: String
    var localizedPrecipitationUnit: String {
        if daily { return WL("mm/天") }
        if precipitationUnit == "mm/h" { return precipitationUnit }

        let minutes = precipitationUnit.filter { $0.isNumber }
        return minutes.isEmpty ? precipitationUnit : WLF("mm/%1$@分", minutes)
    }
    let wind: Double?
    let windDirection: Double?
    let humidity: Double?
    let visibility: Double?
    let sunrise: Date?
    let sunset: Date?
    let daily: Bool
    var timeZoneIdentifier: String = "Asia/Shanghai"
}

struct WeatherDataset {
    let current: WeatherReport
    let hourly: [WeatherReport]
    let daily: [WeatherReport]
    let fetchedAt: Date
    var next24Hours: [WeatherReport] = []
    var timeZoneIdentifier: String = "Asia/Shanghai"
    var hours: [WeatherSample.Hour] {
        hourly.enumerated().map { index, report in
            .init(time: index == 0 ? WL("现在") : WeatherClock.string(report.metrics!.time, "HH时", timeZone: timeZoneIdentifier),
                  kind: report.kind, temperature: report.temperature)
        }
    }
    var days: [WeatherSample.Day] {
        daily.enumerated().map { index, report in
            .init(name: index == 0 ? WL("今天") : WeatherClock.string(report.metrics!.time, "EEE", timeZone: timeZoneIdentifier),
                  kind: report.kind, low: report.low, high: report.high)
        }
    }
}

enum WeatherClock {

    static func difference(from reference: String, to destination: String, at date: Date) -> String {
        guard let origin = TimeZone(identifier: reference), let target = TimeZone(identifier: destination) else { return WL("时区未知") }
        let minutes = (target.secondsFromGMT(for: date) - origin.secondsFromGMT(for: date)) / 60
        guard minutes != 0 else { return WL("与参照城市同一时间") }
        let hours = abs(minutes) / 60, remainder = abs(minutes) % 60
        let duration: String
        if WeatherLocalization.isChinese {
            duration = (hours > 0 ? "\(hours)小时" : "") + (remainder > 0 ? "\(remainder)分钟" : "")
        } else {
            let parts = [hours > 0 ? WeatherLocalization.count("duration.hours", hours) : nil,
                         remainder > 0 ? WeatherLocalization.count("duration.minutes", remainder) : nil].compactMap { $0 }
            duration = parts.joined(separator: " ")
        }
        return WLF(minutes > 0 ? "比参照城市快 %1$@" : "比参照城市慢 %1$@", duration)
    }

    static func string(_ date: Date, _ format: String, timeZone: String = "Asia/Shanghai") -> String {
        WeatherLocalization.date(date, format: format, timeZone: timeZone)
    }
}

enum WeatherServiceError: LocalizedError {
    case response(Int), invalidData, unknownCode(Int)
    var errorDescription: String? {
        switch self {
        case .response(let code): WLF("天气服务暂时不可用（%1$@），请稍后重试。", String(describing: code))
        case .invalidData: WL("天气数据不完整，请稍后刷新。")
        case .unknownCode(let code): WLF("暂不支持天气代码 %1$@，请稍后刷新。", String(describing: code))
        }
    }
}


enum WeatherService {
    static var endpoint: URL { endpoint(for: .shanghai) }
    static func endpoint(for place: WeatherPlace) -> URL {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            .init(name: "latitude", value: String(place.latitude)), .init(name: "longitude", value: String(place.longitude)),
            .init(name: "timezone", value: "auto"), .init(name: "timeformat", value: "unixtime"),
            .init(name: "forecast_days", value: "7"),
            .init(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m"),
            .init(name: "hourly", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,visibility,wind_speed_10m,wind_direction_10m,uv_index"),
            .init(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_direction_10m_dominant"),
            .init(name: "temperature_unit", value: "celsius"),
            .init(name: "wind_speed_unit", value: "kmh"), .init(name: "precipitation_unit", value: "mm")
        ]
        return url.url!
    }

    static func fetch(place: WeatherPlace = .shanghai) async throws -> Data {
        var request = URLRequest(url: endpoint(for: place), timeoutInterval: 20)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await WeatherConnection.session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw WeatherServiceError.invalidData }
        guard (200..<300).contains(response.statusCode) else { throw WeatherServiceError.response(response.statusCode) }
        return data
    }


    static func kind(code: Int, wind: Double = 0) throws -> WeatherKind {
        switch code {
        case 0, 1: return wind >= 40 ? .windy : .clear
        case 2: return wind >= 40 ? .windy : .partlyCloudy
        case 3: return wind >= 40 ? .windy : .overcast
        case 45, 48: return .fog
        case 51, 53, 55, 56, 57, 61, 66, 80: return .lightRain
        case 63, 81: return .moderateRain
        case 65, 67, 82: return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95: return .thunderstorm
        case 96, 99: return .hail
        default: throw WeatherServiceError.unknownCode(code)
        }
    }


    struct Payload: Decodable {
        let current: Current
        let timezone: String?
        let hourly: [String: [Double?]]
        let daily: [String: [Double?]]
        struct Current: Decodable {
            let time: Double
            let interval: Int
            let temperature_2m: Double
            let relative_humidity_2m: Double?
            let apparent_temperature: Double
            let precipitation: Double?
            let weather_code: Int
            let wind_speed_10m: Double?
            let wind_direction_10m: Double?
        }
    }

    static func decode(_ data: Data, fetchedAt: Date = .now, place: WeatherPlace = .shanghai) throws -> WeatherDataset {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        let zone = payload.timezone ?? place.timeZoneIdentifier
        func local(_ date: Date, _ format: String) -> String { WeatherClock.string(date, format, timeZone: zone) }
        let h = payload.hourly, d = payload.daily, c = payload.current
        func value(_ values: [String: [Double?]], _ key: String, _ i: Int) -> Double? {
            guard let a = values[key], a.indices.contains(i), let n = a[i], n.isFinite else { return nil }
            return n
        }
        func required(_ values: [String: [Double?]], _ key: String, _ i: Int) throws -> Double {
            guard let n = value(values, key, i) else { throw WeatherServiceError.invalidData }
            return n
        }
        func date(_ values: [String: [Double?]], _ key: String, _ i: Int) -> Date? {
            value(values, key, i).map { Date(timeIntervalSince1970: $0) }
        }
        guard let times = h["time"], let dates = d["time"], times.count >= 6, dates.count >= 7,
              c.temperature_2m.isFinite, c.apparent_temperature.isFinite else { throw WeatherServiceError.invalidData }
        let now = Date(timeIntervalSince1970: c.time)
        let dayIndex = dates.indices.first { i in
            guard let t = dates[i] else { return false }
            return local(Date(timeIntervalSince1970: t), "yyyy-MM-dd") == local(now, "yyyy-MM-dd")
        } ?? 0
        let nearest = times.indices.min { abs((times[$0] ?? 0) - c.time) < abs((times[$1] ?? 0) - c.time) } ?? 0
        func report(_ i: Int, daily: Bool) throws -> WeatherReport {
            let source = daily ? d : h
            let time = try required(source, "time", i)
            let day = daily ? i : (dates.indices.last { (dates[$0] ?? .infinity) <= time } ?? 0)
            let low = try required(d, "temperature_2m_min", day)
            let high = try required(d, "temperature_2m_max", day)
            let wind = value(source, daily ? "wind_speed_10m_max" : "wind_speed_10m", i)
            let code = try required(source, "weather_code", i)
            guard (0...100).contains(code) else { throw WeatherServiceError.invalidData }
            let kind = try kind(code: Int(code), wind: wind ?? 0)
            let metrics = WeatherMetrics(time: Date(timeIntervalSince1970: time),
                uv: value(source, daily ? "uv_index_max" : "uv_index", i),
                probability: value(source, daily ? "precipitation_probability_max" : "precipitation_probability", i),
                precipitation: value(source, daily ? "precipitation_sum" : "precipitation", i),
                precipitationUnit: daily ? "mm/天" : "mm/h",
                wind: wind, windDirection: value(source, daily ? "wind_direction_10m_dominant" : "wind_direction_10m", i),
                humidity: daily ? nil : value(h, "relative_humidity_2m", i),
                visibility: daily ? nil : value(h, "visibility", i).map { $0 / 1000 },
                sunrise: date(d, "sunrise", day), sunset: date(d, "sunset", day), daily: daily, timeZoneIdentifier: zone)
            return WeatherReport(kind: kind,
                temperature: Int(try required(source, daily ? "temperature_2m_max" : "temperature_2m", i).rounded()),
                low: Int(low.rounded()), high: Int(high.rounded()),
                feelsLike: Int(try required(source, daily ? "apparent_temperature_max" : "apparent_temperature", i).rounded()),
                scope: "\(place.title) · \(local(metrics.time, daily ? "M月d日 EEE" : "M月d日 HH:mm"))",
                isDemo: false, metrics: metrics, place: place)
        }
        let low = try required(d, "temperature_2m_min", dayIndex)
        let high = try required(d, "temperature_2m_max", dayIndex)
        let current = WeatherReport(kind: try kind(code: c.weather_code, wind: c.wind_speed_10m ?? 0),
            temperature: Int(c.temperature_2m.rounded()), low: Int(low.rounded()), high: Int(high.rounded()),
            feelsLike: Int(c.apparent_temperature.rounded()), scope: WLF("此刻的%1$@", String(describing: place.title)), isDemo: false,
            metrics: WeatherMetrics(time: now, uv: value(h, "uv_index", nearest),
                probability: value(h, "precipitation_probability", nearest), precipitation: c.precipitation,
                precipitationUnit: "mm/\(c.interval / 60)分", wind: c.wind_speed_10m, windDirection: c.wind_direction_10m,
                humidity: c.relative_humidity_2m, visibility: value(h, "visibility", nearest).map { $0 / 1000 },
                sunrise: date(d, "sunrise", dayIndex), sunset: date(d, "sunset", dayIndex), daily: false, timeZoneIdentifier: zone), place: place)
        let next = times.indices.filter { (times[$0] ?? 0) > c.time }.prefix(5)
        guard next.count == 5 else { throw WeatherServiceError.invalidData }
        let hours = try [current] + next.map { try report($0, daily: false) }
        let daily = try dates.indices.dropFirst(dayIndex).prefix(7).map { try report($0, daily: true) }
        guard daily.count == 7 else { throw WeatherServiceError.invalidData }
        let trendIndices = times.indices.filter { (times[$0] ?? 0) > c.time }.prefix(23)
        let trend = try [current] + trendIndices.map { try report($0, daily: false) }
        return WeatherDataset(current: current, hourly: hours, daily: daily, fetchedAt: fetchedAt, next24Hours: trend, timeZoneIdentifier: zone)
    }
}

@MainActor @Observable final class WeatherStore {
    private(set) var dataset: WeatherDataset?
    private(set) var loading = false
    private(set) var cached = false
    private var serviceError: WeatherServiceError?
    private var requestFailed = false
    var error: String? {
        guard requestFailed else { return nil }
        return serviceError?.errorDescription ?? WL("暂时无法获取天气，请检查网络后重试。")
    }
    private(set) var connectionFailed = false
    private let cacheKey: String
    private(set) var place: WeatherPlace
    private let defaults: UserDefaults
    private let loader: @Sendable () async throws -> Data
    init(live: Bool, place: WeatherPlace = .shanghai, defaults: UserDefaults = .standard,
         loader: (@Sendable () async throws -> Data)? = nil) {
        self.place = place
        cacheKey = "WeatherIsland.OpenMeteo.v2." + place.cacheID
        self.defaults = defaults
        self.loader = loader ?? { try await WeatherService.fetch(place: place) }
        if live, place == .shanghai, defaults.data(forKey: cacheKey) == nil,
           let legacy = defaults.data(forKey: "WeatherIsland.OpenMeteo.Shanghai.v1"),
           let timestamp = defaults.object(forKey: "WeatherIsland.OpenMeteo.Shanghai.v1.date") as? Date {
            defaults.set(legacy, forKey: cacheKey); defaults.set(timestamp, forKey: cacheKey + ".date")
        }
        guard live, let data = defaults.data(forKey: cacheKey),
              let timestamp = defaults.object(forKey: cacheKey + ".date") as? Date,
              let decoded = try? WeatherService.decode(data, fetchedAt: timestamp, place: place) else { return }
        dataset = decoded
        cached = true
    }
    func updateMetadata(_ place:WeatherPlace) {
        guard self.place.cacheID == place.cacheID,self.place != place else{return}
        self.place=place
        guard let old=dataset else{return}
        func updated(_ report:WeatherReport)->WeatherReport {
            var result=report;result.place=place
            if report.id == old.current.id { result.scope=WLF("此刻的%1$@", String(describing: place.title)) }
            else if let metrics=report.metrics { result.scope="\(place.title) · \(WeatherClock.string(metrics.time,metrics.daily ? "M月d日 EEE":"M月d日 HH:mm",timeZone:old.timeZoneIdentifier))" }
            return result
        }
        dataset=WeatherDataset(current:updated(old.current),hourly:old.hourly.map(updated),daily:old.daily.map(updated),fetchedAt:old.fetchedAt,next24Hours:old.next24Hours.map(updated),timeZoneIdentifier:old.timeZoneIdentifier)
    }
    func refresh() async {
        guard !loading, !Task.isCancelled else { return }
        loading = true
        requestFailed = false; serviceError = nil
        defer { loading = false }
        do {
            let data = try await loader()
            try Task.checkCancellation()
            let fetched = Date.now
            dataset = try WeatherService.decode(data, fetchedAt: fetched, place: place)
            cached = false
            connectionFailed = false
            defaults.set(data, forKey: cacheKey)
            defaults.set(fetched, forKey: cacheKey + ".date")
        } catch is CancellationError {
        } catch let e as URLError where e.code == .cancelled {
        } catch {
            connectionFailed = WeatherConnection.canRetry(error)
            requestFailed = true; serviceError = error as? WeatherServiceError
        }
    }
}
