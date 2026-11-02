import SwiftUI

/// Weather art direction. Values on WeatherKind are used only by offline previews and the weather theatre.
enum WeatherKind: String, CaseIterable, Identifiable, Hashable {
    case clear, partlyCloudy, overcast, lightRain, moderateRain, heavyRain
    case thunderstorm, hail, snow, fog, windy

    var id: String { rawValue }
    var name: String {
        switch self {
        case .clear: "晴天"
        case .partlyCloudy: "多云"
        case .overcast: "阴天"
        case .lightRain: "小雨"
        case .moderateRain: "中雨"
        case .heavyRain: "大雨"
        case .thunderstorm: "雷暴"
        case .hail: "冰雹"
        case .snow: "下雪"
        case .fog: "雾天"
        case .windy: "大风"
        }
    }
    var symbol: String {
        switch self {
        case .clear: "sun.max"
        case .partlyCloudy: "cloud.sun"
        case .overcast: "cloud"
        case .lightRain: "cloud.drizzle"
        case .moderateRain: "cloud.rain"
        case .heavyRain: "cloud.heavyrain"
        case .thunderstorm: "cloud.bolt.rain"
        case .hail: "cloud.hail"
        case .snow: "cloud.snow"
        case .fog: "cloud.fog"
        case .windy: "wind"
        }
    }
    var poem: String {
        switch self {
        case .clear: "阳光已送达。"
        case .partlyCloudy: "云朵只是路过。"
        case .overcast: "天空按下柔光键。"
        case .lightRain: "小岛，听见雨了。"
        case .moderateRain: "雨滴正在合奏。"
        case .heavyRain: "等雨，慢一点也好。"
        case .thunderstorm: "天空在打鼓。"
        case .hail: "冰粒敲响了小岛。"
        case .snow: "今天，轻轻落白。"
        case .fog: "城市藏进了云里。"
        case .windy: "风路过，树知道。"
        }
    }
    var effectLabel: String {
        switch self {
        case .clear: "日晕转动"
        case .partlyCloudy: "浮云慢游"
        case .overcast: "层云叠影"
        case .lightRain: "疏雨轻落"
        case .moderateRain: "雨幕与涟漪"
        case .heavyRain: "密雨斜落"
        case .thunderstorm: "乌云与闪电"
        case .hail: "冰粒回弹"
        case .snow: "雪花飘落"
        case .fog: "薄雾流动"
        case .windy: "风线与落叶"
        }
    }
    var tint: Color {
        switch self {
        case .clear, .partlyCloudy: Color(hex: 0xEE8259)
        case .overcast, .fog: Color(hex: 0x8B9A94)
        case .lightRain, .moderateRain, .heavyRain: Color(hex: 0x708EAD)
        case .thunderstorm: Color(hex: 0x796F99)
        case .hail, .snow: Color(hex: 0x80A9B4)
        case .windy: Color(hex: 0x91A870)
        }
    }
    var showsSun: Bool { self == .clear || self == .partlyCloudy || self == .windy }
    var wet: Bool { [.lightRain, .moderateRain, .heavyRain, .thunderstorm, .hail].contains(self) }
    var severe: Bool { [.heavyRain, .thunderstorm, .hail, .windy].contains(self) }
    var particleCount: Int {
        switch self {
        case .lightRain: 18
        case .moderateRain: 38
        case .heavyRain: 76
        case .thunderstorm: 58
        case .hail: 28
        case .snow: 36
        default: 0
        }
    }
    var uv: Int {
        switch self {
        case .clear: 7
        case .partlyCloudy: 4
        case .overcast, .windy: 3
        case .lightRain, .moderateRain, .snow: 2
        default: 1
        }
    }
    var sampleTemperature: Int {
        switch self {
        case .clear: 26
        case .partlyCloudy: 23
        case .overcast: 21
        case .lightRain: 22
        case .moderateRain: 20
        case .heavyRain: 19
        case .thunderstorm: 21
        case .hail: 12
        case .snow: -2
        case .fog: 16
        case .windy: 18
        }
    }
    var precipitation: Double {
        switch self {
        case .lightRain: 0.6
        case .moderateRain: 3.2
        case .heavyRain: 12.0
        case .thunderstorm: 8.5
        case .hail: 4.0
        case .snow: 0.8 // Water equivalent, explicitly labeled in the detail view.
        default: 0
        }
    }
    var probability: Int {
        switch self {
        case .clear: 5
        case .partlyCloudy, .windy: 15
        case .overcast, .fog: 30
        case .lightRain: 75
        case .moderateRain: 90
        default: 95
        }
    }
    var humidity: Int {
        switch self {
        case .clear: 48
        case .partlyCloudy: 62
        case .overcast: 74
        case .lightRain: 82
        case .moderateRain: 88
        case .heavyRain, .thunderstorm: 94
        case .hail: 86
        case .snow: 79
        case .fog: 97
        case .windy: 55
        }
    }
    var windSpeed: Int {
        switch self {
        case .clear, .partlyCloudy: 9
        case .overcast, .lightRain: 12
        case .moderateRain: 18
        case .heavyRain: 27
        case .thunderstorm: 32
        case .hail: 29
        case .snow: 14
        case .fog: 5
        case .windy: 46
        }
    }
    var visibility: Double {
        switch self {
        case .fog: 0.3
        case .heavyRain: 2.0
        case .thunderstorm, .hail: 3.0
        case .moderateRain, .snow: 5.0
        case .lightRain: 8.0
        default: 12.0
        }
    }
    var reminder: String {
        switch self {
        case .clear: "阳光正好，出门记得带上帽子和遮阳用品。"
        case .partlyCloudy: "适合慢慢走，早晚加一件，别被云朵骗了阳光。"
        case .overcast: "天光柔和，适合散步；早晚微凉，备一件薄外套。"
        case .lightRain: "把折叠伞放进包里，鞋底选防滑，慢慢走。"
        case .moderateRain: "带伞也带一件防水外套，路面湿滑，预留出行时间。"
        case .heavyRain: "尽量待在室内，避开积水路段；出行前查看当地预警。"
        case .thunderstorm: "进入有防护的建筑内，远离树下和空旷处，暂停户外活动。"
        case .hail: "尽快进入坚固建筑内，远离窗户，避免在树下或临时棚下停留。"
        case .snow: "保暖、防滑都要顾到，留意路面结冰，放慢脚步。"
        case .fog: "能见度较低，尽量避开长途驾驶；行车减速并保持车距。"
        case .windy: "避开广告牌与临时搭建物，收好阳台物品，减少迎风骑行。"
        }
    }
    var outing: String {
        switch self {
        case .heavyRain, .thunderstorm, .hail: "把户外计划移到室内，等天气平稳后再出发。"
        case .snow: "短时出门，注意保暖和防滑，留意道路信息。"
        case .fog: "适合室内阅读或轻运动，等视野清晰后再远行。"
        case .windy: "选室内运动，散步时远离高大树木与松动物件。"
        case .lightRain, .moderateRain: "选有遮蔽的路线；咖啡馆与室内展览也很合适。"
        case .clear: "散步、骑行都合适，午间尽量选择有遮阴的路线。"
        default: "适合公园散步或轻运动，出门前留意短时天气变化。"
        }
    }
}

