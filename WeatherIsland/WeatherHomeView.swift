import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A miniature Shanghai whose sky changes when an hour or forecast ticket is selected.
struct WeatherHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var temperature: Int
    @State private var entered: Bool
    @State private var selectedHour = 0
    @State private var selectedDay: Int?
    @State private var sunRotation = 0.0
    @State private var cloudFloating = false
    @State private var started = false
    @State private var settingsPresented = false
    @State private var demoKind: WeatherKind?
    @State private var detailReport: WeatherReport?
    @State private var store: WeatherStore
    private let entryReady: Bool
    private let useLiveData: Bool
    private let animate: Bool
    private let snapshot: Bool

    init(animate: Bool = true, snapshot: Bool = false, initialHour: Int = 0, initialDay: Int? = nil, initialWeather: WeatherKind? = nil, useLiveData: Bool = false, entryReady: Bool = true) {
        self.entryReady = entryReady
        self.useLiveData = useLiveData
        _store = State(initialValue: WeatherStore(live: useLiveData))
        self.animate = animate
        self.snapshot = snapshot
        let hour = min(max(initialHour, 0), WeatherSample.hours.count - 1)
        let day = initialDay.map { min(max($0, 0), WeatherSample.days.count - 1) }
        let target = initialWeather?.sampleTemperature ?? day.map { WeatherSample.days[$0].high } ?? WeatherSample.hours[hour].temperature
        _demoKind = State(initialValue: initialWeather)
        _selectedHour = State(initialValue: hour)
        _selectedDay = State(initialValue: initialWeather == nil ? day : nil)
        _temperature = State(initialValue: animate ? 0 : target)
        _entered = State(initialValue: !animate)
    }

    private var hours: [WeatherSample.Hour] { store.dataset?.hours ?? WeatherSample.hours }
    private var days: [WeatherSample.Day] { store.dataset?.days ?? WeatherSample.days }
    private var day: WeatherSample.Day { days[min(selectedDay ?? 0, days.count - 1)] }
    private var sourceLabel: String {
        if demoKind != nil { return "天气剧场 · 离线演示" }
        guard useLiveData else { return "离线示例 / 点小岛看详情" }
        guard let data = store.dataset else { return "正在连接天气服务" }
        return "Open-Meteo · \(store.cached || store.error != nil ? "缓存 " : "更新 ")\(WeatherClock.string(data.fetchedAt, "M/d HH:mm"))"
    }
    private func refresh() async {
        guard useLiveData else { return }
        await store.refresh()
        if store.dataset != nil && demoKind == nil {
            selectedHour = 0
            selectedDay = nil
            if entered { temperature = report.temperature }
        }
    }

    private var report: WeatherReport {
        if let demoKind { return .demo(demoKind) }
        if let data = store.dataset {
            if let selectedDay { return data.daily[min(selectedDay, data.daily.count - 1)] }
            return data.hourly[min(selectedHour, data.hourly.count - 1)]
        }
        let kind = selectedDay != nil ? day.kind : hours[selectedHour].kind
        let value = selectedDay != nil ? day.high : hours[selectedHour].temperature
        return WeatherReport(kind: kind, temperature: value, low: day.low, high: day.high,
                             feelsLike: value - 1, scope: scope, isDemo: false)
    }
    private var condition: String { report.kind.name }
    private var scope: String {
        if demoKind != nil { return "上海 · 天气剧场" }
        if store.dataset != nil { return report.scope }
        if selectedDay != nil { return "\(day.name) · 日间最高" }
        return selectedHour == 0 ? "此刻的上海" : "今天 \(hours[selectedHour].time)"
    }

    var body: some View {
        Group {
            if snapshot { homeLayout }
            else {
                NavigationStack {
                    homeLayout
                        .islandNavigationStyle()
                        .navigationDestination(item: $detailReport) { report in
                            WeatherDetailView(report: report, animate: animate)
                        }
                }
            }
        }
        .task { await refresh() }
        .task(id: entryReady) {
            if entryReady { await enter() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, useLiveData,
               Date.now.timeIntervalSince(store.dataset?.fetchedAt ?? .distantPast) > 600 {
                Task { await refresh() }
            }
        }
        .sheet(isPresented: $settingsPresented) {
            WeatherExplorerView(selected: report.kind) { kind in
                withAnimation(entrance(0.4)) { demoKind = kind; selectedDay = nil }
                temperature = kind.sampleTemperature
                settingsPresented = false
            }
        }
    }

    private var homeLayout: some View {
        GeometryReader { geometry in
            if useLiveData && store.dataset == nil && demoKind == nil {
                VStack(spacing: 18) {
                    Image(systemName: "cloud.sun").font(.system(size: 44, weight: .light))
                    Text(store.loading || store.error == nil ? "正在为小岛接通天空…" : "暂时没收到天气来信")
                        .font(.system(size: 20, weight: .medium))
                    if store.loading || store.error == nil { ProgressView() }
                    if let error = store.error {
                        Text(error).font(.system(size: 13)).multilineTextAlignment(.center)
                        Button("重新连接") { Task { await refresh() } }.buttonStyle(.borderedProminent)
                        Button("先逛逛天气剧场") { settingsPresented = true }
                    }
                }
                .tint(WeatherPalette.ink)
                .foregroundStyle(WeatherPalette.ink)
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if snapshot { content(height: geometry.size.height) }
            else {
                ScrollView(.vertical) { content(height: geometry.size.height) }
                    .scrollIndicators(.hidden)
                    .refreshable { await refresh() }
            }
        }
        .background(WeatherPalette.paper.ignoresSafeArea())
    }

    private func content(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            header
            if useLiveData && (demoKind != nil || store.error != nil || store.cached) {
                HStack(spacing: 8) {
                    Text(demoKind != nil ? "天气剧场 · 演示数据" : store.error != nil ? "更新失败，显示上次缓存" : "上次天气 · 正在更新")
                        .font(.system(size: 10))
                    Spacer()
                    Button(demoKind != nil ? "返回实况" : "重试") {
                        if demoKind != nil {
                            demoKind = nil; selectedDay = nil; selectedHour = 0
                            temperature = report.temperature
                        }
                        Task { await refresh() }
                    }.font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(WeatherPalette.ink)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(WeatherPalette.lime.opacity(0.5)))
                .padding(.top, 6)
            }
            Button { detailReport = report } label: { islandWeather }
                .buttonStyle(.plain)
                .padding(.top, height < 730 ? 4 : 14)
            hourlyOrbit
                .padding(.top, 16)
                .opacity(entered ? 1 : 0)
                .offset(y: entered ? 0 : 16)
                .animation(entrance(0.55), value: entered)
            weekTickets
                .padding(.top, 18)
            HStack {
                if useLiveData && demoKind == nil {
                    Link(sourceLabel, destination: URL(string: "https://open-meteo.com/")!)
                } else { Text(sourceLabel) }
                Spacer()
                Text("11 种天空")
            }
            .font(.system(size: 8, weight: .medium, design: .monospaced))
            .foregroundStyle(WeatherPalette.secondary)
            .frame(height: 14)
            .padding(.top, 16)
            .opacity(entered ? 1 : 0)
            .animation(entrance(0.45, delay: 0.6), value: entered)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .top)
    }

    private var header: some View {
        HStack(spacing: 9) {
            WeatherBrandMark()
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("气象岛")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WeatherPalette.ink)
                Text("把今天，过成好天气")
                    .font(.system(size: 9))
                    .foregroundStyle(WeatherPalette.secondary)
            }
            Spacer()
            Button { settingsPresented = true } label: {
                HStack(spacing: 7) {
                    Circle().fill(WeatherPalette.lime).frame(width: 5, height: 5)
                    Text("天气剧场").font(.system(size: 11, weight: .medium))
                    Image(systemName: "sparkles").font(.system(size: 8, weight: .semibold))
                }
                .foregroundStyle(WeatherPalette.paper)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(WeatherPalette.ink))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开天气剧场，可切换 11 种示例天气")
        }
        .frame(height: 48)
    }

    private var islandWeather: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                HStack(spacing: 5) {
                    Circle().fill(WeatherPalette.accent).frame(width: 4, height: 4)
                    Text(scope)
                    Text(demoKind != nil ? "/ 离线演示" : store.dataset != nil ? "/ " + WeatherClock.string(report.metrics!.time, "M月d日 EEE") : "/ 10月30日 周四")
                        .foregroundStyle(WeatherPalette.secondary)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WeatherPalette.ink)
                .frame(height: 16)

                Text("\(temperature)°")
                    .font(.system(size: 100, weight: .regular, design: .serif))
                    .tracking(-6)
                    .monospacedDigit()
                    .foregroundStyle(WeatherPalette.ink)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: temperature)
                    .offset(x: -3, y: 9)
                    .accessibilityLabel("\(scope)，\(temperature) 摄氏度，\(condition)")

                VStack(alignment: .leading, spacing: 6) {
                    Text(condition)
                        .font(.system(size: 16, weight: .semibold))
                    Text(report.kind.poem)
                        .font(.system(size: 10))
                        .foregroundStyle(WeatherPalette.secondary)
                    Text("天气详情 ↗")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(WeatherPalette.accent)
                }
                .foregroundStyle(WeatherPalette.ink)
                .offset(x: width - 116, y: 42)

                IslandScene(
                    kind: report.kind, animate: animate && !snapshot && detailReport == nil && !settingsPresented,
                    rotation: sunRotation, cloudOffset: cloudFloating ? -4 : 4
                )
                .frame(width: width + 20, height: 230)
                .offset(x: -10, y: 91)
                .accessibilityHidden(true)

                HStack(spacing: 0) {
                    metric("最高", value: "\(report.high)°")
                    metric("最低", value: "\(report.low)°")
                    metric(selectedDay == nil ? "体感" : "预报", value: selectedDay == nil ? "\(report.feelsLike)°" : "日间")
                }
                .frame(height: 35)
                .background(Capsule().fill(WeatherPalette.surface))
                .overlay(Capsule().strokeBorder(WeatherPalette.line, lineWidth: 0.7))
                .padding(.horizontal, 25)
                .offset(y: 305)
            }
            .opacity(entered ? 1 : 0)
            .offset(y: entered ? 0 : 8)
            .animation(entrance(0.65), value: entered)
        }
        .frame(height: 340)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scope)，\(condition)，\(temperature) 摄氏度。打开天气详情与生活建议")
        .accessibilityAddTraits(.isButton)
    }

    private func metric(_ title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title).font(.system(size: 9)).foregroundStyle(WeatherPalette.secondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(WeatherPalette.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var hourlyOrbit: some View {
        VStack(spacing: 5) {
            HStack {
                Text(store.dataset == nil ? "今天的温度轨道" : "接下来的温度轨道")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WeatherPalette.ink)
                Spacer()
                Text("逐小时 · 点选看天空")
                    .font(.system(size: 9))
                    .foregroundStyle(WeatherPalette.secondary)
            }
            .frame(height: 18)
            GeometryReader { geometry in
                let cell = geometry.size.width / 6
                ZStack(alignment: .topLeading) {
                    Path { path in
                        for index in hours.indices {
                            let point = CGPoint(x: cell * (CGFloat(index) + 0.5), y: 36 + orbitOffset(index))
                            if index == 0 { path.move(to: point) }
                            else { path.addLine(to: point) }
                        }
                    }
                    .stroke(LinearGradient(colors: [WeatherPalette.accent, Color(hex: 0xE6BC69)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    ForEach(Array(hours.enumerated()), id: \.element.id) { index, hour in
                        let active = demoKind == nil && selectedDay == nil && selectedHour == index
                        Button { selectHour(index) } label: {
                            VStack(spacing: 0) {
                                Text("\(hour.temperature)°")
                                    .font(.system(size: 16, weight: active ? .semibold : .medium, design: .rounded))
                                    .foregroundStyle(WeatherPalette.ink)
                                    .frame(height: 20)
                                    .padding(.bottom, 4)
                                ZStack {
                                    Circle().fill(active ? WeatherPalette.accent : WeatherPalette.paper)
                                        .frame(width: active ? 8 : 5, height: active ? 8 : 5)
                                    if active {
                                        Circle().stroke(WeatherPalette.accent, lineWidth: 1)
                                            .frame(width: 16, height: 16)
                                    }
                                }
                                .frame(height: 16)
                                .padding(.bottom, 6)
                                Text(hour.time)
                                    .font(.system(size: 9, weight: active ? .semibold : .regular))
                                    .foregroundStyle(active ? WeatherPalette.accent : WeatherPalette.secondary)
                                    .frame(height: 12)
                            }
                            .frame(width: cell, height: 58)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .offset(x: cell * CGFloat(index), y: 4 + orbitOffset(index))
                        .opacity(entered ? 1 : 0)
                        .animation(entrance(0.45, delay: Double(index) * 0.08), value: entered)
                        .accessibilityLabel("\(hour.time)，\(hour.condition)，\(hour.temperature) 度，切换小岛天气")
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
            }
            .frame(height: 87)
        }
        .frame(height: 110)
    }

    private func orbitOffset(_ index: Int) -> CGFloat {
        CGFloat((hours.map(\.temperature).max() ?? 26) - hours[index].temperature) * min(8, 34 / CGFloat(max(1, (hours.map(\.temperature).max() ?? 26) - (hours.map(\.temperature).min() ?? 23))))
    }

    private var weekTickets: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("一周天气收藏")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WeatherPalette.ink)
                Spacer()
                Text("7 DAYS  ↗")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(WeatherPalette.secondary)
            }
            .frame(height: 18)
            if snapshot {
                GeometryReader { geometry in
                    ticketsRow
                        .frame(width: geometry.size.width, alignment: .leading)
                        .offset(x: -CGFloat(max(0, min((selectedDay ?? 0) - 1, 4))) * 98)
                        .clipped()
                }
                .frame(height: 114)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) { ticketsRow }
                        .scrollIndicators(.hidden)
                        .onAppear {
                            proxy.scrollTo(selectedDay ?? 0, anchor: .center)
                        }
                }
            }
        }
        .frame(height: 142)
    }

    private var ticketsRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, item in
                let active = demoKind == nil && (selectedDay ?? 0) == index
                Button { selectDay(index) } label: {
                    ForecastTicket(day: item, index: index, active: active, entered: entered, animation: entrance(0.5, delay: Double(index) * 0.06))
                }
                .buttonStyle(.plain)
                .id(index)
                .opacity(entered ? 1 : 0)
                .animation(entrance(0.45, delay: Double(index) * 0.06), value: entered)
                .accessibilityLabel("\(item.name)，\(item.condition)，最低 \(item.low) 度，最高 \(item.high) 度")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: 114)
    }

    private func selectHour(_ index: Int) {
        withAnimation(entrance(0.4)) {
            demoKind = nil
            selectedDay = nil
            selectedHour = index
        }
        temperature = hours[index].temperature
    }

    private func selectDay(_ index: Int) {
        withAnimation(entrance(0.4)) { demoKind = nil; selectedDay = index }
        temperature = days[index].high
    }

    private func entrance(_ duration: Double, delay: Double = 0) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration).delay(delay)
    }

    @MainActor private func enter() async {
        guard animate, !started else { return }
        started = true
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        temperature = report.temperature
        entered = true
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 2).repeatCount(1, autoreverses: false)) { sunRotation = 360 }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { cloudFloating = true }
    }
}

