import SwiftUI

struct SceneGalleryView: View {
    let app: WeatherApplication
    @State private var family: PaperSceneStyle.Family?
    private var styles: [PaperSceneStyle] { PaperSceneStyle.all.filter { family == nil || $0.family == family } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("把晴雨，收进山水间。").font(WeatherTypography.display(28))
                Text("宋韵画境 · 十卷意境 · 五十幅原创画作").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                Button { app.apply(nil) } label: {
                    HStack { Image(systemName: "location.circle"); VStack(alignment: .leading, spacing: 5) { Text("跟随地区自动匹配").font(.system(size: 15, weight: .medium)); Text("依地区匹配意境山水，画境不代表当地实景").font(.system(size: 12)) }; Spacer(); if app.automaticScene { Image(systemName: "checkmark.circle.fill") } }.padding(16).background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.lime.opacity(0.4)))
                }.buttonStyle(.plain)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        filter("全部", value: nil)
                        ForEach(PaperSceneStyle.Family.allCases, id: \.self) { filter($0.artDirection, value: $0) }
                    }
                }.scrollIndicators(.hidden)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(styles) { style in
                        NavigationLink { SceneDetailView(app: app, style: style) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                PaperCityScene(style: style, kind: .partlyCloudy, animate: false).aspectRatio(360.0/248,contentMode:.fit).clipped().background(style.tint.opacity(0.16)).clipShape(RoundedRectangle(cornerRadius: 5))
                                HStack { Text(String(format: "%02d", style.number + 1)).font(.system(size: 12, design: .monospaced)).foregroundStyle(WeatherPalette.secondary); Text(style.name).font(WeatherTypography.display(15)); Spacer(minLength: 0); if app.collection.sceneID == style.id { Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(WeatherPalette.accent) } }
                                Text(style.artDirection + " · 原创意境").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                            }.padding(10).background(RoundedRectangle(cornerRadius: 9).fill(WeatherPalette.surface))
                        }.buttonStyle(.plain)
                    }
                }
                Text("画境是宋韵山水与花鸟意境。手动选择会应用到所有地区，真实天气与地区数据保持独立。").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary).lineSpacing(5)
            }.padding(22)
        }.background(WeatherPalette.paper).foregroundStyle(WeatherPalette.ink).navigationTitle("宋韵画境").paperPageNavigation()
    }
    private func filter(_ name: String, value: PaperSceneStyle.Family?) -> some View {
        Button { family = value } label: { Text(name).font(.system(size: 12, weight: .medium)).padding(.horizontal, 14).padding(.vertical, 10).foregroundStyle(family == value ? WeatherPalette.paper : WeatherPalette.ink).background(Capsule().fill(family == value ? WeatherPalette.ink : WeatherPalette.surface)) }.buttonStyle(.plain)
    }
}

struct SceneDetailView: View {
    let app: WeatherApplication
    let style: PaperSceneStyle
    @State private var kind: WeatherKind = .partlyCloudy
    @State private var applied = false
    @Environment(\.scenePhase) private var phase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("宋 韵 画 境 / \(String(format: "%02d", style.number + 1))").font(.system(size: 12, design: .monospaced)).tracking(3).foregroundStyle(WeatherPalette.secondary)
                Text(style.name).font(WeatherTypography.display(34))
                Text(style.artDirection + " / " + style.subtitle).font(.system(size: 13)).foregroundStyle(WeatherPalette.secondary)
                PaperCityScene(style: style, kind: kind, animate: phase == .active && app.tab == .settings).aspectRatio(360.0/248,contentMode:.fit).background(style.tint.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 5))
                HStack { Text(kind.poem).font(WeatherTypography.display(21)); Spacer(); Image(systemName: kind.symbol).foregroundStyle(kind.tint) }
                Text("试试不同的天空").font(.system(size: 13, weight: .medium))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                    ForEach(WeatherKind.allCases) { weather in
                        Button { kind = weather } label: { Label(weather.name, systemImage: weather.symbol).font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 12).fill(kind == weather ? style.tint : WeatherPalette.surface)) }.buttonStyle(.plain)
                    }
                }
                Text("此处晴雨为演示；应用后，画境随所在地区的真实天气流转。").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                Button { app.apply(style); applied = true } label: { Text(app.collection.sceneID == style.id ? "已应用此画境 ✓" : "应用此画境").font(.system(size: 15, weight: .medium)).frame(maxWidth: .infinity).padding(18).foregroundStyle(WeatherPalette.paper).background(Capsule().fill(WeatherPalette.ink)) }.buttonStyle(.plain)
                if applied { Button("去首页看看") { app.tab = .weather }.frame(maxWidth: .infinity) }
                Button("恢复随地区选画") { app.apply(nil); applied = false }.font(.system(size: 12)).frame(maxWidth: .infinity)
            }.padding(24)
        }.background(WeatherPalette.paper).foregroundStyle(WeatherPalette.ink).navigationTitle("画境小赏").paperPageNavigation()
    }
}

#if DEBUG
struct SceneGallery_Previews:PreviewProvider {
    static var previews:some View {
        Group {
            NavigationStack {SceneGalleryView(app:WeatherApplication(live:false))}.previewDisplayName("五十幅宋韵画境 · 离线画廊")
            NavigationStack {WeatherSettingsView(app:WeatherApplication(live:false))}.previewDisplayName("设置 · 场景入口")
        }.preferredColorScheme(.light)
    }
}
#endif

extension View {
    @ViewBuilder func paperPageNavigation() -> some View {
        #if os(iOS)
        self.toolbar(.visible,for:.navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbarBackground(WeatherPalette.paper,for:.navigationBar)
            .toolbarBackground(.visible,for:.navigationBar)
        #else
        self
        #endif
    }
}
