import SwiftUI


struct WeatherBrandMark: View {
    var body: some View {
        Canvas { context,size in
            let scale=min(size.width,size.height)/160
            context.translateBy(x:(size.width-160*scale)/2,y:(size.height-160*scale)/2)
            context.scaleBy(x:scale,y:scale)
            let circle=Path(ellipseIn:CGRect(x:16,y:16,width:128,height:128))
            context.fill(circle,with:.color(Color(hex:0xE8E3D3)))
            context.stroke(circle,with:.color(WeatherPalette.ink.opacity(0.4)),lineWidth:0.8)
            var g=context;g.clip(to:circle)
            var far=Path();far.move(to:CGPoint(x:3,y:104));far.addCurve(to:CGPoint(x:158,y:94),control1:CGPoint(x:68,y:37),control2:CGPoint(x:83,y:116));far.addLine(to:CGPoint(x:158,y:157));far.addLine(to:CGPoint(x:3,y:157));far.closeSubpath()
            g.fill(far,with:.linearGradient(Gradient(colors:[Color(hex:0x91A99A),Color(hex:0xE8E3D3)]),startPoint:CGPoint(x:80,y:63),endPoint:CGPoint(x:80,y:139)))
            var shore=Path();shore.move(to:CGPoint(x:8,y:120));shore.addCurve(to:CGPoint(x:116,y:145),control1:CGPoint(x:34,y:94),control2:CGPoint(x:65,y:112));shore.addLine(to:CGPoint(x:12,y:150));shore.closeSubpath()
            g.fill(shore,with:.color(WeatherPalette.ink.opacity(0.75)))
            for i in 0..<3 {let y=110+Double(i)*8;var p=Path();p.move(to:CGPoint(x:81+Double(i)*5,y:y));p.addQuadCurve(to:CGPoint(x:132,y:y),control:CGPoint(x:109,y:y-1));g.stroke(p,with:.color(WeatherPalette.ink.opacity(0.23)),lineWidth:0.7)}
            g.fill(Path(ellipseIn:CGRect(x:102,y:47,width:14,height:14)),with:.color(WeatherPalette.accent.opacity(0.8)))
        }.environment(\.colorScheme, .light).aspectRatio(1,contentMode:.fit).accessibilityHidden(true)
    }
}

struct WeatherBrandLockup: View {
    var body: some View {
        VStack(spacing: 0) {
            WeatherBrandMark().frame(width: 144, height: 144)
            Text(WL("气象岛"))
                .font(WeatherTypography.display(34))
                .frame(minHeight: 44)
                .padding(.top, 24)
            Text(WL("山水入怀，晴雨有时。"))
                .font(.system(size: 12))
                .foregroundStyle(WeatherPalette.secondary)
                .frame(minHeight: 20)
                .padding(.top, 10)
        }
        .foregroundStyle(WeatherPalette.ink)
        .accessibilityElement(children: .combine)
    }
}

struct WeatherSplashView: View {
    var snapshot = false
    let onEnter: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                WeatherPalette.paper
                WeatherBrandLockup()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Circle().fill(WeatherPalette.accent).frame(width: 4, height: 4)
                        Text(WL("观 天 · 知 时")).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(WeatherLocalization.isChinese ? 4 : 0)
                    }
                    .foregroundStyle(WeatherPalette.secondary)
                    .padding(.top, max(geometry.safeAreaInsets.top, 59) + 32)
                    Spacer()
                    Button(action: onEnter) {
                        HStack(spacing: 12) {
                            Text(WL("进入小岛")).font(.system(size: 14, weight: .medium)).tracking(WeatherLocalization.isChinese ? 2 : 0)
                            Image(systemName: "arrow.right").font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(WeatherPalette.paper)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(WeatherPalette.ink))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(WL("打开真实天气首页"))
                    .padding(.horizontal, 64)
                    Text(WL("一卷山水 · 四时晴雨"))
                        .font(.system(size: 10)).tracking(WeatherLocalization.isChinese ? 2 : 0)
                        .foregroundStyle(WeatherPalette.secondary)
                        .padding(.top, 20)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 34) + 24)
                }
                .opacity(snapshot || appeared ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.45).delay(0.15), value: appeared)
            }
        }
        .ignoresSafeArea()
        .task { appeared = true }
    }
}

struct WeatherRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSplash = true
    @State private var destination: URL?
    @State private var configurationLoaded = false

    var body: some View {
        ZStack {
            Group {
            #if os(iOS)
            if configurationLoaded {
                if let destination {
                    BusinessEntryWebView(url: destination)
                        .ignoresSafeArea(.container, edges: .vertical)
                } else {
                    WeatherTabsView(entryReady: !showingSplash)
                }
            }
            #else
            WeatherHomeView(useLiveData: true, entryReady: !showingSplash)
            #endif
            }
                .opacity(showingSplash ? 0 : 1)
                .allowsHitTesting(!showingSplash)
                .accessibilityHidden(showingSplash)
            if showingSplash {
                WeatherSplashView(onEnter: enterIsland)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .background(WeatherPalette.paper)
        .task {
            async let minimumSplash: Void = Task.sleep(for: .milliseconds(reduceMotion ? 500 : 1500))
            destination = await BusinessEntry.fetchDestination()
            guard !Task.isCancelled else { return }
            configurationLoaded = true
            do { try await minimumSplash }
            catch { return }
            enterIsland()
        }
    }

    private func enterIsland() {
        guard showingSplash, configurationLoaded else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.45)) { showingSplash = false }
    }
}

#if DEBUG && os(iOS)
struct WeatherBranding_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WeatherSplashView(snapshot: true, onEnter: {})
                .previewDisplayName(WL("气象岛 · 启动画面"))
                .previewDevice("iPhone 15 Pro")
            WeatherTabsView(app:WeatherApplication(live:false))
                .previewDisplayName(WL("四 Tab · 离线天气"))
                .previewDevice("iPhone 15 Pro")
            WeatherBrandMark()
                .padding(32)
                .frame(width: 256, height: 256)
                .background(WeatherPalette.paper)
                .previewLayout(.sizeThatFits)
                .previewDisplayName(WL("气象岛 · Logo"))
        }
    }
}
#endif