private struct ForecastTicket: View {
    let day: WeatherSample.Day
    let index: Int
    let active: Bool
    let entered: Bool
    let animation: Animation?
    private var ink: Color { active ? WeatherPalette.paper : WeatherPalette.ink }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(day.name).font(.system(size: 11, weight: .medium))
                Spacer(minLength: 0)
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 7, design: .monospaced)).opacity(0.5)
            }
            .padding(.top, 11)
            IslandGlyph(symbol: day.symbol, ink: ink)
                .frame(width: 25, height: 25)
                .padding(.top, 7)
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 64, y: 0))
            }
            .stroke(ink.opacity(0.22), style: StrokeStyle(lineWidth: 0.6, dash: [2, 3]))
            .frame(height: 1)
            .padding(.top, 11)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(day.low)°").font(.system(size: 10)).opacity(0.6)
                Text("/ ").font(.system(size: 8)).opacity(0.4)
                Text("\(day.high)°").font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .padding(.top, 7)
            GeometryReader { geometry in
                Capsule().fill(active ? WeatherPalette.lime : WeatherPalette.accent.opacity(0.5))
                    .frame(width: entered ? geometry.size.width * CGFloat(day.high - day.low) / 10 : 0, height: 2)
                    .animation(animation, value: entered)
            }
            .frame(height: 2)
            .padding(.top, 5)
            Spacer(minLength: 0)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 12)
        .frame(width: 88, height: 114)
        .background(TicketShape().fill(active ? WeatherPalette.ink : WeatherPalette.surface))
        .overlay(TicketShape().strokeBorderCompatible(WeatherPalette.line.opacity(active ? 0 : 1)))
        .contentShape(Rectangle())
    }
}