struct WeatherReport: Identifiable, Hashable {
    let kind: WeatherKind
    let temperature: Int
    let low: Int
    let high: Int
    let feelsLike: Int
    var scope: String
    let isDemo: Bool
    var metrics: WeatherMetrics? = nil
    var place: WeatherPlace = .shanghai
    var timeZoneIdentifier: String { metrics?.timeZoneIdentifier ?? place.timeZoneIdentifier }
    var id: String { "\(kind.rawValue)-\(scope)-\(temperature)-\(metrics?.time.timeIntervalSince1970 ?? 0)" }
    var uv: Double? { isLive ? metrics?.uv : Double(kind.uv) }
    var uvText: String { uv.map { String(format: "%.1f", $0) } ?? "—" }
    var isLive: Bool { metrics != nil }


    static func demo(_ kind: WeatherKind) -> WeatherReport {
        let t = kind.sampleTemperature
        return WeatherReport(kind: kind, temperature: t, low: t - 4, high: t + 3,
                             feelsLike: t - (kind == .windy || kind == .snow ? 4 : 1),
                             scope: "上海 · 天气剧场", isDemo: true)
    }
    var uvLevel: String {
        guard let uv else { return "暂无数据" }
        switch uv { case ..<3: return "低"; case ..<6: return "中等"; case ..<8: return "高"; case ..<11: return "很高"; default: return "极高" }
    }
    var uvAdvice: String {
        guard let uv else { return "紫外线数据暂缺，长时间户外活动请做好遮阳。" }
        return uv >= 6 ? "遮阳帽、太阳镜安排上；午间多走阴凉处。" : uv >= 3 ? "有云也有紫外线，户外记得做好遮阳。" : "紫外线较弱，长时间在户外仍需留意防晒。"
    }
    var outfitTitle: String {
        if temperature <= 5 { return "羽绒服 + 围巾" }
        if kind == .hail { return "保暖内搭 + 外套" }
        if kind.wet { return "长袖 + 防水外套" }
        if kind == .windy { return "长袖 + 防风外套" }
        if temperature < 18 { return "针织衫 + 外套" }
        if temperature < 25 { return "长袖 + 薄外套" }
        return "轻薄上衣 + 长裤"
    }
    var outfitAdvice: String {
        if temperature <= 5 { return "叠穿保暖层，搭配手套与防滑鞋。" }
        if kind == .hail { return "优先在室内避雹；保暖衣物不能替代遮蔽。" }
        if kind.wet { return "选快干面料和防滑鞋，包里备一双干袜子。" }
        if kind == .windy { return "外层挡风，帽子与围巾要固定好。" }
        return "白天舒适，早晚温差 \(high - low)°，外搭可随时增减。"
    }
    var commute: String {
        if kind.severe { return kind.reminder }
        if kind == .fog { return "雾天视野受限，减速行车，关注当地道路与天气提示。" }
        if kind == .snow { return "鞋底选防滑，过桥和背阴路段注意结冰。" }
        if kind.wet { return "折叠伞与防滑鞋一起带上，通勤多留一点时间。" }
        return "通勤轻装出发，包里留一件可增减的外搭。"
    }
}

