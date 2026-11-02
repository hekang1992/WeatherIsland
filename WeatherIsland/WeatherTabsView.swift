import SwiftUI
#if os(iOS)
import UIKit

struct WeatherTabsView: View {
    var entryReady = true
    @State private var app: WeatherApplication
    @State private var location = LocationController()
    @State private var locationAlert = false
    init(entryReady: Bool = true, app: WeatherApplication? = nil) {
        self.entryReady = entryReady
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let application = app ?? WeatherApplication(live: !arguments.contains("--map-preview"))
        if app == nil && (arguments.contains("--map-preview") || arguments.contains("--map")) { application.tab = .map }
        #else
        let application = app ?? WeatherApplication()
        #endif
        _app = State(initialValue: application)
    }
    var body: some View {
        @Bindable var binding = app
        TabView(selection: $binding.tab) {
            NavigationStack {
                RegionalWeatherHome(app: app, preview: app.offline, active: app.tab == .weather, entryReady: entryReady, locate: locate, locating: location.locating, resolvingLocation: location.resolvingName).id(app.selected.cacheID)
            }.tabItem { Label("天气", systemImage: "cloud.sun") }.tag(WeatherApplication.Tab.weather)
            NavigationStack { WeatherMapView(app: app) }
                .tabItem { Label("地图", systemImage: "map") }.tag(WeatherApplication.Tab.map)
            NavigationStack { SavedCitiesView(app: app, locate: locate, locating: location.locating) }
                .tabItem { Label("我的", systemImage: "square.stack") }.tag(WeatherApplication.Tab.cities)
            NavigationStack { WeatherSettingsView(app: app) }
                .tabItem { Label("设置", systemImage: "slider.horizontal.3") }.tag(WeatherApplication.Tab.settings)
        }.tint(WeatherPalette.ink)
        .sheet(isPresented: $binding.searchPresented) { CitySearchView(app: app, locate: locate, locating: location.locating) }
        .onChange(of: location.error) { _, error in if error != nil { app.searchPresented = false; locationAlert = true } }
        .onChange(of: locationAlert) { _, presented in if !presented { location.clearError() } }
        .alert("没有收到位置信息", isPresented: $locationAlert) {
            Button("搜索城市") { app.searchPresented = true }
            if location.canOpenSettings { Button("前往系统设置") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
            Button("取消", role: .cancel) {}
        } message: { Text(location.error ?? "请稍后重试。") }
    }
    private func locate() { location.onLocated = { place in app.searchPresented = false; app.selectLocation(place) }; location.onResolved = { place in app.resolveLocation(place) }; location.request() }
}

struct SavedCitiesView: View {
    let app: WeatherApplication
    var locate: () -> Void
    var locating: Bool
    @Environment(\.editMode) private var editMode
    var body: some View {
        List {
            Section {
                Button(action: locate) { HStack { Image(systemName: "location"); VStack(alignment: .leading, spacing: 5) { Text(locating ? "正在寻找我的位置…" : "我的位置"); Text("定位到所在行政区 · 不自动加入收藏").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }; Spacer(); if locating { ProgressView() } else { Image(systemName: "arrow.up.right") } }.padding(.vertical, 9) }.listRowBackground(WeatherPalette.surface)
            }
            Section {
                ForEach(app.places) { place in
                    CityWeatherRow(app: app, place: place, active: app.tab == .cities)
                        .listRowBackground(WeatherPalette.surface)
                        .deleteDisabled(app.places.count == 1)
                        .contextMenu { Button("设为默认城市", systemImage: "star") { app.setDefault(place.id) }; if app.places.count > 1 { Button("删除城市", systemImage: "trash", role: .destructive) { app.remove(place.id) } } }
                }.onDelete { indices in let ids = indices.map { app.places[$0].id }; for id in ids { app.remove(id) } }.onMove { app.move(from: $0, to: $1) }
            } header: { Text("我的天气来信 · \(app.places.count)") } footer: { Text("长按卡片可设为默认城市；点编辑可删除或拖动排序。至少保留一座收藏城市。") }
            Button { app.searchPresented = true } label: { Label("添加城市", systemImage: "plus").frame(maxWidth: .infinity).padding(8) }.listRowBackground(WeatherPalette.lime.opacity(0.35))
        }.scrollContentBackground(.hidden).background(WeatherPalette.paper).foregroundStyle(WeatherPalette.ink).navigationTitle("我的小岛").toolbar { EditButton() }
    }
}

private struct CityWeatherRow: View {
    let app: WeatherApplication
    let place: WeatherPlace
    var active: Bool
    @State private var weather: WeatherStore
    init(app: WeatherApplication, place: WeatherPlace, active: Bool) { self.app = app; self.place = place; self.active = active; _weather = State(initialValue: app.weather(for: place)) }
    var body: some View {
        Button { app.select(place) } label: {
            HStack(spacing: 12) {
                PaperCityScene(style: .automatic(for: place), kind: weather.dataset?.current.kind ?? .partlyCloudy, animate: false).frame(width: 85, height: 95).clipped()
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 4) { Text(place.title).font(.system(size: 16, weight: .medium)); if app.collection.defaultID == place.id { Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(WeatherPalette.accent) } }
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let zone = weather.dataset?.timeZoneIdentifier ?? (place.timeZoneIdentifier == "UTC" ? nil : place.timeZoneIdentifier)
                        Text((zone.map { WeatherClock.string(context.date, "HH:mm", timeZone: $0) } ?? "当地时间待更新") + " · " + place.country)
                            .font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                    }
                    if let data = weather.dataset { Text("\(data.current.kind.name) · \(data.current.low)° / \(data.current.high)°").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary); if weather.cached { Text("缓存 · " + WeatherClock.string(data.fetchedAt, "M/d HH:mm", timeZone: data.timeZoneIdentifier)).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) } }
                    else { Text(weather.error == nil ? "正在接收天气…" : "暂无天气，点开重试").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }
                }
                Spacer(minLength: 0)
                if let data = weather.dataset { Text("\(data.current.temperature)°").font(.system(size: 34, weight: .light)) }
            }.padding(.vertical, 7).contentShape(Rectangle())
        }.buttonStyle(.plain).task(id: active) { if active && !app.offline { await weather.refresh() } }
    }
}