private struct TicketShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, r: CGFloat = 13, n: CGFloat = 5, y = h * 0.55
        var p = Path()
        p.move(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: w-r, y: 0))
        p.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: y-n))
        p.addArc(center: CGPoint(x: w, y: y), radius: n, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: w, y: h-r))
        p.addQuadCurve(to: CGPoint(x: w-r, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: r, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h-r), control: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: y+n))
        p.addArc(center: CGPoint(x: 0, y: y), radius: n, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        p.closeSubpath()
        return p
    }

    func strokeBorderCompatible(_ color: Color) -> some View {
        self.stroke(color, lineWidth: 0.65)
    }
}

/// Deterministic, scalable isometric Shanghai illustration. No image downloads or assets.
enum IslandDrawing {
    static func draw(in c: inout GraphicsContext) {
        let ink = Color(hex: 0x40574C)
        func polygon(_ points: [CGPoint], color: Color) {
            var p = Path()
            p.addLines(points)
            p.closeSubpath()
            c.fill(p, with: .color(color))
        }
        func line(_ points: [CGPoint], color: Color, width: CGFloat = 1) {
            var p = Path(); p.addLines(points)
            c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, color: Color) {
            c.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)), with: .color(color))
        }
        func building(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, color: Color) {
            let d: CGFloat = 7
            polygon([.init(x:x,y:y-h),.init(x:x+w,y:y-h),.init(x:x+w,y:y),.init(x:x,y:y)], color: color)
            polygon([.init(x:x+w,y:y-h),.init(x:x+w+d,y:y-h-4),.init(x:x+w+d,y:y-4),.init(x:x+w,y:y)], color: color.opacity(0.65))
            polygon([.init(x:x,y:y-h),.init(x:x+d,y:y-h-4),.init(x:x+w+d,y:y-h-4),.init(x:x+w,y:y-h)], color: Color(hex: 0xFFFBEA))
            if h > 15 {
                for row in 0..<Int((h-7)/7) {
                    for col in 0..<max(1,Int(w/7)) {
                        c.fill(Path(CGRect(x:x+3+CGFloat(col)*6,y:y-h+5+CGFloat(row)*7,width:2,height:3)), with: .color(ink.opacity(0.3)))
                    }
                }
            }
        }
        // Soft ground shadow and a pale circular sky.
        ellipse(67, 199, 228, 14, color: ink.opacity(0.055))
        var orbit = Path(ellipseIn: CGRect(x: 12, y: 79, width: 336, height: 107))
        orbit = orbit.applying(CGAffineTransform(translationX: -180, y: -132).concatenating(CGAffineTransform(rotationAngle: -.pi / 13)).concatenating(CGAffineTransform(translationX: 180, y: 132)))
        c.stroke(orbit, with: .color(ink.opacity(0.24)), style: StrokeStyle(lineWidth: 0.7, dash: [3,4]))
        // Island sides.
        var side = Path()
        side.move(to: .init(x:40,y:141))
        side.addCurve(to: .init(x:283,y:116), control1: .init(x:69,y:91), control2: .init(x:228,y:86))
        side.addCurve(to: .init(x:315,y:166), control1: .init(x:337,y:128), control2: .init(x:347,y:148))
        side.addCurve(to: .init(x:177,y:211), control1: .init(x:280,y:200), control2: .init(x:231,y:215))
        side.addCurve(to: .init(x:40,y:163), control1: .init(x:107,y:207), control2: .init(x:58,y:186))
        side.closeSubpath()
        c.fill(side, with: .linearGradient(Gradient(colors:[Color(hex:0xB4C6A4),Color(hex:0x809F8F)]), startPoint:.init(x:80,y:145), endPoint:.init(x:260,y:220)))
        // Island top surface.
        var top = Path()
        top.move(to:.init(x:40,y:141))
        top.addCurve(to:.init(x:139,y:106),control1:.init(x:54,y:115),control2:.init(x:107,y:106))
        top.addCurve(to:.init(x:283,y:116),control1:.init(x:180,y:89),control2:.init(x:243,y:100))
        top.addCurve(to:.init(x:310,y:159),control1:.init(x:322,y:127),control2:.init(x:338,y:145))
        top.addCurve(to:.init(x:165,y:184),control1:.init(x:274,y:187),control2:.init(x:213,y:193))
        top.addCurve(to:.init(x:40,y:155),control1:.init(x:109,y:188),control2:.init(x:66,y:171))
        top.closeSubpath()
        c.fill(top, with:.color(Color(hex:0xE0E5B9)))
        c.stroke(top, with:.color(Color(hex:0xF8F9D6)),lineWidth:1.3)
        // The Huangpu river, a cream embankment and tiny wake.
        var river = Path()
        river.move(to:.init(x:282,y:118))
        river.addCurve(to:.init(x:117,y:177),control1:.init(x:232,y:143),control2:.init(x:177,y:136))
        c.stroke(river,with:.color(Color(hex:0xF9F5DF)),style:StrokeStyle(lineWidth:29,lineCap:.butt))
        c.stroke(river,with:.color(Color(hex:0xA2CAC7)),style:StrokeStyle(lineWidth:22,lineCap:.butt))
        line([.init(x:201,y:147),.init(x:187,y:152),.init(x:173,y:158)],color:.white.opacity(0.8),width:1)
        polygon([.init(x:184,y:145),.init(x:192,y:145),.init(x:187,y:150)],color:Color(hex:0xFFF9EB))
        // Back city blocks.
        building(109,130,19,29,color:Color(hex:0xD9B9A7))
        building(134,126,16,39,color:Color(hex:0xC2C6D8))
        building(156,124,15,24,color:Color(hex:0xE7D5A7))
        building(270,139,17,38,color:Color(hex:0xB7C3B6))
        // World Financial Center silhouette.
        polygon([.init(x:205,y:134),.init(x:206,y:64),.init(x:224,y:58),.init(x:227,y:130)],color:Color(hex:0xA8B6CE))
        polygon([.init(x:211,y:68),.init(x:219,y:65),.init(x:220,y:77),.init(x:211,y:78)],color:WeatherPalette.paper)
        line([.init(x:211,y:86),.init(x:212,y:123)],color:.white.opacity(0.6))
        // Shanghai Tower: a tapered, twisting profile.
        var tower = Path()
        tower.move(to:.init(x:237,y:137))
        tower.addLine(to:.init(x:235,y:74))
        tower.addCurve(to:.init(x:251,y:39),control1:.init(x:235,y:58),control2:.init(x:245,y:42))
        tower.addCurve(to:.init(x:256,y:133),control1:.init(x:254,y:72),control2:.init(x:249,y:95))
        tower.closeSubpath()
        c.fill(tower,with:.linearGradient(Gradient(colors:[Color(hex:0xD5D9EA),Color(hex:0x9CAEC2)]),startPoint:.init(x:237,y:85),endPoint:.init(x:256,y:85)))
        line([.init(x:249,y:50),.init(x:244,y:85),.init(x:250,y:128)],color:.white.opacity(0.7),width:1)
        // Oriental Pearl Tower, coral spheres and tripod.
        line([.init(x:171,y:148),.init(x:183,y:92),.init(x:196,y:143)],color:Color(hex:0xB77264),width:4)
        line([.init(x:184,y:23),.init(x:184,y:141)],color:Color(hex:0xB77264),width:3)
        ellipse(173,58,22,22,color:WeatherPalette.accent)
        ellipse(168,104,31,27,color:Color(hex:0xCC7B76))
        ellipse(180,34,8,8,color:WeatherPalette.accent)
        ellipse(176,61,7,5,color:Color(hex:0xFFCEB1).opacity(0.75))
        ellipse(172,107,10,7,color:Color(hex:0xF5B9A0).opacity(0.8))
        line([.init(x:172,y:119),.init(x:194,y:119)],color:ink.opacity(0.3),width:1)
        // Small Bund blocks, terrace and greenery in front.
        building(91,154,17,17,color:Color(hex:0xF2D6AA))
        building(114,161,19,22,color:Color(hex:0xDBBAA0))
        building(139,157,16,16,color:Color(hex:0xEEE1BF))
        building(251,163,18,17,color:Color(hex:0xDAB7A2))
        for point in [CGPoint(x:71,y:142),.init(x:91,y:166),.init(x:220,y:171),.init(x:286,y:149),.init(x:267,y:171)] {
            line([.init(x:point.x,y:point.y),.init(x:point.x,y:point.y-12)],color:ink.opacity(0.6),width:1.5)
            ellipse(point.x-5,point.y-20,10,13,color:Color(hex:0x7F9D71))
            ellipse(point.x-2,point.y-19,6,9,color:Color(hex:0xA1B480))
        }
        line([.init(x:124,y:194),.init(x:125,y:203),.init(x:129,y:207)],color:Color(hex:0x547963),width:1.5)
        line([.init(x:265,y:189),.init(x:264,y:198)],color:Color(hex:0x547963),width:1.5)
        // An orbital marker and a tiny four-point star.
        ellipse(319,117,6,6,color:WeatherPalette.accent)
        line([.init(x:40,y:69),.init(x:48,y:69)],color:ink.opacity(0.5),width:0.8)
        line([.init(x:44,y:65),.init(x:44,y:73)],color:ink.opacity(0.5),width:0.8)
        ellipse(313,59,3,3,color:ink.opacity(0.35))
    }
}

