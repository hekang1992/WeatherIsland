import SwiftUI

enum IslandWidgetStyle: String, CaseIterable, Identifiable {
    case landscape, rain, daylight
    var id: String { rawValue }
    var title: String {
        switch self { case .landscape: "山水天气"; case .rain: "带伞提醒"; case .daylight: "日出日落" }
    }
    var subtitle: String {
        switch self {
        case .landscape: "一眼知晴雨，把山水放在桌面。"
        case .rain: "未来六小时的雨，出门前心里有数。"
        case .daylight: "追一场日出，留住今天的余晖。"
        }
    }
    var symbol: String {
        switch self { case .landscape: "mountain.2"; case .rain: "umbrella"; case .daylight: "sun.horizon" }
    }
    var ink: Color {
        switch self {
        case .landscape: Color(red: 0.14, green: 0.29, blue: 0.26)
        case .rain: Color(red: 0.12, green: 0.29, blue: 0.43)
        case .daylight: Color(red: 0.43, green: 0.25, blue: 0.18)
        }
    }
    var accent: Color {
        switch self {
        case .landscape: Color(red: 0.29, green: 0.49, blue: 0.40)
        case .rain: Color(red: 0.23, green: 0.48, blue: 0.67)
        case .daylight: Color(red: 0.83, green: 0.43, blue: 0.24)
        }
    }
    var paper: Color {
        switch self {
        case .landscape: Color(red: 0.94, green: 0.95, blue: 0.88)
        case .rain: Color(red: 0.88, green: 0.94, blue: 0.97)
        case .daylight: Color(red: 0.99, green: 0.93, blue: 0.84)
        }
    }
}

enum IslandWidgetSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String { switch self { case .small: "小号"; case .medium: "中号"; case .large: "大号" } }
}

struct IslandWidgetBackdrop: View {
    let style: IslandWidgetStyle
    var body: some View {
        ZStack {
            style.paper
            LinearGradient(colors: [.white.opacity(0.35), .clear, style.accent.opacity(0.09)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if style == .landscape {
                IslandMountains().opacity(0.76)
            } else {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2 + 135, y: size.height / 2 - 80)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 110, y: center.y - 110, width: 220, height: 220)),
                                 with: .color(style.accent.opacity(0.06)))
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - 135, y: center.y - 135, width: 270, height: 270)),
                                   with: .color(style.accent.opacity(0.07)), lineWidth: 1)
                }
            }
        }.accessibilityHidden(true)
    }
}

private struct IslandMountains: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let sun = CGRect(x: w * 0.75, y: h * 0.19, width: min(w, h) * 0.15, height: min(w, h) * 0.15)
            context.fill(Path(ellipseIn: sun), with: .color(Color(red: 0.84, green: 0.53, blue: 0.34).opacity(0.68)))
            for layer in 0..<3 {
                let baseline = h * (0.67 + Double(layer) * 0.13)
                var p = Path()
                p.move(to: CGPoint(x: w * 0.25, y: h))
                p.addLine(to: CGPoint(x: w * 0.25, y: baseline + h * 0.13))
                p.addCurve(to: CGPoint(x: w * 0.66, y: baseline - h * 0.16),
                    control1: CGPoint(x: w * 0.4, y: baseline + h * 0.18), control2: CGPoint(x: w * 0.52, y: baseline - h * 0.33))
                p.addCurve(to: CGPoint(x: w * 1.08, y: baseline - h * 0.09),
                    control1: CGPoint(x: w * 0.79, y: baseline + h * 0.08), control2: CGPoint(x: w * 0.9, y: baseline - h * 0.39))
                p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
                context.fill(p, with: .color(Color(red: 0.27, green: 0.46, blue: 0.39).opacity(0.10 + Double(layer) * 0.09)))
            }
            var water = Path()
            for line in 0..<4 {
                let y = h * 0.88 + Double(line) * 6
                water.move(to: CGPoint(x: w * 0.64 + Double(line % 2) * 12, y: y))
                water.addLine(to: CGPoint(x: w * 0.92 - Double(line) * 5, y: y))
            }
            context.stroke(water, with: .color(.white.opacity(0.5)), lineWidth: 1)
        }
    }
}

struct IslandWidgetContent: View {
    let style: IslandWidgetStyle
    let size: IslandWidgetSize
    let weather: IslandWidgetWeather?
    var date: Date = .now
    var demo = false
    private var small: Bool { size == .small }
    private var large: Bool { size == .large }

