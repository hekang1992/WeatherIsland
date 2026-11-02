import SwiftUI

/// Weather motion is confined to the illustration, with a deterministic still frame for Preview exports.
struct IslandScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var epoch = Date()
    let kind: WeatherKind
    var animate = true
    var rotation: Double = 0
    var cloudOffset: CGFloat = 0
    var frozenTime: Double = 2.8

    private var moves: Bool { animate && !reduceMotion && scenePhase == .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moves)) { timeline in
            let time = moves ? max(0, timeline.date.timeIntervalSince(epoch)) : frozenTime
            GeometryReader { geometry in
                let sx = geometry.size.width / 360
                let sy = geometry.size.height / 230
                ZStack(alignment: .topLeading) {
                    Ellipse().fill(skyColor)
                        .frame(width: 189 * sx, height: 177 * sy)
                        .position(x: 188.5 * sx, y: 103.5 * sy)
                    if kind.showsSun {
                        ZStack {
                            Circle().fill(WeatherPalette.accent).frame(width: 44, height: 44)
                            Circle().stroke(WeatherPalette.accent.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [1.5, 6]))
                                .frame(width: 62, height: 62)
                                .rotationEffect(.degrees(rotation + (moves ? time * 6 : 0)))
                            if kind == .clear {
                                Circle().stroke(WeatherPalette.accent.opacity(0.13), lineWidth: 6)
                                    .frame(width: 75 + sin(time * 0.9) * 3, height: 75 + sin(time * 0.9) * 3)
                            }
                        }
                        .scaleEffect(min(sx, sy))
                        .position(x: 285 * sx, y: 48 * sy)
                    }
                    if !kind.showsSun || kind == .partlyCloudy || kind == .windy {
                        if kind != .partlyCloudy && kind != .windy {
                            cloud(width: 128, height: 88, shade: cloudColor.opacity(0.7))
                                .scaleEffect(min(sx, sy))
                                .position(x: (259 + sin(time * 0.34) * 4) * sx, y: 58 * sy)
                        }
                    }
                    Canvas { context, size in
                        context.scaleBy(x: size.width / 360, y: size.height / 230)
                        IslandDrawing.draw(in: &context)
                    }
                    .saturation(kind.severe || kind == .overcast ? 0.65 : 1)
                    if kind != .clear {
                        cloud(width: kind == .partlyCloudy ? 97 : 126, height: 80, shade: cloudColor)
                            .scaleEffect(min(sx, sy))
                            .rotationEffect(.degrees(-6))
                            .position(x: (85 + (kind == .windy ? sin(time * 0.65) * 13 : 0)) * sx,
                                      y: (69 + (moves ? cloudOffset + sin(time * 0.9) * 2 : 0)) * sy)
                    }
                    Canvas { context, size in
                        context.scaleBy(x: size.width / 360, y: size.height / 230)
                        WeatherParticles.draw(kind: kind, time: time, context: &context)
                    }
                    Text("SHANGHAI ISLAND")
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(WeatherPalette.secondary)
                        .rotationEffect(.degrees(-12))
                        .position(x: 70 * sx, y: 193 * sy)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cloud(width: CGFloat, height: CGFloat, shade: Color) -> some View {
        CloudOutline().fill(shade)
            .overlay { CloudOutline().stroke(WeatherPalette.ink.opacity(kind.severe ? 0.25 : 0.55), lineWidth: 1) }
            .frame(width: width, height: height)
    }
    private var skyColor: Color {
        switch kind {
        case .clear: Color(hex: 0xF1DFC3).opacity(0.5)
        case .thunderstorm: Color(hex: 0xB8B4CC).opacity(0.6)
        case .heavyRain, .hail: Color(hex: 0xBECAD1).opacity(0.55)
        case .snow, .fog: Color(hex: 0xDCE6E3).opacity(0.65)
        default: Color(hex: 0xDCDDF0).opacity(0.36)
        }
    }
    private var cloudColor: Color {
        switch kind {
        case .thunderstorm: Color(hex: 0x74768D)
        case .heavyRain: Color(hex: 0x96A6B7)
        case .moderateRain, .hail: Color(hex: 0xADBDCB)
        case .overcast, .fog: Color(hex: 0xC6CEC8)
        case .lightRain: Color(hex: 0xB8C5D1)
        default: Color(hex: 0xFFFFF8)
        }
    }
}

/// Pure drawing function: repeatable particle paths, no random state or network assets.
enum WeatherParticles {
    static func draw(kind: WeatherKind, time: Double, context base: inout GraphicsContext, onDark: Bool = false, subtle: Bool = false) {
        var c = base
        if subtle { c.opacity *= 0.42 }
        let rain = [WeatherKind.lightRain, .moderateRain, .heavyRain, .thunderstorm].contains(kind)
        for i in 0..<kind.particleCount {
            let seed = Double((i * 73 + 29) % 997) / 997
            let speed: Double = kind == .heavyRain || kind == .thunderstorm ? 1.1 : kind == .lightRain ? 0.48 : 0.72
            let phase = (time * (kind == .snow ? 0.13 : speed) + Double(i) * 0.173).truncatingRemainder(dividingBy: 1)
            let baseX = 45 + seed * 275
            if rain {
                let slant: Double = kind == .heavyRain || kind == .thunderstorm ? 9 : 3
                let length: Double = kind == .heavyRain || kind == .thunderstorm ? 13 : kind == .moderateRain ? 9 : 5
                let x = baseX - phase * slant * 2
                let y = 67 + phase * 112
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - slant * 0.45, y: y + length))
                c.stroke(p, with: .color((onDark ? Color(hex: 0xC5E8FF) : Color(hex: 0x527796)).opacity(0.4 + seed * 0.4)), style: StrokeStyle(lineWidth: kind == .lightRain ? 1 : 1.4, lineCap: .round))
                if phase > 0.87 {
                    let progress = (phase - 0.87) / 0.13
                    let r = 1 + progress * 4
                    c.stroke(Path(ellipseIn: CGRect(x: x-r, y: 180, width: r*2, height: r*0.6)), with: .color(kind.tint.opacity((1-progress)*0.5)), lineWidth: 0.6)
                }
            } else if kind == .hail {
                let fall = min(phase / 0.72, 1)
                let bounce = phase > 0.72 ? sin((phase - 0.72) / 0.28 * .pi) * (8 + seed * 9) : 0
                let x = baseX + phase * 5
                let y = 64 + fall * 112 - bounce
                let radius = 1.5 + seed * 1.6
                let circle = Path(ellipseIn: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2))
                c.fill(circle, with: .color(Color(hex: 0xE9F6FB)))
                c.stroke(circle, with: .color(Color(hex: 0x7695AC)), lineWidth: 0.7)
            } else if kind == .snow {
                let x = baseX + sin(time * 0.55 + Double(i)) * 12
                let y = 48 + phase * 137
                let r = 1.5 + seed * 1.5
                var p = Path()
                for arm in 0..<3 {
                    let a = Double(arm) * .pi / 3 + time * 0.15
                    p.move(to: CGPoint(x: x-cos(a)*r, y: y-sin(a)*r))
                    p.addLine(to: CGPoint(x: x+cos(a)*r, y: y+sin(a)*r))
                }
                c.stroke(p, with: .color(onDark ? Color(hex: 0xFFFFFF) : Color(hex: 0x7197B3)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        if kind == .thunderstorm {
            // One slow glow every six seconds. No full-screen flashes or strobing.
            let pulse = pow(max(0, sin(time.truncatingRemainder(dividingBy: 6) / 6 * .pi)), 8)
            var bolt = Path()
            bolt.addLines([.init(x:260,y:61), .init(x:243,y:90), .init(x:256,y:88), .init(x:246,y:112), .init(x:275,y:78), .init(x:260,y:80)])
            bolt.closeSubpath()
            c.fill(bolt, with: .color((subtle ? Color(hex: 0x7A8576) : Color(hex: 0xF4C96D)).opacity(0.25 + pulse * 0.75)))
            c.stroke(bolt, with: .color(Color(hex: 0xFFF7CE).opacity(pulse)), lineWidth: 1)
        }
        if kind == .fog {
            for i in 0..<4 {
                let drift = sin(time * 0.35 + Double(i)) * 14
                let y = Double(118 + i * 19)
                let rect = CGRect(x: 33 + drift + Double(i % 2) * 21, y: y, width: Double(275 - i * 22), height: 11)
                c.fill(Path(roundedRect: rect, cornerRadius: 6), with: .linearGradient(Gradient(colors: [.white.opacity(0), Color(hex: 0xEBF0E8).opacity(0.8), .white.opacity(0)]), startPoint: rect.origin, endPoint: .init(x:rect.maxX, y:y)))
            }
        }
        if kind == .windy {
            for i in 0..<4 {
                let phase = (time * 0.3 + Double(i) * 0.23).truncatingRemainder(dividingBy: 1)
                let x = -30 + phase * 385
                let y = Double(81 + i * 27)
                var p = Path()
                p.move(to: .init(x:x-36,y:y))
                p.addQuadCurve(to: .init(x:x+24,y:y-8), control: .init(x:x,y:y+4))
                c.stroke(p, with: .color((onDark ? Color(hex: 0xE3F1F4) : WeatherPalette.ink).opacity(sin(phase * .pi)*0.5)), style: StrokeStyle(lineWidth:1.2,lineCap:.round))
                let leaf = CGRect(x: x+8, y: y+sin(time*2+Double(i))*6, width: 6, height: 2.7)
                c.fill(Path(ellipseIn:leaf), with: .color(WeatherPalette.accent.opacity(0.7)))
            }
        }
    }
}

#if DEBUG && os(iOS)
struct WeatherEffects_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WeatherHomeView(initialWeather: .overcast).previewDisplayName("天空 · 阴天")
            WeatherHomeView(initialWeather: .moderateRain).previewDisplayName("天空 · 中雨")
            WeatherHomeView(initialWeather: .snow).previewDisplayName("天空 · 飘雪")
            WeatherHomeView(initialWeather: .fog).previewDisplayName("天空 · 雾天")
            WeatherHomeView(initialWeather: .windy).previewDisplayName("天空 · 大风")
            WeatherDetailView(report: .demo(.thunderstorm)).previewDisplayName("天气手记 · 雷暴出行")
            WeatherDetailView(report: .demo(.clear)).previewDisplayName("天气手记 · 晴天遮阳")
            WeatherHomeView(animate: false, initialWeather: .hail)
                .previewDisplayName("冰雹 · 静态天空")
        }
        .previewDevice("iPhone 15 Pro")
    }
}
#endif
