import Foundation

func checkHomeWeatherInsights() {
    let time = Date(timeIntervalSince1970: 1793325600)
    func hour(_ offset: Double, chance: Double? = 10, wind: Double? = 12, uv: Double? = 3,
              visibility: Double? = 18, kind: WeatherKind = .partlyCloudy, feels: Int = 22,
              sunrise: Date? = time.addingTimeInterval(-3600), sunset: Date? = time.addingTimeInterval(8 * 3600)) -> WeatherReport {
        WeatherReport(kind: kind, temperature: 23, low: 18, high: 26, feelsLike: feels, scope: "测试", isDemo: true,
                      metrics: WeatherMetrics(time: time.addingTimeInterval(offset * 3600), uv: uv, probability: chance,
                                              precipitation: nil, precipitationUnit: "mm/h", wind: wind, windDirection: nil,
                                              humidity: nil, visibility: visibility, sunrise: sunrise, sunset: sunset, daily: false))
    }
    func insights(_ hours: [WeatherReport], zone: String = "Asia/Shanghai") -> HomeWeatherInsights {
        .init(data: WeatherDataset(current: hour(0), hourly: hours, daily: [], fetchedAt: time,
                                  next24Hours: hours, timeZoneIdentifier: zone))
    }
    precondition(insights([]).rainChance == nil)
    precondition(insights([hour(0, chance: nil)]).rainTitle == "降水待更新")
    precondition(insights([hour(-1, chance: 100), hour(0, chance: 10), hour(6, chance: 90)]).rainChance == 10)
    precondition(insights([hour(0, chance: 49)]).rainTitle == "留意短时晴雨")
    precondition(insights([hour(0, chance: 50)]).rainTitle == "出门记得带伞")
    let eligible = insights([hour(1), hour(2)])
    precondition(eligible.outdoorWindow != nil && eligible.windowLabel.hasPrefix("今天"))
    precondition(insights([hour(1), hour(3)]).outdoorWindow == nil, "A gap cannot form a two-hour window")
    precondition(insights([hour(2), hour(1)]).outdoorWindow?.start.metrics?.time == hour(1).metrics?.time)
    for unavailable in [hour(1, chance: nil), hour(1, wind: nil), hour(1, uv: nil), hour(1, visibility: nil)] {
        precondition(insights([unavailable, hour(2)]).outdoorWindow == nil)
    }
    for unsuitable in [hour(1, chance: 30), hour(1, wind: 25), hour(1, uv: 6), hour(1, visibility: 4.9),
                       hour(1, kind: .lightRain), hour(1, kind: .snow), hour(1, kind: .fog),
                       hour(1, kind: .thunderstorm), hour(1, feels: 31), hour(1, feels: 7),
                       hour(1, sunrise: nil), hour(1, sunset: nil), hour(1, sunset: time.addingTimeInterval(2.5 * 3600))] {
        precondition(insights([unsuitable, hour(2)]).outdoorWindow == nil)
    }
    precondition(insights([hour(-2), hour(-1)]).outdoorWindow == nil)

    let tomorrow = insights([hour(14, sunrise: time.addingTimeInterval(12 * 3600), sunset: time.addingTimeInterval(20 * 3600)), hour(15)], zone: "Asia/Shanghai")
    precondition(tomorrow.windowLabel.hasPrefix("明天"))
    let la = insights([hour(1), hour(2)], zone: "America/Los_Angeles")
    precondition(la.windowLabel != eligible.windowLabel)
    let stale = HomeWeatherInsights(data: eligible.data, referenceTime: time.addingTimeInterval(48 * 3600))
    precondition(stale.outdoorWindow == nil && stale.rainChance == nil, "Cached hours in the past are not presented as upcoming")
    print("HOME INSIGHTS PASS: missing values, rain horizon and threshold, contiguous outdoor hours, weather exclusions, daylight bounds and local dates")
}
