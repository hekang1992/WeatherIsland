import Foundation
import Observation

/// Coordinates are evenly spaced in Web Mercator so the forecast grid aligns with the map.
struct WeatherMapArea: Hashable, Sendable {
    var north: Double
    var south: Double
    var west: Double
    var east: Double // May exceed 180 when the region crosses the date line.
    static let side = 7

    static func around(latitude: Double, longitude: Double, span: Double = 8) -> Self {
        let latitude = min(78, max(-78, latitude))
        let half = min(12, max(0.15, span / 2))
        return .init(north: min(82, latitude + half), south: max(-82, latitude - half),
                     west: longitude - half, east: longitude + half)
    }
    static func mercator(_ latitude: Double) -> Double { log(tan(.pi / 4 + latitude * .pi / 360)) }
    static func latitude(_ y: Double) -> Double { (2 * atan(exp(y)) - .pi / 2) * 180 / .pi }
    static func longitude(_ value: Double) -> Double { (value + 180).truncatingRemainder(dividingBy: 360) + (value < -180 ? 180 : -180) }
    func coordinate(row: Int, column: Int) -> (latitude: Double, longitude: Double) {
        let fraction = Double(row) / Double(Self.side - 1)
        return (Self.latitude(Self.mercator(north) + (Self.mercator(south) - Self.mercator(north)) * fraction),
                Self.longitude(west + (east - west) * Double(column) / Double(Self.side - 1)))
    }
    func fractions(latitude: Double, longitude: Double) -> (x: Double, y: Double)? {
        let middle = (west + east) / 2
        let unwrapped = longitude + (360 * ((middle - longitude) / 360).rounded())
        let x = (unwrapped - west) / (east - west)
        let y = (Self.mercator(north) - Self.mercator(latitude)) / (Self.mercator(north) - Self.mercator(south))
        guard x.isFinite, y.isFinite, (-1e-9...1.000000001).contains(x), (-1e-9...1.000000001).contains(y) else { return nil }
        return (min(1, max(0, x)), min(1, max(0, y)))
    }
}

enum WeatherMapLayer: String, CaseIterable, Identifiable, Sendable {
    case precipitation, temperature, wind, cloud
    var id: String { rawValue }
    var title: String { switch self { case .precipitation: "降水"; case .temperature: "气温"; case .wind: "风速"; case .cloud: "云量" } }
    var symbol: String { switch self { case .precipitation: "drop.fill"; case .temperature: "thermometer.medium"; case .wind: "wind"; case .cloud: "cloud.fill" } }
    var unit: String { switch self { case .precipitation: "mm/h"; case .temperature: "°C"; case .wind: "km/h"; case .cloud: "%" } }
    var ticks: [Double] { switch self { case .precipitation: [0, 0.5, 2, 5, 10, 20]; case .temperature: [-20, -10, 0, 15, 25, 40]; case .wind: [0, 10, 20, 40, 60, 80]; case .cloud: [0, 20, 40, 60, 80, 100] } }
    var palette: [UInt32] { switch self { case .precipitation: [0x83D7E5, 0x5AAAF0, 0x7767DB, 0xD65AA9, 0xF1B75F, 0xF16661]; case .temperature: [0x7762CE, 0x6599E6, 0x72CECE, 0xD7DE96, 0xECAE6E, 0xDD6B72]; case .wind: [0xB1D9CB, 0x72C6C5, 0x69A7D1, 0x8C82D6, 0xD383BB, 0xECAD82]; case .cloud: [0xD5E9EE, 0xBDD9E6, 0x96BBD4, 0x7F9CBC, 0x7884A5, 0x6B698E] } }
    func formatted(_ value: Double) -> String { self == .precipitation ? String(format: "%.1f", value) : String(format: "%.0f", value) }
    func rgba(_ value: Double) -> (Double, Double, Double, Double) {
        let stops = ticks
        let upper = stops.firstIndex(where: { $0 >= value }) ?? stops.count - 1
        let lower = max(0, upper - 1)
        let t = lower == upper ? 0 : min(1, max(0, (value - stops[lower]) / (stops[upper] - stops[lower])))
        func channel(_ shift: UInt32) -> Double {
            let a = Double((palette[lower] >> shift) & 255), b = Double((palette[upper] >> shift) & 255)
            return (a + (b - a) * t) / 255
        }
        let opacity = self == .precipitation ? min(0.78, max(0, value / 0.4) * 0.72) : self == .cloud ? 0.12 + min(100, max(0, value)) / 160 : 0.58
        return (channel(16), channel(8), channel(0), opacity)
    }
}

struct WeatherMapForecast: Sendable {
    struct Point: Decodable, Sendable {
        struct Hourly: Decodable, Sendable {
            var time: [Double]
            var temperature_2m: [Double?]
            var precipitation: [Double?]
            var wind_speed_10m: [Double?]
            var cloud_cover: [Double?]
            func values(for layer: WeatherMapLayer) -> [Double?] {
                switch layer { case .precipitation: precipitation; case .temperature: temperature_2m; case .wind: wind_speed_10m; case .cloud: cloud_cover }
            }
        }
        var hourly: Hourly
    }
    let area: WeatherMapArea
    let points: [Point]
    let fetchedAt: Date
    let isDemo: Bool
    var times: [Date] { points.first?.hourly.time.map { Date(timeIntervalSince1970: $0) } ?? [] }
    var lastHour: Int { max(0, min(66, times.count - 1)) }

