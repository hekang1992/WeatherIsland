import Foundation

enum WeatherMapChecks {
    @MainActor static func run() async throws {
        let area = WeatherMapArea.around(latitude: 31.23, longitude: 121.47)
        let components = URLComponents(url: WeatherMapService.endpoint(area: area), resolvingAgainstBaseURL: false)!
        let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
        precondition(query["latitude"]!.split(separator: ",").count == 49)
        precondition(query["longitude"]!.split(separator: ",").count == 49)
        precondition(query["forecast_hours"] == "67" && query["timeformat"] == "unixtime")
        precondition(query["hourly"] == "temperature_2m,precipitation,wind_speed_10m,cloud_cover")
        precondition(query["wind_speed_unit"] == "kmh" && query["precipitation_unit"] == "mm")
        for row in 0..<7 {
            for column in 0..<7 {
                let coordinate = area.coordinate(row: row, column: column)
                let position = area.fractions(latitude: coordinate.latitude, longitude: coordinate.longitude)!
                precondition(abs(position.x - Double(column) / 6) < 0.000001)
                precondition(abs(position.y - Double(row) / 6) < 0.000001)
            }
        }
        let dateLine = WeatherMapArea.around(latitude: 0, longitude: 179)
        precondition(dateLine.fractions(latitude: 0, longitude: -179) != nil)
        precondition(dateLine.coordinate(row: 3, column: 6).longitude < 0)
        precondition(WeatherMapArea.around(latitude: 89, longitude: -179).north <= 82)
        precondition(WeatherMapArea.longitude(-181) == 179 && WeatherMapArea.longitude(181) == -179)
        let times = [1_793_340_000, 1_793_343_600, 1_793_347_200]
        var payload: [[String: Any]] = (0..<49).map { index in
            let value = Double(index % 7 + (index / 7) * 2)
            return ["hourly": ["time": times, "temperature_2m": [value, value + 1, value + 2], "precipitation": [0, 0.5, 1], "wind_speed_10m": [10, 20, 30], "cloud_cover": [25, 50, 75]]]
        }
        func decode(_ payload: [[String: Any]]) throws -> WeatherMapForecast { try WeatherMapService.decode(JSONSerialization.data(withJSONObject: payload), area: area) }
        let forecast = try decode(payload)
        precondition(!forecast.isDemo && forecast.times.count == 3 && forecast.lastHour == 2)
        precondition(abs(forecast.value(layer: .temperature, hour: 0, x: 0.25, y: 0.25)! - 4.5) < 0.00001)
        precondition(forecast.value(layer: .temperature, hour: 1, x: 1, y: 1) == 19)
        precondition(forecast.value(layer: .precipitation, hour: 0, x: 0.5, y: 0.5) == 0)
        precondition(forecast.value(layer: .cloud, hour: 0, x: -0.1, y: 0.5) == nil)
        precondition(forecast.value(layer: .wind, hour: 9, x: 0.5, y: 0.5) == nil)
        var hourly = payload[0]["hourly"] as! [String: Any]
        hourly["temperature_2m"] = [NSNull(), 1, 2]
        payload[0]["hourly"] = hourly
        let missing = try decode(payload)
        precondition(missing.value(layer: .temperature, hour: 0, x: 0, y: 0) == nil)
        precondition(missing.value(layer: .temperature, hour: 0, x: 0.5, y: 0.5) == 9)
        do { _ = try decode(Array(payload.dropLast())); preconditionFailure("Missing grid point accepted") } catch WeatherServiceError.invalidData { }
        hourly["time"] = [times[0], times[1] + 10, times[2]]
        payload[0]["hourly"] = hourly
        do { _ = try decode(payload); preconditionFailure("Misaligned times accepted") } catch WeatherServiceError.invalidData { }
        let dry = WeatherMapLayer.precipitation.rgba(0)
        precondition(dry.3 == 0 && WeatherMapLayer.precipitation.rgba(5).3 > 0.5)
        let demo = WeatherMapService.demo(area: area)
        precondition(demo.isDemo && demo.points.count == 49 && demo.lastHour == 66)
        let store = WeatherMapStore()
        await store.load(area: area, offline: true)
        precondition(store.forecast?.isDemo == true && !store.loading && store.error == nil)
        let fetchedAt = store.forecast!.fetchedAt
        await store.load(area: area, offline: true)
        precondition(store.forecast!.fetchedAt == fetchedAt)
        await store.load(area: dateLine, offline: true)
        precondition(store.forecast?.area == dateLine)
        if CommandLine.arguments.contains("--map-live") {
            let live = try await WeatherMapService.fetch(area: area)
            precondition(!live.isDemo && live.points.count == 49 && live.lastHour == 66)
            print("MAP LIVE PASS: 49 coordinates → Open-Meteo → 67 aligned hourly points → forecast grid")
        }
        print("MAP PASS: 49-coordinate request, Mercator alignment, date-line wrap, bilinear values, missing cells, malformed grids, 66-hour horizon, transparent dry cells and regional cache")
    }
}
