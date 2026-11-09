import SwiftUI

/// All summaries use the same forecast and local clock as the home screen.
/// A missing probability is never treated as a zero percent chance of rain.
struct HomeWeatherInsights {
    let data: WeatherDataset
    var referenceTime: Date? = nil
    private var now: Date { referenceTime ?? data.current.metrics?.time ?? data.fetchedAt }

    var comingHours: [WeatherReport] {
        return data.next24Hours.filter {
            guard let time = $0.metrics?.time else { return false }
            return time >= now && time < now.addingTimeInterval(6 * 3600)
        }.sorted { $0.metrics!.time < $1.metrics!.time }
    }
    var rainChance: Double? { comingHours.compactMap { $0.metrics?.probability }.max() }
    var rainTitle: String {
        if let time = data.current.metrics?.time, abs(now.timeIntervalSince(time)) < 3600 {
            if data.current.kind.severe { return "等天气平稳再出发" }
            if data.current.kind.wet { return "出门记得带伞" }
        }
        guard let rainChance else { return "降水待更新" }
        return rainChance >= 50 ? "出门记得带伞" : "留意短时晴雨"
    }
    var rainNote: String {
        guard let rainChance else { return "未来 6 小时概率暂缺" }
        return "6 小时内已知最高概率 \(Int(rainChance.rounded()))%"
    }
    var outdoorWindow: (start: WeatherReport, end: WeatherReport)? {
        let hours = data.next24Hours.sorted { ($0.metrics?.time ?? .distantPast) < ($1.metrics?.time ?? .distantPast) }
        for (first, second) in zip(hours, hours.dropFirst()) {
            guard let a = first.metrics, let b = second.metrics,
                  a.time >= now, b.time.timeIntervalSince(a.time) >= 3500,
                  b.time.timeIntervalSince(a.time) <= 3700,
                  suitable(first), suitable(second),
                  let sunrise = a.sunrise, let sunset = a.sunset,
                  a.time >= sunrise, b.time.addingTimeInterval(3600) <= sunset else { continue }
            return (first, second)
        }
        return nil
    }
    private func suitable(_ report: WeatherReport) -> Bool {
        guard let m = report.metrics, let chance = m.probability, let wind = m.wind,
              let uv = m.uv, let visibility = m.visibility else { return false }
        return !report.kind.wet && !report.kind.severe && report.kind != .fog && report.kind != .snow && report.kind != .windy
            && chance < 30 && wind < 25 && uv < 6 && visibility >= 5 && (8...30).contains(report.feelsLike)
    }
    var windowLabel: String {
        guard let window = outdoorWindow, let start = window.start.metrics?.time, let end = window.end.metrics?.time else { return "先看看逐时预报" }
        let today = WeatherClock.string(now, "yyyy-MM-dd", timeZone: data.timeZoneIdentifier)
        let prefix = WeatherClock.string(start, "yyyy-MM-dd", timeZone: data.timeZoneIdentifier) == today ? "今天 " : "明天 "
        return prefix + WeatherClock.string(start, "HH:mm", timeZone: data.timeZoneIdentifier) + "—" + WeatherClock.string(end.addingTimeInterval(3600), "HH:mm", timeZone: data.timeZoneIdentifier)
    }
}

enum HomeWeatherTopic: String, Identifiable {
    case briefing, rain, air, daylight, outfit, commute, outdoor, uv, wind, humidity, visibility, precipitation, feelsLike, forecast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .briefing: "今日天气手记"
        case .rain: "带伞这件小事"
        case .air: "呼吸之间"
        case .daylight: "追着日光走"
        case .outfit: "穿衣手记"
        case .commute: "通勤备忘"
        case .outdoor: "留一点时间给户外"
        case .uv: "防晒提醒"
        case .wind: "风从哪里来"
        case .humidity: "空气里的水分"
        case .visibility: "目光能走多远"
        case .precipitation: "读懂降水量"
        case .feelsLike: "身体感受到的温度"
        case .forecast: "这一刻的天气"
        }
    }
    var symbol: String {
        switch self {
        case .briefing: "text.book.closed"
        case .rain: "umbrella"
        case .air: "aqi.medium"
        case .daylight: "sun.horizon"
        case .outfit: "tshirt"
        case .commute: "figure.walk"
        case .outdoor: "leaf"
        case .uv: "sun.max"
        case .wind: "wind"
        case .humidity: "humidity"
        case .visibility: "eye"
        case .precipitation: "drop"
        case .feelsLike: "thermometer.medium"
        case .forecast: "cloud.sun"
        }
    }
}