    var body: some View {
        Group {
            if let weather {
                switch style {
                case .landscape: landscape(weather)
                case .rain: rain(weather)
                case .daylight: daylight(weather)
                }
            } else { empty }
        }
        .padding(small ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(style.ink)
        .fontDesign(.rounded)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .dynamicTypeSize(.medium)
    }

    private func heading(_ weather: IslandWidgetWeather, label: String? = nil) -> some View {
        HStack(spacing: 4) {
            Image(systemName: style.symbol).font(.system(size: 10, weight: .semibold))
            Text(label ?? weather.place.name).font(.system(size: 11, weight: .semibold))
                .truncationMode(.tail).layoutPriority(1)
            Spacer(minLength: 3)
            if !small || label != nil {
                Text(label == nil ? style.title : weather.place.name).font(.system(size: small ? 9 : 10)).opacity(0.72)
            }
        }
    }
    private func stamp(_ weather: IslandWidgetWeather) -> some View {
        HStack(spacing: 3) {
            Circle().fill(weather.stale(at: date) && !demo ? Color.orange : style.accent).frame(width: 4, height: 4)
            Text(demo ? "示例数据" : (weather.stale(at: date) ? "缓存 · " : "") + weather.clock(weather.fetchedAt, weather.stale(at: date) ? "M/d HH:mm" : "HH:mm") + " 更新")
                .font(.system(size: 9))
            Spacer(minLength: 0)
            if !small { Text("气象岛").font(.system(size: 9, weight: .medium)) }
        }.foregroundStyle(style.ink.opacity(0.65))
    }
    private func landscape(_ w: IslandWidgetWeather) -> some View {
        VStack(alignment: .leading, spacing: large ? 13 : (small ? 6 : 4)) {
            heading(w)
            if small {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(w.temperature)°").font(.system(size: 47, weight: .light, design: .serif)).tracking(-3)
                    Image(systemName: w.symbol).symbolRenderingMode(.hierarchical).font(.system(size: 18))
                }
                Text(w.condition).font(.system(size: 12, weight: .medium))
                temperatureRange(w)
                Spacer(minLength: 0)
                stamp(w)
            } else {
                HStack(alignment: .center) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(w.temperature)°").font(.system(size: large ? 64 : 46, weight: .light, design: .serif)).tracking(-3)
                        VStack(alignment: .leading, spacing: 5) {
                            Label(w.condition, systemImage: w.symbol).font(.system(size: 12, weight: .medium))
                            temperatureRange(w)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if large {
                    HStack { Text("山水有时 · 晴雨相伴").font(.system(size: 12, design: .serif)); Spacer() }
                    Divider().overlay(style.ink.opacity(0.1))
                    hourlyTemperatures(w)
                    VStack(spacing: 10) {
                        ForEach(Array(w.days.prefix(3))) { day in
                            HStack {
                                Text(day.id == w.today(at: date)?.id ? "今天" : w.clock(day.date, "EEE"))
                                    .frame(width: 32, alignment: .leading)
                                Image(systemName: day.symbol).symbolRenderingMode(.hierarchical).frame(width: 24)
                                Spacer()
                                Text("\(day.low)°").opacity(0.65)
                                Capsule().fill(LinearGradient(colors: [style.accent.opacity(0.25), style.accent], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: 70, height: 4).accessibilityHidden(true)
                                Text("\(day.high)°").frame(width: 28, alignment: .trailing)
                            }.font(.system(size: 11, weight: .medium))
                        }
                    }
                } else {
                    hourlyTemperatures(w)
                }
                Spacer(minLength: 0)
                stamp(w)
            }
        }
    }
    private func temperatureRange(_ w: IslandWidgetWeather) -> some View {
        Text(w.today(at: date).map { "最低 \($0.low)°  最高 \($0.high)°" } ?? "今日预报待更新")
            .font(.system(size: 10)).foregroundStyle(style.ink.opacity(0.75))
    }
    private func hourlyTemperatures(_ w: IslandWidgetWeather) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(w.upcoming(at: date).prefix(5))) { hour in
                VStack(spacing: large ? 7 : 4) {
                    Text(w.clock(hour.date, "HH时")).font(.system(size: 9)).opacity(0.7)
                    if large { Image(systemName: hour.symbol).symbolRenderingMode(.hierarchical).font(.system(size: 14)) }
                    Text("\(hour.temperature)°").font(.system(size: 12, weight: .medium))
                }.frame(maxWidth: .infinity)
            }
        }
    }
    private func rainHours(_ w: IslandWidgetWeather) -> [IslandWidgetHour] { Array(w.upcoming(at: date).prefix(6)) }
    private func rainTitle(_ w: IslandWidgetWeather) -> String {
        let hours = rainHours(w)
        guard hours.count == 6, hours.allSatisfy({ $0.probability != nil }) else { return "降水预报待更新" }
        if let first = hours.first(where: { ($0.probability ?? 0) >= 50 }) {
            return first.id == hours.first?.id ? "出门记得带伞" : "\(w.clock(first.date, "HH时"))起，记得带伞"
        }
        return "未来六小时雨意不浓"
    }
    private func rain(_ w: IslandWidgetWeather) -> some View {
        let hours = rainHours(w)
        let maxProbability = hours.count == 6 && hours.allSatisfy { $0.probability != nil }
            ? hours.compactMap(\.probability).max() : nil
        return VStack(alignment: .leading, spacing: large ? 10 : (small ? 4 : 5)) {
            heading(w, label: "带伞提醒")
            if small {
                Image(systemName: "umbrella.fill").font(.system(size: 23)).foregroundStyle(style.accent)
                Text(rainTitle(w)).font(.system(size: 14, weight: .semibold))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(maxProbability.map { "\(Int($0.rounded()))%" } ?? "—").font(.system(size: 29, weight: .light))
                    Text("最高概率").font(.system(size: 9)).opacity(0.7)
                }
                Spacer(minLength: 0)
                stamp(w)
            } else if large {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rainTitle(w)).font(.system(size: 21, weight: .medium, design: .serif))
                        Text("未来 6 小时 · 逐小时降水概率").font(.system(size: 10)).opacity(0.7)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "umbrella.fill").font(.system(size: 33, weight: .light)).foregroundStyle(style.accent)
                }
                rainChart(w, hours: hours, height: 78)
                HStack(spacing: 12) {
                    rainMetric("最高降水概率", value: maxProbability.map { "\(Int($0.rounded()))%" } ?? "—")
                    Rectangle().fill(style.ink.opacity(0.1)).frame(width: 1, height: 30)
                    rainMetric("六小时预计降水", value: hours.count == 6 && hours.allSatisfy { $0.precipitation != nil }
                        ? String(format: "%.1f mm", hours.compactMap(\.precipitation).reduce(0, +)) : "—")
                }.padding(12).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
                Text("逐小时预报 · 无分钟级停雨预测").font(.system(size: 10)).opacity(0.7)
                Spacer(minLength: 0)
                stamp(w)
            } else {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(rainTitle(w)).font(.system(size: 12, weight: .semibold)).lineLimit(2)
                        Text(maxProbability.map { "\(Int($0.rounded()))%" } ?? "—").font(.system(size: 28, weight: .light))
                        Text("未来六小时最高概率").font(.system(size: 9)).opacity(0.7)
                    }.frame(width: 119, alignment: .leading)
                    rainChart(w, hours: hours, height: 44)
                }
                Spacer(minLength: 0)
                stamp(w)
            }
        }
    }
    private func rainMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 9)).opacity(0.7)
            Text(value).font(.system(size: 23, weight: .light))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func rainChart(_ w: IslandWidgetWeather, hours: [IslandWidgetHour], height: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: large ? 10 : 5) {
            ForEach(hours) { hour in
                VStack(spacing: 5) {
                    Text(hour.probability.map { "\(Int($0.rounded()))" } ?? "—").font(.system(size: large ? 10 : 8))
                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4).fill(style.accent.opacity(0.09))
                            RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [style.accent.opacity(0.5), style.accent], startPoint: .top, endPoint: .bottom))
                                .frame(height: max(2, geometry.size.height * CGFloat(min(100, max(0, hour.probability ?? 0))) / 100))
                        }
                    }.frame(height: height)
                    Text(w.clock(hour.date, "HH")).font(.system(size: 9)).opacity(0.7)
                }.frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(w.clock(hour.date, "HH时"))，降水概率\(hour.probability.map { "\(Int($0))%" } ?? "暂无数据")")
            }
        }.frame(maxWidth: .infinity)
    }

    private func daylight(_ w: IslandWidgetWeather) -> some View {
        let day = w.today(at: date)
        let rise = day?.sunrise, set = day?.sunset
        let nextRise = w.days.compactMap(\.sunrise).first { $0 > date }
        let beforeRise = rise.map { date < $0 } ?? false
        let beforeSet = set.map { date < $0 } ?? false
        let target = beforeRise ? rise : (beforeSet ? set : nextRise)
        let event = beforeRise ? "距日出" : (beforeSet ? "距日落" : "距下次日出")
        return VStack(alignment: .leading, spacing: large ? 12 : (small ? 4 : 7)) {
            heading(w, label: "日出日落")
            if small {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(target.map { countdown(to: $0) } ?? "—").font(.system(size: 27, weight: .light, design: .serif))
                    Text(event).font(.system(size: 9)).opacity(0.7)
                }
                sunArc(rise: rise, set: set).frame(height: 39)
                solarTimes(w, rise: rise, set: set, compact: true)
                Spacer(minLength: 0)
                stamp(w)
            } else if large {
                HStack(alignment: .firstTextBaseline) {
                    Text(target.map { countdown(to: $0) } ?? "—").font(.system(size: 39, weight: .light, design: .serif))
                    Text(event).font(.system(size: 12)).opacity(0.7)
                    Spacer()
                    Image(systemName: beforeRise || !beforeSet ? "moon.stars" : "sun.max").font(.system(size: 23)).foregroundStyle(style.accent)
                }
                sunArc(rise: rise, set: set).frame(height: 104)
                solarTimes(w, rise: rise, set: set, compact: false)
                HStack {
                    Label("白昼时长", systemImage: "sun.max")
                    Spacer()
                    Text(rise.flatMap { r in set.map { countdown(seconds: $0.timeIntervalSince(r)) } } ?? "暂无数据")
                }.font(.system(size: 12, weight: .medium)).padding(12)
                    .background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                Text(rise == nil || set == nil ? "极昼、极夜或日照数据暂缺" : "日光行过山海，愿你从容度日。")
                    .font(.system(size: 11, design: .serif)).opacity(0.7)
                Spacer(minLength: 0)
                stamp(w)
            } else {
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event).font(.system(size: 11)).opacity(0.7)
                        Text(target.map { countdown(to: $0) } ?? "—").font(.system(size: 29, weight: .light, design: .serif))
                        Text(beforeRise ? "等第一束光" : (beforeSet ? "把余晖留给自己" : "静候明日晨光"))
                            .font(.system(size: 10, design: .serif)).opacity(0.7)
                    }.frame(width: 126, alignment: .leading)
                    VStack(spacing: 6) {
                        sunArc(rise: rise, set: set).frame(height: 54)
                        solarTimes(w, rise: rise, set: set, compact: true)
                    }
                }
                Spacer(minLength: 0)
                stamp(w)
            }
        }
    }
    private func solarTimes(_ w: IslandWidgetWeather, rise: Date?, set: Date?, compact: Bool) -> some View {
        HStack {
            Label(rise.map { w.clock($0) } ?? "—", systemImage: "sunrise")
            Spacer(minLength: 4)
            Label(set.map { w.clock($0) } ?? "—", systemImage: "sunset")
        }.font(.system(size: compact ? 9 : 13, weight: .medium))
    }
    private func countdown(to target: Date) -> String { countdown(seconds: max(0, target.timeIntervalSince(date))) }
    private func countdown(seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        return minutes >= 60 ? "\(minutes / 60)时\(String(format: "%02d", minutes % 60))分" : "\(minutes)分"
    }
    private func sunArc(rise: Date?, set: Date?) -> some View {
        Canvas { context, size in
            let left: CGFloat = 8, right = size.width - 8, bottom = size.height - 5, top: CGFloat = 7
            var curve = Path()
            curve.move(to: CGPoint(x: left, y: bottom))
            curve.addQuadCurve(to: CGPoint(x: right, y: bottom), control: CGPoint(x: size.width / 2, y: top - (bottom - top)))
            context.stroke(curve, with: .color(style.accent.opacity(0.24)), style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
            var horizon = Path(); horizon.move(to: CGPoint(x: 0, y: bottom)); horizon.addLine(to: CGPoint(x: size.width, y: bottom))
            context.stroke(horizon, with: .color(style.accent.opacity(0.24)), lineWidth: 1)
            guard let rise, let set, set > rise else { return }
            let progress = min(1, max(0, date.timeIntervalSince(rise) / set.timeIntervalSince(rise)))
            var lit = Path()
            for step in 0...60 {
                let t = progress * Double(step) / 60
                let point = CGPoint(x: left + (right - left) * t, y: bottom - 4 * (bottom - top) * t * (1 - t))
                if step == 0 { lit.move(to: point) } else { lit.addLine(to: point) }
            }
            context.stroke(lit, with: .color(style.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            if date >= rise && date <= set {
                let point = CGPoint(x: left + (right - left) * progress, y: bottom - 4 * (bottom - top) * progress * (1 - progress))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)), with: .color(style.accent.opacity(0.12)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(style.accent))
            }
        }.accessibilityHidden(true)
    }
    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(style.title, systemImage: style.symbol).font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
            Image(systemName: "leaf").font(.system(size: small ? 25 : 32)).foregroundStyle(style.accent)
            Text("让天气，住进小岛").font(.system(size: small ? 15 : 21, weight: .medium, design: .serif))
            Text("打开气象岛，选择城市\n联网后即可显示天气")
                .font(.system(size: 11)).lineLimit(2).opacity(0.75)
            Spacer(minLength: 0)
        }
    }
}
