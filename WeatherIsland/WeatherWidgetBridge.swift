import Foundation
#if os(iOS)
import WidgetKit

@MainActor enum WeatherWidgetBridge {
    static func place(_ place: WeatherPlace) -> IslandWidgetPlace {
        .init(name: place.title, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZoneIdentifier)
    }
    static func select(_ place: WeatherPlace) {
        if IslandWidgetCache.select(Self.place(place)) { reload() }
    }
    static func publish(_ dataset: WeatherDataset, place: WeatherPlace) {
        let snapshot = snapshot(dataset, place: place)
        IslandWidgetCache.save(snapshot)
        select(place)
        reload()
    }
    static func snapshot(_ dataset: WeatherDataset, place: WeatherPlace) -> IslandWidgetWeather {
        let current = dataset.current
        let hours = dataset.next24Hours.isEmpty ? dataset.hourly : dataset.next24Hours
        return .init(place: .init(name: place.title, latitude: place.latitude, longitude: place.longitude, timeZone: dataset.timeZoneIdentifier),
            fetchedAt: dataset.fetchedAt, observedAt: current.metrics?.time ?? dataset.fetchedAt,
            temperature: current.temperature, feelsLike: current.feelsLike, condition: current.kind.name,
            symbol: symbol(current.kind),
            hours: hours.compactMap { report in
                guard let metrics = report.metrics else { return nil }
                return .init(date: metrics.time, temperature: report.temperature, symbol: symbol(report.kind),
                             probability: metrics.probability, precipitation: metrics.precipitation)
            }, days: dataset.daily.compactMap { report in
                guard let metrics = report.metrics else { return nil }
                return .init(date: metrics.time, low: report.low, high: report.high, symbol: symbol(report.kind),
                             sunrise: metrics.sunrise, sunset: metrics.sunset)
            })
    }
    private static func symbol(_ kind: WeatherKind) -> String {
        kind == .windy ? "wind" : kind.symbol + ".fill"
    }
    private static func reload() {
        for kind in ["IslandLandscapeWeather", "IslandUmbrellaWeather", "IslandDaylightWeather"] {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
#endif