struct HomeWeatherSheet: Identifiable {
    let topic: HomeWeatherTopic
    var report: WeatherReport? = nil
    var id: String { topic.id + (report?.id ?? "") }
}

struct HomeWeatherInsightSheet: View {
    let selection: HomeWeatherSheet
    let data: WeatherDataset
    let quality: AirQualityReading?
    let airCached: Bool
    let airFailed: Bool
    let weatherCached: Bool
    let preview: Bool
    let style: PaperSceneStyle
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var fullDetail = false
    #if os(iOS)
    @State private var detent: PresentationDetent = .medium
    #endif

    private var topic: HomeWeatherTopic { selection.topic }
    private var report: WeatherReport { selection.report ?? ((topic == .uv || topic == .daylight) ? (data.daily.first ?? data.current) : data.current) }
    private var today: WeatherReport { data.daily.first ?? data.current }
    private var insights: HomeWeatherInsights { .init(data: data, referenceTime: preview ? nil : .now) }
    private func local(_ date: Date, _ format: String = "HH:mm") -> String {
        WeatherClock.string(date, format, timeZone: data.timeZoneIdentifier)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    introduction
                    detailContent
                    if topic == .briefing || topic == .commute || topic == .outfit {
                        HomePackingList(report: report, context: report.place.cacheID + local(preview ? (report.metrics?.time ?? data.fetchedAt) : .now, "yyyy-MM-dd"))
                    }
                    Button {
                        #if os(iOS)
                        detent = .large
                        #endif
                        fullDetail = true
                    } label: {
                        HStack { Text("查看完整天气"); Spacer(); Image(systemName: "arrow.up.right") }
                            .font(.system(size: 14, weight: .medium)).padding(16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(WeatherPalette.lime.opacity(0.45)))
                    }.buttonStyle(.plain).accessibilityIdentifier("home.sheet.fullDetail")
                    VStack(alignment: .leading, spacing: 5) {
                        Text(preview ? "离线设计示例" : "Open-Meteo · \(weatherCached ? "缓存" : "更新")于 \(local(data.fetchedAt, "M/d HH:mm"))")
                        Text("\(report.place.title) · 当地时间 · \(data.timeZoneIdentifier)")
                        Text("生活建议根据预报生成；小时预报无法确定具体的起雨分钟。")
                    }.font(.caption).foregroundStyle(WeatherPalette.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(24).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(WeatherPalette.paper)
            .foregroundStyle(WeatherPalette.ink)
            .navigationTitle(topic.title).navigationBarTitleDisplayModeIfAvailable()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly).accessibilityLabel("关闭天气手记").accessibilityIdentifier("home.sheet.close")
                }
            }
            .navigationDestination(isPresented: $fullDetail) {
                WeatherDetailView(report: report, sceneStyle: style, animate: false)
            }
        }
        .homeSheetPresentation()
        #if os(iOS)
        .presentationDetents([.medium, .large], selection: $detent)
        .onAppear { if typeSize.isAccessibilitySize { detent = .large } }
        #endif
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(report.place.title + " · " + (report.metrics?.daily == true ? local(report.metrics!.time, "M月d日 EEEE") : "天气生活指南"), systemImage: topic.symbol)
                .font(.caption).foregroundStyle(WeatherPalette.secondary)
            Text(headline).font(WeatherTypography.display(29)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("home.sheet.headline")
            Text(explanation).font(.subheadline).lineSpacing(5).foregroundStyle(WeatherPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    private var headline: String {
        switch topic {
        case .briefing: report.kind.poem
        case .rain: insights.rainTitle
        case .air: quality?.usAQI.map { "\(Int($0.rounded())) · \(quality!.label)" } ?? "空气质量暂缺"
        case .daylight: DaylightProgress.duration(sunrise: today.metrics?.sunrise, sunset: today.metrics?.sunset)
        case .outfit: report.outfitTitle
        case .commute: report.kind.severe ? "等天气平稳，再出发" : "给路途留一点余裕"
        case .outdoor: insights.windowLabel
        case .uv: "\(today.uvText) · \(today.uvLevel)"
        case .wind: report.metrics?.wind.map { String(format: "%.0f km/h", $0) } ?? "风速暂缺"
        case .humidity: report.metrics?.humidity.map { "\(Int($0.rounded()))%" } ?? "湿度暂缺"
        case .visibility: report.metrics?.visibility.map { String(format: "%.1f km", $0) } ?? "能见度暂缺"
        case .precipitation: report.metrics?.precipitation.map { String(format: "%.1f %@", $0, report.metrics?.precipitationUnit ?? "mm") } ?? "降水量暂缺"
        case .feelsLike: "体感 \(report.feelsLike)°"
        case .forecast: report.metrics?.daily == true ? "\(report.low)°—\(report.high)° · \(report.kind.name)" : "\(report.temperature)° · \(report.kind.name)"
        }
    }
    private var explanation: String {
        switch topic {
        case .briefing: "今天 \(today.low)°—\(today.high)°，温差 \(today.high - today.low)°。\(today.uvAdvice)"
        case .rain: "\(insights.rainNote)。降水概率描述出现降水的可能性，并不等于下雨时长或雨量。"
        case .air: quality?.advice ?? "空气质量与天气独立更新，数据恢复后可在首页查看。"
        case .daylight: "把日出前的期待，留到日落后的余晖。以下时间均为所选地区当地时间。"
        case .outfit: report.outfitAdvice
        case .commute: report.commute
        case .outdoor: insights.outdoorWindow == nil ? "接下来 24 小时内，暂未找到数据完整且符合筛选条件的连续两小时。可以先看看逐时预报，灵活安排。" : "在未来 24 小时里，挑出一段白天的连续两小时，作为散步时间参考。出发前再确认天气与空气质量。"
        case .uv: today.uvAdvice
        case .wind: "风速会影响体感与出行。这里使用每小时公里；开阔路段、桥面与高处的风感可能更明显。"
        case .humidity: "相对湿度表示空气接近饱和的程度，也随温度变化。搭配气温与体感一起看，更容易判断闷热或干燥。"
        case .visibility: "能见度是模型预报的水平可视距离，雾、降水和空气中的颗粒物都可能影响视野。"
        case .precipitation: "降水量按标注的时间范围累计。当前、逐小时与每日的统计口径可能不同，请连同单位一起阅读。"
        case .feelsLike: "实际气温 \(report.temperature)°。体感温度综合考虑风与湿度等因素，衣着、日晒和活动量也会影响个人感受。"
        case .forecast: report.metrics?.daily == true ? "这是当天的综合预报，温度显示全天最低与最高值。点击下方可查看完整天气。" : "\(report.metrics.map { local($0.time, "M月d日 HH:mm") } ?? report.scope) 的时段预报，方便你决定何时出门。"
        }
    }
    @ViewBuilder private var detailContent: some View {
        switch topic {
        case .briefing:
            rows([("umbrella", "带伞提醒", insights.rainNote), ("tshirt", "今日穿搭", report.outfitTitle), ("figure.walk", "路上留意", report.commute)])
        case .rain:
            if insights.comingHours.isEmpty {
                rows([("clock", "逐小时预报暂缺", "稍后下拉首页刷新，再查看未来降水变化。")])
            } else {
                VStack(spacing: 0) {
                    ForEach(insights.comingHours) { hour in
                        rainRow(hour).padding(.vertical, 13).accessibilityElement(children: .combine)
                    }
                }.padding(.horizontal, 16).background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.surface))
            }
        case .air:
            rows([("aqi.medium", "美国 AQI 标准", "0–50 优 · 51–100 良 · 101–150 敏感人群需留意 · 151 及以上需减少户外活动"),
                  ("circle.dotted", "PM2.5 / PM10", "\(quality?.pm25.map { String(format: "%.1f", $0) } ?? "—") / \(quality?.pm10.map { String(format: "%.1f", $0) } ?? "—") µg/m³"),
                  ("clock", "空气数据独立更新", quality.map { "Open-Meteo / CAMS · \(airCached ? "缓存" : "更新")于 \(local($0.fetchedAt, "M/d HH:mm"))\(airFailed ? " · 本次更新失败" : "")\n预报时刻 \(local($0.time, "M/d HH:mm"))，采用美国 AQI，与国内 AQI 口径不同。" } ?? "当前没有可用的空气数据。")])
        case .daylight:
            rows([("sunrise", "日出", today.metrics?.sunrise.map { local($0) } ?? "暂无日出数据"), ("sunset", "日落", today.metrics?.sunset.map { local($0) } ?? "暂无日落数据"), ("camera", "留住今日天色", "日落前后可以留意天空色彩，云层与降水也会影响实际观赏效果。")])
        case .outfit:
            rows([("thermometer.medium", "温度参考", "当前 \(report.temperature)° · 体感 \(report.feelsLike)°\n今日 \(report.low)°—\(report.high)°"), ("bag", "随身多带一层", report.high - report.low >= 8 ? "昼夜温差较大，带一件方便增减的外搭。" : "根据室内外温差和个人感受灵活增减衣物。")])
        case .commute:
            rows([("umbrella", "雨具", insights.rainNote), ("wind", "风与视野", "\(data.current.metrics?.wind.map { String(format: "风速 %.0f km/h", $0) } ?? "风速暂缺") · \(data.current.metrics?.visibility.map { String(format: "能见度 %.1f km", $0) } ?? "能见度暂缺")"), ("clock", "出发之前", "长途出行再确认沿途天气，留意当地道路信息与官方天气提示。")])
        case .outdoor:
            rows([("leaf", "如何挑选这段时间", "连续两小时均为日间，降水概率低于 30%、风速低于 25 km/h、紫外线低于 6、能见度至少 5 km、体感 8°—30°，且没有雨雪、雾或强风天气。"), ("aqi.medium", "再看一眼空气", quality?.advice ?? "空气质量暂缺，出发前请补充确认。"), ("cup.and.saucer", "也给室内留一个选项", report.kind.outing)])
        case .uv:
            rows([("sun.max", "今日最高紫外线", "\(today.uvText) · \(today.uvLevel)\n0–2 低 / 3–5 中等 / 6–7 高 / 8–10 很高 / 11+ 极高"), ("hat.widebrim", "遮阳小物", "根据活动时长准备遮阳帽、太阳镜，选择有遮蔽的路线。")])
        case .wind, .humidity, .visibility, .precipitation, .feelsLike, .forecast:
            forecastFacts
        }
    }
    private func rainRow(_ hour: WeatherReport) -> some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    Text(local(hour.metrics!.time, "M/d HH时")).font(.caption.monospacedDigit())
                    HStack(spacing: 12) {
                        Image(systemName: hour.kind.symbol).frame(width: 24)
                        rainBar(hour)
                        Text(hour.metrics?.probability.map { "\(Int($0.rounded()))%" } ?? "—")
                            .font(.caption.monospacedDigit()).fixedSize()
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Text(local(hour.metrics!.time, "M/d HH时")).font(.caption.monospacedDigit()).frame(minWidth: 72, alignment: .leading)
                    Image(systemName: hour.kind.symbol).frame(width: 24)
                    rainBar(hour)
                    Text(hour.metrics?.probability.map { "\(Int($0.rounded()))%" } ?? "—")
                        .font(.caption.monospacedDigit()).frame(width: 42, alignment: .trailing)
                }
            }
        }
    }
    private func rainBar(_ hour: WeatherReport) -> some View {
        GeometryReader { g in
            Capsule().fill(WeatherPalette.line.opacity(0.5))
                .overlay(alignment: .leading) {
                    Capsule().fill(WeatherPalette.ink.opacity(0.6))
                        .frame(width: g.size.width * min(max(hour.metrics?.probability ?? 0, 0), 100) / 100)
                }
        }.frame(height: 5)
    }
    private var forecastFacts: some View {
        rows([("thermometer.medium", report.metrics?.daily == true ? "全天温度范围" : "气温与体感", report.metrics?.daily == true ? "最低 \(report.low)° / 最高 \(report.high)°" : "气温 \(report.temperature)° / 体感 \(report.feelsLike)°"),
              ("drop", report.metrics?.daily == true ? "全天最高降水概率" : "降水概率", report.metrics?.probability.map { "\(Int($0.rounded()))%" } ?? "暂无数据"),
              ("wind", report.metrics?.daily == true ? "全天最大风速" : "风速", report.metrics?.wind.map { String(format: "%.0f km/h", $0) } ?? "暂无数据"),
              ("tshirt", "穿衣参考", report.outfitAdvice)])
    }
    private func rows(_ items: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider().overlay(WeatherPalette.line).padding(.leading, 48) }
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: item.0).font(.system(size: 19, weight: .light)).frame(width: 24, height: 24).foregroundStyle(WeatherPalette.accent)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.1).font(.subheadline.weight(.medium))
                        Text(item.2).font(.subheadline).foregroundStyle(WeatherPalette.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(16)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.surface))
    }
}