private struct IslandGlyph: View {
    let symbol: String
    let ink: Color
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            ZStack {
                if symbol == "sun.max" {
                    SunOutline().stroke(WeatherPalette.accent,style:StrokeStyle(lineWidth:1.1,lineCap:.round))
                    Circle().fill(WeatherPalette.accent).frame(width:size*0.43,height:size*0.43)
                } else if !["cloud.sun", "cloud", "cloud.drizzle"].contains(symbol) {
                    Image(systemName: symbol)
                        .resizable().scaledToFit()
                        .foregroundStyle(ink, WeatherPalette.accent)
                        .padding(2)
                } else {
                    if symbol == "cloud.sun" {
                        Circle().fill(WeatherPalette.accent).frame(width:size*0.43,height:size*0.43)
                            .offset(x:size*0.19,y:-size*0.23)
                    }
                    CloudOutline().fill(ink.opacity(0.1))
                        .overlay { CloudOutline().stroke(ink,style:StrokeStyle(lineWidth:1.1,lineCap:.round,lineJoin:.round)) }
                        .offset(y:symbol == "cloud.drizzle" ? -2 : 0)
                    if symbol == "cloud.drizzle" {
                        Path { path in
                            for index in 0..<3 {
                                let x = size*(0.28+Double(index)*0.2)
                                path.move(to:.init(x:x,y:size*0.78))
                                path.addLine(to:.init(x:x-2,y:size*0.91))
                            }
                        }.stroke(WeatherPalette.accent,style:StrokeStyle(lineWidth:1.1,lineCap:.round))
                    }
                }
            }
            .frame(width:size,height:geometry.size.height)
        }
    }
}
private struct SunOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)
        path.addEllipse(in: CGRect(x: center.x - radius * 0.235, y: center.y - radius * 0.235, width: radius * 0.47, height: radius * 0.47))
        for index in 0..<8 {
            let angle = Double(index) * .pi / 4
            path.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.37, y: center.y + sin(angle) * radius * 0.37))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.47, y: center.y + sin(angle) * radius * 0.47))
        }
        return path
    }
}

