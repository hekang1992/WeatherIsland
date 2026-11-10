import SwiftUI
import WidgetKit

struct IslandWeatherEntry: TimelineEntry, Sendable {
    let date: Date
    let weather: IslandWidgetWeather?
    var demo = false
}

struct IslandWeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> IslandWeatherEntry {
        .init(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
    }
    func getSnapshot(in context: Context, completion: @escaping @Sendable (IslandWeatherEntry) -> Void) {
        if context.isPreview {
            completion(.init(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true))
        } else {
            completion(.init(date: .now, weather: IslandWidgetCache.place.flatMap { IslandWidgetCache.read(for: $0) }))
        }
    }
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<IslandWeatherEntry>) -> Void) {
        Task {
            let now = Date.now
            guard let place = IslandWidgetCache.place else {
                completion(Timeline(entries: [.init(date: now, weather: nil)], policy: .after(now.addingTimeInterval(900))))
                return
            }
            var weather = IslandWidgetCache.read(for: place)
            var failed = false
            do {
                let fresh = try await IslandWidgetClient.fetch(place)
                // A city switch during a request must not restore the previous city.
                if IslandWidgetCache.place == place { IslandWidgetCache.save(fresh); weather = fresh }
            } catch { failed = true }
            if let selected = IslandWidgetCache.place, selected != place { weather = IslandWidgetCache.read(for: selected) }
            // Entries update countdowns without requesting the network every minute.
            let minutes = failed ? 15 : 30
            let entries = (0..<minutes).map { minute in
                IslandWeatherEntry(date: now.addingTimeInterval(Double(minute) * 60), weather: weather)
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Double(minutes) * 60))))
        }
    }
}

struct IslandSystemWidgetView: View {
    let entry: IslandWeatherEntry
    let style: IslandWidgetStyle
    @Environment(\.widgetFamily) private var family
    private var size: IslandWidgetSize {
        switch family { case .systemSmall: .small; case .systemLarge: .large; default: .medium }
    }
    var body: some View {
        IslandWidgetContent(style: style, size: size, weather: entry.weather, date: entry.date, demo: entry.demo)
            .containerBackground(for: .widget) { IslandWidgetBackdrop(style: style) }
            .widgetURL(URL(string: "weatherisland://widget/\(style.rawValue)"))
    }
}

struct LandscapeWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "IslandLandscapeWeather", provider: IslandWeatherProvider()) { entry in
            IslandSystemWidgetView(entry: entry, style: .landscape)
        }
        .configurationDisplayName(WL("山水天气"))
        .description(WL("把一卷青绿山水放在桌面，查看当前天气、逐小时气温与未来预报。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
struct UmbrellaWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "IslandUmbrellaWeather", provider: IslandWeatherProvider()) { entry in
            IslandSystemWidgetView(entry: entry, style: .rain)
        }
        .configurationDisplayName(WL("带伞提醒"))
        .description(WL("看看未来六小时的降水概率与预计雨量，出门前记得带伞。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
struct DaylightWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "IslandDaylightWeather", provider: IslandWeatherProvider()) { entry in
            IslandSystemWidgetView(entry: entry, style: .daylight)
        }
        .configurationDisplayName(WL("日出日落"))
        .description(WL("查看日出日落、白昼时长与太阳轨迹，等待下一束光。"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

@main
struct WeatherIslandWidgetBundle: WidgetBundle {
    var body: some Widget {
        LandscapeWeatherWidget()
        UmbrellaWeatherWidget()
        DaylightWeatherWidget()
    }
}

#Preview(WL("山水 · 小"), as: .systemSmall) { LandscapeWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}
#Preview(WL("带伞 · 中"), as: .systemMedium) { UmbrellaWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}
#Preview(WL("日照 · 大"), as: .systemLarge) { DaylightWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}

#Preview(WL("山水 · 中"), as: .systemMedium) { LandscapeWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}

#Preview(WL("山水 · 大"), as: .systemLarge) { LandscapeWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}

#Preview(WL("带伞 · 小"), as: .systemSmall) { UmbrellaWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}

#Preview(WL("带伞 · 大"), as: .systemLarge) { UmbrellaWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}

#Preview(WL("日照 · 小"), as: .systemSmall) { DaylightWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}

#Preview(WL("日照 · 中"), as: .systemMedium) { DaylightWeatherWidget() } timeline: {
    IslandWeatherEntry(date: IslandWidgetWeather.sample.fetchedAt, weather: .sample, demo: true)
}