enum WeatherSample {
    struct Hour: Identifiable {
        var id: String { time }
        let time: String
        let kind: WeatherKind
        let temperature: Int
        var symbol: String { kind.symbol }
        var condition: String { kind.name }
    }
    struct Day: Identifiable {
        var id: String { name }
        let name: String
        let kind: WeatherKind
        let low: Int
        let high: Int
        var symbol: String { kind.symbol }
        var condition: String { kind.name }
    }
    static let hours: [Hour] = [
        .init(time: "现在", kind: .partlyCloudy, temperature: 23),
        .init(time: "11时", kind: .partlyCloudy, temperature: 24),
        .init(time: "12时", kind: .clear, temperature: 25),
        .init(time: "13时", kind: .clear, temperature: 26),
        .init(time: "14时", kind: .clear, temperature: 26),
        .init(time: "15时", kind: .partlyCloudy, temperature: 25)
    ]
    static let days: [Day] = [
        .init(name: "今天", kind: .partlyCloudy, low: 18, high: 26),
        .init(name: "周五", kind: .clear, low: 19, high: 27),
        .init(name: "周六", kind: .moderateRain, low: 18, high: 23),
        .init(name: "周日", kind: .lightRain, low: 18, high: 24),
        .init(name: "周一", kind: .overcast, low: 17, high: 23),
        .init(name: "周二", kind: .thunderstorm, low: 16, high: 21),
        .init(name: "周三", kind: .heavyRain, low: 16, high: 20)
    ]
}