    /// Missing cells stay transparent; no extrapolation beyond the downloaded area.
    func value(layer: WeatherMapLayer, hour: Int, x: Double, y: Double) -> Double? {
        guard (0...1).contains(x), (0...1).contains(y), points.count == WeatherMapArea.side * WeatherMapArea.side else { return nil }
        let gx = x * Double(WeatherMapArea.side - 1), gy = y * Double(WeatherMapArea.side - 1)
        let x0 = Int(gx), y0 = Int(gy), x1 = min(x0 + 1, WeatherMapArea.side - 1), y1 = min(y0 + 1, WeatherMapArea.side - 1)
        let cells = [(x0, y0, (1 - (gx - Double(x0))) * (1 - (gy - Double(y0)))),
                     (x1, y0, (gx - Double(x0)) * (1 - (gy - Double(y0)))),
                     (x0, y1, (1 - (gx - Double(x0))) * (gy - Double(y0))),
                     (x1, y1, (gx - Double(x0)) * (gy - Double(y0)))]
        var result = 0.0
        for (column, row, weight) in cells where weight > 0.000001 {
            let values = points[row * WeatherMapArea.side + column].hourly.values(for: layer)
            guard values.indices.contains(hour), let value = values[hour], value.isFinite else { return nil }
            result += value * weight
        }
        return result
    }
}

enum WeatherMapService {
    static func endpoint(area: WeatherMapArea) -> URL {
        let coordinates = (0..<(WeatherMapArea.side * WeatherMapArea.side)).map { area.coordinate(row: $0 / WeatherMapArea.side, column: $0 % WeatherMapArea.side) }
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            .init(name: "latitude", value: coordinates.map { String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), $0.latitude) }.joined(separator: ",")),
            .init(name: "longitude", value: coordinates.map { String(format: "%.4f", locale: Locale(identifier: "en_US_POSIX"), $0.longitude) }.joined(separator: ",")),
            .init(name: "hourly", value: "temperature_2m,precipitation,wind_speed_10m,cloud_cover"),
            .init(name: "forecast_hours", value: "67"), .init(name: "timeformat", value: "unixtime"),
            .init(name: "timezone", value: "GMT"), .init(name: "temperature_unit", value: "celsius"),
            .init(name: "wind_speed_unit", value: "kmh"), .init(name: "precipitation_unit", value: "mm")
        ]
        return url.url!
    }
    static func decode(_ data: Data, area: WeatherMapArea) throws -> WeatherMapForecast {
        let points = try JSONDecoder().decode([WeatherMapForecast.Point].self, from: data)
        guard points.count == WeatherMapArea.side * WeatherMapArea.side, let times = points.first?.hourly.time,
              times.count > 1, zip(times, times.dropFirst()).allSatisfy({ $1 - $0 == 3600 }),
              points.allSatisfy({ point in point.hourly.time == times && WeatherMapLayer.allCases.allSatisfy { point.hourly.values(for: $0).count == times.count } }) else { throw WeatherServiceError.invalidData }
        return .init(area: area, points: points, fetchedAt: Date(), isDemo: false)
    }
    static func fetch(area: WeatherMapArea) async throws -> WeatherMapForecast {
        let request = URLRequest(url: endpoint(area: area), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 35)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw WeatherServiceError.invalidData }
        guard (200..<300).contains(response.statusCode) else { throw WeatherServiceError.response(response.statusCode) }
        try Task.checkCancellation()
        return try decode(data, area: area)
    }
    /// Only used by explicitly offline previews. Production errors never substitute demo cells.
    static func demo(area: WeatherMapArea, now: Date = Date()) -> WeatherMapForecast {
        let start = floor(now.timeIntervalSince1970 / 3600) * 3600
        let times = (0...66).map { start + Double($0) * 3600 }
        let points = (0..<49).map { index -> WeatherMapForecast.Point in
            let x = Double(index % 7) / 6, y = Double(index / 7) / 6
            let rain: [Double?] = (0...66).map { hour in
                let front = 0.32 + 0.13 * sin(Double(hour) / 8)
                let distance = pow((y - front - 0.32 * x) / 0.2, 2)
                return max(0, exp(-distance * 2) * (3 + 7 * pow(sin(x * 9 + Double(hour) / 10), 2)) - 0.2)
            }
            return .init(hourly: .init(time: times,
                temperature_2m: (0...66).map { 19 + 9 * y + 3 * sin(Double($0) / 5) },
                precipitation: rain, wind_speed_10m: (0...66).map { 8 + 24 * x + 6 * sin(Double($0) / 8 + y * 3) },
                cloud_cover: rain.map { min(100, 20 + ($0 ?? 0) * 15) }))
        }
        return .init(area: area, points: points, fetchedAt: now, isDemo: true)
    }
}

@MainActor @Observable final class WeatherMapStore {
    private(set) var forecast: WeatherMapForecast?
    private(set) var loading = false
    private(set) var error: String?
    private var requestID = UUID()
    func load(area: WeatherMapArea, offline: Bool, force: Bool = false) async {
        if !force, let forecast, forecast.area == area, Date().timeIntervalSince(forecast.fetchedAt) < 900 { return }
        let id = UUID(); requestID = id
        loading = true; error = nil
        // Never show an old region's heatmap under a new place name.
        if forecast?.area != area { forecast = nil }
        defer { if id == requestID { loading = false } }
        do {
            let result: WeatherMapForecast
            if offline { result = WeatherMapService.demo(area: area) }
            else { result = try await WeatherMapService.fetch(area: area) }
            try Task.checkCancellation()
            guard id == requestID else { return }
            forecast = result
        } catch is CancellationError { }
        catch {
            guard id == requestID, !Task.isCancelled else { return }
            self.error = "天气图层暂未加载成功，请重试。"
        }
    }
}