struct CloudOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 64
        let sy = rect.height / 64
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
        var path = Path()
        path.move(to: p(16, 49))
        path.addCurve(to: p(16, 29), control1: p(3, 49), control2: p(3, 30))
        path.addCurve(to: p(42, 28), control1: p(17, 11), control2: p(38, 11))
        path.addCurve(to: p(49, 49), control1: p(59, 23), control2: p(65, 48))
        path.addLine(to: p(16, 49))
        path.closeSubpath()
        return path
    }
}


enum WeatherPalette {
    static let ink = adaptive(0x35483D, dark: 0xE3E8DD)
    static let secondary = adaptive(0x657163, dark: 0xAAB7A8)
    static let accent = adaptive(0xA15342, dark: 0xE3A18D)
    static let lime = adaptive(0xD6DDC8, dark: 0x3D5041)
    static let line = adaptive(0xD9D4C5, dark: 0x425147)
    static let paper = adaptive(0xF3EFE4, dark: 0x18231E)
    static let surface = adaptive(0xFAF7EF, dark: 0x233129)
    static var background: Color { paper }

    private static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        #if os(iOS)
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
        #elseif os(macOS)
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
        #else
        Color(hex: light)
        #endif
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}
#if DEBUG && os(iOS)
struct WeatherHomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WeatherHomeView().previewDisplayName("气象岛 · 交互与入场动画")
            WeatherHomeView(animate: false).previewDisplayName("气象岛 · 现在 / 多云")
            WeatherHomeView(animate: false, initialHour: 3).previewDisplayName("气象岛 · 13时 / 晴")
            WeatherHomeView(animate: false, initialDay: 3).previewDisplayName("气象岛 · 周日 / 小雨")
            WeatherHomeView(initialWeather: .heavyRain).previewDisplayName("气象岛 · 大雨动画")
            WeatherHomeView(initialWeather: .thunderstorm).previewDisplayName("气象岛 · 雷暴动画")
            WeatherHomeView(initialWeather: .hail).previewDisplayName("气象岛 · 冰雹动画")
            WeatherDetailView(report: .demo(.partlyCloudy)).previewDisplayName("天气手记 · 穿衣与紫外线")
        }
        .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
        .preferredColorScheme(.light)
    }
}
#endif

/// Songti for display titles; measurement labels retain the system font for legibility.
enum WeatherTypography {
    static func display(_ size:CGFloat)->Font { .custom("STSongti-SC-Regular",size:size,relativeTo:.title) }
}