struct CitySearchView: View {
    let app: WeatherApplication
    var locate: () -> Void
    var locating: Bool
    @State private var query = ""
    @State private var search = CitySearchController()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Image(systemName: "magnifyingglass"); TextField("搜索城市、区县 · 支持中英文", text: $query).autocorrectionDisabled(); if search.loading || search.resolving { ProgressView() } }.padding(.vertical, 6) }
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: locate) { Label(locating ? "正在定位…" : "使用我的位置", systemImage: "location") }
                    Section("已收藏") { ForEach(app.places) { place in Button { app.select(place); app.searchPresented = false } label: { VStack(alignment: .leading, spacing: 5) { Text(place.title); Text(place.subtitle).font(.caption).foregroundStyle(WeatherPalette.secondary) } } } }
                } else {
                    ForEach(search.results, id: \.self) { result in Button { search.choose(result) { place in app.add(place) } } label: { VStack(alignment: .leading, spacing: 5) { Text(result.title).font(.system(size: 15, weight: .medium)); Text(result.subtitle).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }.padding(.vertical, 5) }.disabled(search.resolving) }
                    if let error = search.error { Text(error).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }
                    if !search.loading && !search.resolving && search.results.isEmpty && search.error == nil { Text("没有找到结果，试试城市全名或加上国家。").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }
                }
            }.scrollContentBackground(.hidden).background(WeatherPalette.paper).navigationTitle("寻找一座小岛").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(WeatherPalette.ink).onChange(of: query) { _, value in search.update(value) }.onDisappear { search.cancel() }
    }
}
#endif

struct WeatherSettingsView: View {
    let app: WeatherApplication
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 16) { WeatherBrandMark().frame(width: 66, height: 66); VStack(alignment: .leading, spacing: 6) { Text("气象岛").font(WeatherTypography.display(28)); Text("一卷山水，四时晴雨。").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) } }.padding(.vertical, 12)
                NavigationLink { SceneGalleryView(app: app) } label: {
                    VStack(alignment: .leading, spacing: 10) { HStack { Text("宋韵画境").font(WeatherTypography.display(24)); Spacer(); Image(systemName: "arrow.up.right") }; Text("十卷山水花鸟 · 五十幅晴雨意境。").font(.system(size: 12)); HStack(spacing: 6) { ForEach([0, 15, 40], id: \.self) { i in PaperCityScene(style: PaperSceneStyle.all[i], animate: false).frame(height: 98).clipped() } }; Text(app.automaticScene ? "当前 · 跟随地区自动匹配" : "当前 · \(app.style.name)").font(.system(size: 12, weight: .medium)) }.padding(20).background(RoundedRectangle(cornerRadius: 10).fill(WeatherPalette.lime.opacity(0.22)))
                }.buttonStyle(.plain)
                VStack(spacing: 0) { placeholder("界面主题", subtitle: "全局主题", symbol: "paintpalette"); Divider(); placeholder("关于我们", subtitle: "岛屿来信", symbol: "heart"); Divider(); placeholder("服务协议", subtitle: "服务说明", symbol: "doc.text"); Divider(); placeholder("隐私政策", subtitle: "隐私说明", symbol: "hand.raised") }.padding(.horizontal, 18).background(RoundedRectangle(cornerRadius: 23).fill(WeatherPalette.surface))
                Text("WEATHER ISLAND\n版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") · 山水入怀，晴雨有时").font(.system(size: 12, design: .monospaced)).lineSpacing(8).foregroundStyle(WeatherPalette.secondary).frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }.padding(24)
        }.background(WeatherPalette.paper).foregroundStyle(WeatherPalette.ink).navigationTitle("设置").islandNavigationStyle()
    }
    private func placeholder(_ name: String, subtitle: String, symbol: String) -> some View { HStack(spacing: 12) { Image(systemName: symbol).frame(width: 24); VStack(alignment: .leading, spacing: 4) { Text(name).font(.system(size: 14, weight: .medium)); Text(subtitle).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }; Spacer(); Text("即将开放").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }.padding(.vertical, 20).accessibilityElement(children: .combine) }
}
