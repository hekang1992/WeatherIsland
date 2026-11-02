import SwiftUI

/// A forecast keeps its selected time context when opening the life guide.
struct WeatherDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let report: WeatherReport
    var sceneStyle: PaperSceneStyle? = nil
    var animate = true
    var snapshot = false
    var snapshotOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .weatherReadingWidth()
            if snapshot {
                GeometryReader { geometry in
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: -snapshotOffset)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                        .clipped()
                }
            } else {
                ScrollView { content }
                    .scrollIndicators(.hidden)
            }
        }
        .background(WeatherPalette.paper.ignoresSafeArea())
        .foregroundStyle(WeatherPalette.ink)
        .islandNavigationStyle()
        .task { appeared = true }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Circle().stroke(WeatherPalette.line, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回气象岛")
            Spacer()
            VStack(spacing: 3) {
                Text("天气手记").font(.system(size: 17, weight: .semibold)).tracking(2)
                Text("WEATHER ISLAND / FIELD NOTES").font(.system(size: 7, design: .monospaced)).tracking(1)
                    .foregroundStyle(WeatherPalette.secondary)
            }
            Spacer()
            Text("生活\n指南")
                .font(.system(size: 12, weight: .medium)).lineSpacing(2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(WeatherPalette.lime.opacity(0.6)))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            weatherSummary
            reminder
            HStack(alignment: .firstTextBaseline) {
                Text("把自己，照顾好").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(report.isLive ? "生活建议 · 结合预报" : "生活指数 · 示例").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
            }
            HStack(alignment: .top, spacing: 12) {
                uvCard
                clothingCard
            }
            .opacity(!animate || snapshot || appeared ? 1 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.1), value: appeared)
            sectionTitle("天空的细节", subtitle: "WEATHER DETAILS")
            metrics
            sectionTitle("给今天一点灵感", subtitle: "YOUR DAY, YOUR WAY")
            VStack(spacing: 0) {
                adviceRow(number: "01", title: "出门前", symbol: "figure.walk", text: report.commute)
                Divider().overlay(WeatherPalette.line).padding(.leading, 42)
                adviceRow(number: "02", title: "去哪里", symbol: "leaf", text: report.kind.outing)
                Divider().overlay(WeatherPalette.line).padding(.leading, 42)
                adviceRow(number: "03", title: "包里带上", symbol: "bag", text: packingAdvice)
            }
            .padding(.horizontal, 15)
            .background(RoundedRectangle(cornerRadius: 20).fill(WeatherPalette.surface))
            daylight
            if let metrics = report.metrics {
                Text("预报时段 · " + WeatherClock.string(metrics.time, metrics.daily ? "yyyy年M月d日" : "yyyy年M月d日 HH:mm", timeZone: report.timeZoneIdentifier))
                    .font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                WeatherWebLink("天气数据：Open-Meteo", destination: URL(string: "https://open-meteo.com/")!)
                    .font(.system(size: 12)).foregroundStyle(WeatherPalette.ink)
            }
            Text(report.isLive ? "数据来源 Open-Meteo · 模型天气与预报\n穿衣与出行建议由本地规则生成，仅供日常参考。\n紫外线与能见度采用相近小时预报；缺失值显示 —。" : "离线天气手记 / 所有天气与生活指数均为固定示例。\n天气剧场不代表当地实况；出行请结合当地预报与预警。")
                .font(.system(size: 12)).lineSpacing(4)
                .foregroundStyle(WeatherPalette.secondary)
                .padding(.top, 3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 30)
        .weatherReadingWidth()
    }

    private var weatherSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Circle().fill(report.kind.tint).frame(width: 5, height: 5)
                Text(report.scope).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(report.isLive ? "Open-Meteo 预报" : report.isDemo ? "天气体验" : "示例预报")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WeatherPalette.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    summaryReading.fixedSize(horizontal: true, vertical: true)
                    summaryScene.frame(minWidth: 140, maxWidth: 280)
                }
                VStack(alignment: .leading, spacing: 16) {
                    summaryReading
                    summaryScene
                }
            }
            .padding(.vertical, 12)
            HStack(spacing: 15) {
                Text("最高 \(report.high)° / 最低 \(report.low)°")
                Text("体感 \(report.feelsLike)°")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(WeatherPalette.secondary)
        }
    }

    private var summaryReading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("\(report.temperature)°")
                .font(.system(size: 65, weight: .regular, design: .serif))
                .tracking(-3)
            Text(report.kind.name).font(.system(size: 17, weight: .semibold))
            Text(report.kind.poem).font(.system(size: 12))
                .foregroundStyle(WeatherPalette.secondary)
        }
        .accessibilityIdentifier("detail.reading")
    }

    private var summaryScene: some View {
        PaperCityScene(style: sceneStyle ?? .automatic(for: report.place), kind: report.kind, animate: animate && !snapshot)
            .aspectRatio(360.0 / 248, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .accessibilityHidden(true)
    }

    private var reminder: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: report.kind.severe ? "exclamationmark.shield" : "sparkles")
                .font(.system(size: 16)).frame(width: 20).padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(report.kind.severe ? "出行提醒 · 场景演示" : "小岛的今日叮咛")
                    .font(.system(size: 12, weight: .semibold))
                Text(report.kind.reminder).font(.system(size: 12)).lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(report.kind.severe ? report.kind.tint.opacity(0.15) : WeatherPalette.lime.opacity(0.45)))
    }

    private var uvCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(report.metrics?.daily == true ? "最高紫外线" : "紫外线", systemImage: "sun.max")
                .font(.system(size: 12, weight: .medium))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(report.uvText).font(.system(size: 32, weight: .regular, design: .serif))
                Text(report.uvLevel).font(.system(size: 12, weight: .medium))
            }
            uvMeter
            Text(report.uvAdvice).font(.system(size: 12)).lineSpacing(3)
                .foregroundStyle(WeatherPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 167, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(WeatherPalette.line, lineWidth: 0.7))
        .accessibilityElement(children: .combine)
    }

    private var uvBand: Int {
        switch report.uv ?? 0 {
        case ..<3: 0
        case ..<6: 1
        case ..<8: 2
        case ..<11: 3
        default: 4
        }
    }

    private var uvMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach([0xA9C498, 0xDFCE84, 0xE5A06B, 0xCC8374, 0xA793B4], id: \.self) { hex in
                        Capsule().fill(Color(hex: UInt32(hex)))
                    }
                }
                Circle().fill(WeatherPalette.ink).frame(width: 6, height: 6)
                    .overlay(Circle().stroke(WeatherPalette.paper, lineWidth: 1))
                    .offset(x: (geometry.size.width - 6) * (CGFloat(uvBand) + 0.5) / 5)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    private var clothingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("穿衣灵感", systemImage: "tshirt")
                .font(.system(size: 12, weight: .medium))
            Image(systemName: report.temperature <= 5 ? "snowflake" : report.kind.wet ? "umbrella" : "tshirt")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(report.kind.tint)
                .frame(height: 33)
            Text(report.outfitTitle).font(.system(size: 12, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(report.outfitAdvice).font(.system(size: 12)).lineSpacing(3)
                .foregroundStyle(WeatherPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 167, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.lime.opacity(0.45)))
        .accessibilityElement(children: .combine)
    }

    private func number(_ value: Double?, decimals: Int = 0) -> String {
        guard let value else { return "—" }
        return String(format: "%.*f", decimals, value)
    }

    private var metrics: some View {
        let m = report.metrics
        let daily = m?.daily == true
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metric(daily ? "最高降水概率" : "降水概率", value: number(report.isLive ? m?.probability : Double(report.kind.probability)), unit: "%", symbol: "umbrella", note: daily ? "全天最高概率" : "相近小时预报")
            metric(daily ? "全天降水量" : "时段降水量", value: number(report.isLive ? m?.precipitation : report.kind.precipitation, decimals: 1), unit: m?.precipitationUnit ?? "mm/h", symbol: "drop", note: report.kind == .snow ? "含降雪水当量" : "对应时段的累计量")
            metric(daily ? "最高风速" : "风速", value: number(report.isLive ? m?.wind : Double(report.kind.windSpeed)), unit: "km/h", symbol: "wind", note: windNote)
            metric("相对湿度", value: number(report.isLive ? m?.humidity : Double(report.kind.humidity)), unit: "%", symbol: "humidity", note: daily ? "日汇总未提供" : "空气中的水分")
            metric("能见度", value: number(report.isLive ? m?.visibility : report.kind.visibility, decimals: 1), unit: "km", symbol: "eye", note: daily ? "日汇总未提供" : "相近小时预报")
            metric(daily ? "最高体感温度" : "体感温度", value: "\(report.feelsLike)", unit: "°C", symbol: "thermometer.medium", note: "与气温一起参考")
        }
    }

    private var windNote: String {
        guard report.isLive else { return "风速 · 示例" }
        guard let direction = report.metrics?.windDirection else { return "风向暂无数据" }
        let names = ["北风", "东北风", "东风", "东南风", "南风", "西南风", "西风", "西北风"]
        return names[Int((direction + 22.5) / 45) % 8]
    }

    private func metric(_ title: String, value: String, unit: String, symbol: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol).font(.system(size: 12, weight: .medium))
                .foregroundStyle(WeatherPalette.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 24, weight: .regular, design: .serif))
                Text(unit).font(.system(size: 12))
            }
            Text(note).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).stroke(WeatherPalette.line, lineWidth: 0.8))
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        HStack {
            Text(title).font(.system(size: 16, weight: .semibold))
            Spacer()
            Text(subtitle).font(.system(size: 7, design: .monospaced)).tracking(0.5)
                .foregroundStyle(WeatherPalette.secondary)
        }
        .padding(.top, 2)
    }

    private func adviceRow(number: String, title: String, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: symbol).font(.system(size: 18, weight: .light))
                    .frame(width: 30, height: 30)
                Text(number).font(.system(size: 6, design: .monospaced)).offset(x: 3, y: 5)
                    .foregroundStyle(WeatherPalette.accent)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(text).font(.system(size: 12)).lineSpacing(4)
                    .foregroundStyle(WeatherPalette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var packingAdvice: String {
        if report.kind == .hail || report.kind == .thunderstorm || report.kind == .heavyRain {
            return "必要出行前看预警，手机充好电；优先安排室内等待，随身雨具不能替代安全遮蔽。"
        }
        if report.temperature <= 5 { return "围巾、手套、保温杯，再加一双防滑鞋。" }
        if report.kind.wet { return "折叠伞、防水袋与一小包纸巾，给雨天多一点从容。" }
        if report.kind == .windy { return "防风外套和水杯，背包拉链收好，少带易被风吹走的物件。" }
        return "水杯、薄外套与遮阳用品，轻轻松松出发。"
    }

    private func sunTime(_ time: Date?, sample: String) -> String {
        if !report.isLive { return sample }
        return time.map { WeatherClock.string($0, "HH:mm", timeZone: report.timeZoneIdentifier) } ?? "—"
    }

    private var daylight: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("把日光，也收藏起来").font(.system(size: 13, weight: .medium))
                Spacer()
                Text(report.isLive ? "日出 / 日落" : "日出 / 日落 · 示例").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
            }
            GeometryReader { geometry in
                let width = max(0, geometry.size.width - 18)
                ZStack(alignment: .topLeading) {
                    Path { p in
                        p.move(to: .init(x: 9, y: 35))
                        p.addQuadCurve(to: .init(x: width + 9, y: 35), control: .init(x: width / 2 + 9, y: -25))
                    }
                    .stroke(WeatherPalette.accent.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    Image(systemName: "sun.max.fill").foregroundStyle(WeatherPalette.accent)
                        .font(.system(size: 18)).position(x: width * 0.42 + 9, y: 6)
                }
            }
            .frame(height: 36)
            HStack {
                Text(sunTime(report.metrics?.sunrise, sample: "06:08") + " 日出")
                Spacer()
                Text(sunTime(report.metrics?.sunset, sample: "17:06") + " 日落")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.lime.opacity(0.3)))
    }
}

extension View {
    /// Limit reading line lengths while keeping the page background edge to edge.
    func weatherReadingWidth(_ width: CGFloat = 720) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }

    @ViewBuilder func islandNavigationStyle() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