struct HomePackingList: View {
    let report: WeatherReport?
    let context: String
    // One bounded record, reset for another city or local forecast day.
    @AppStorage("WeatherIsland.Packing.context") private var savedContext = ""
    @AppStorage("WeatherIsland.Packing.items") private var checked = 0
    private var items: [(String, String)] {
        [("雨具", report?.kind.wet == true ? "雨伞或防水外套" : "折叠伞，随手备用"),
         ("衣物", (report?.temperature ?? 20) <= 5 ? "围巾与保暖外层" : "方便增减的外搭"),
         ("随身", "水杯、钥匙与手机")]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("出门前，点一点").font(WeatherTypography.display(20)); Spacer(); Text("\(savedContext == context ? checked.nonzeroBitCount : 0)/3").font(.caption.monospacedDigit()).foregroundStyle(WeatherPalette.secondary) }
            ForEach(0..<items.count, id: \.self) { index in
                let selected = savedContext == context && checked & (1 << index) != 0
                Button {
                    if savedContext != context { checked = 0; savedContext = context }
                    checked ^= 1 << index
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(selected ? WeatherPalette.ink : WeatherPalette.secondary)
                        VStack(alignment: .leading, spacing: 3) { Text(items[index].0).font(.subheadline.weight(.medium)); Text(items[index].1).font(.caption).foregroundStyle(WeatherPalette.secondary) }
                        Spacer()
                    }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 13).fill(WeatherPalette.lime.opacity(selected ? 0.55 : 0.2)))
                }.buttonStyle(.plain).accessibilityLabel(items[index].0 + "，" + items[index].1)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("home.packing.\(index)")
            }
            Text("仅保存在本机，切换地区或日期后重新勾选。").font(.caption).foregroundStyle(WeatherPalette.secondary)
        }
    }
}

private extension View {
    @ViewBuilder func homeSheetPresentation() -> some View {
        #if os(iOS)
        self.presentationDragIndicator(.visible).presentationCornerRadius(28)
            .presentationBackground(WeatherPalette.paper).presentationContentInteraction(.scrolls)
        #else
        self.frame(minWidth: 380, minHeight: 520)
        #endif
    }
    @ViewBuilder func navigationBarTitleDisplayModeIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
