import Foundation

func checkWeatherWidgets(fixture: Data) throws {
    let place = IslandWidgetPlace(name: "上海", latitude: 31.23, longitude: 121.47, timeZone: "Asia/Shanghai")
    var object = try JSONSerialization.jsonObject(with: fixture) as! [String: Any]
    var current = object["current"] as! [String: Any]
    current["is_day"] = 0
    current["weather_code"] = 0
    object["current"] = current
    let data = try JSONSerialization.data(withJSONObject: object)
    let parsed = try IslandWidgetClient.decode(data, place: place)
    precondition(parsed.place.name == "上海")
    precondition(parsed.symbol == "moon.stars.fill", "Night must not show the sun")
    precondition(parsed.hours.count > 24 && !parsed.days.isEmpty)
    let roundtrip = try JSONDecoder().decode(IslandWidgetWeather.self, from: JSONEncoder().encode(parsed))
    precondition(roundtrip.hours.count == parsed.hours.count && roundtrip.place == parsed.place)
    var broken = object
    var hourly = object["hourly"] as! [String: Any]
    hourly["precipitation_probability"] = []
    broken["hourly"] = hourly
    do {
        _ = try IslandWidgetClient.decode(JSONSerialization.data(withJSONObject: broken), place: place)
        preconditionFailure("Mismatched arrays must be rejected")
    } catch is URLError { }
    var daily = object["daily"] as! [String: Any]
    let count = (daily["time"] as! [Any]).count
    daily["sunrise"] = Array(repeating: NSNull(), count: count)
    daily["sunset"] = Array(repeating: NSNull(), count: count)
    object["daily"] = daily
    hourly = object["hourly"] as! [String: Any]
    hourly["precipitation_probability"] = Array(repeating: NSNull(), count: (hourly["time"] as! [Any]).count)
    object["hourly"] = hourly
    let partial = try IslandWidgetClient.decode(JSONSerialization.data(withJSONObject: object), place: place)
    precondition(partial.days.allSatisfy { $0.sunrise == nil && $0.sunset == nil })
    precondition(partial.hours.allSatisfy { $0.probability == nil }, "Missing rain must not become 0%")
    let sample = IslandWidgetWeather.sample
    precondition(sample.today(at: sample.fetchedAt) != nil)
    precondition(!sample.stale(at: sample.fetchedAt))
    precondition(sample.stale(at: sample.fetchedAt.addingTimeInterval(7201)))
    precondition(sample.upcoming(at: sample.fetchedAt.addingTimeInterval(3601)).first?.id == sample.hours[2].id)
    precondition(sample.today(at: sample.fetchedAt.addingTimeInterval(86400 * 4)) == nil)
    precondition(sample.clock(sample.fetchedAt) == "14:00")
    print("WIDGET PASS: API decoding, night symbols, Codable cache, malformed arrays, missing rain, polar daylight, stale data, hourly rollover and city timezone")
}
