import SwiftUI
#if os(iOS)
import UIKit

struct WeatherTabsView: View {
    var entryReady = true
    @State private var app: WeatherApplication
    @State private var location = LocationController()
    @State private var locationAlert = false
    @State private var startupFinished = false
    @State private var retryID = 0
    @State private var locationEntry = WeatherLocationEntry()
    @State private var pendingLocationAlert = false
    @State private var returningFromLocationSettings = false
    @Environment(\.scenePhase) private var phase
    private var selectedWeather: WeatherStore { app.weather(for: app.selected) }
    private var waitingForFirstWeather: Bool {
        !app.offline && !locationEntry.blocksWeather && !startupFinished && app.tab == .weather && selectedWeather.dataset == nil
    }
    private var loadID: String? {
        guard phase == .active, !app.offline, !locationEntry.blocksWeather else { return nil }
        return "\(app.selected.cacheID):\(retryID)"
    }
    init(entryReady: Bool = true, app: WeatherApplication? = nil) {
        self.entryReady = entryReady
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let application: WeatherApplication
        if app == nil, arguments.contains("--startup-connection-check") {
            let source = StartupConnectionCheck()
            let defaults = UserDefaults(suiteName: "WeatherIsland.StartupCheck." + UUID().uuidString)!
            application = WeatherApplication(defaults: defaults,
                weatherLoader: { place in try await source.fetch(place) })
            application.select(.shanghai) // This check isolates networking from location onboarding.
        } else if app == nil, arguments.contains("--location-startup-check") {
            let suite = "WeatherIsland.LocationCheck"
            let defaults = UserDefaults(suiteName: suite)!
            if arguments.contains("--reset-city-choice") { defaults.removePersistentDomain(forName: suite) }
            application = WeatherApplication(defaults: defaults)
        } else {
            application = app ?? WeatherApplication(live: !arguments.contains("--map-preview") && !arguments.contains("--home-layout-check"))
        }
        if app == nil && (arguments.contains("--map-preview") || arguments.contains("--map")) { application.tab = .map }
        #else
        let application = app ?? WeatherApplication()
        #endif
        _app = State(initialValue: application)
    }
    var body: some View {
        @Bindable var binding = app
        ZStack {
            if !app.offline && locationEntry.blocksWeather {
                WeatherLocationEntryView(choosingCity: locationEntry.phase == .needsCity,
                                         locate: locate, chooseCity: showCitySelection)
            } else if waitingForFirstWeather {
                WeatherStartupView(weather: selectedWeather, retry: { retryID += 1 },
                                   enter: { startupFinished = true })
            } else {
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
                }
            }
        }
        .tint(WeatherPalette.ink)
        .onChange(of: selectedWeather.dataset != nil, initial: true) { _, ready in
            if ready && !locationEntry.blocksWeather { startupFinished = true }
        }
        .task(id: loadID) {
            guard loadID != nil else { return }
            await app.loadSelectedWeather()
        }
        .onChange(of: entryReady, initial: true) { _, _ in startLocationIfNeeded() }
        .onChange(of: phase, initial: true) { _, value in
            if value == .active {
                if returningFromLocationSettings {
                    returningFromLocationSettings = false
                    location.refreshAuthorization()
                    if location.authorized { locate() }
                }
                startLocationIfNeeded()
            } else if value == .background, location.locating {
                location.cancel(); locationEntry.backgrounded()
            }
        }
        .onChange(of: location.authorization) { _, _ in
            if returningFromLocationSettings, phase == .active, location.authorized {
                returningFromLocationSettings = false; locate()
            }
        }
        .onChange(of: app.citySelectionRevision) { _, _ in
            location.cancel(); returningFromLocationSettings = false
            pendingLocationAlert = false; locationAlert = false
            locationEntry.choseCity()
        }
        .onChange(of: app.searchPresented) { _, shown in
            if shown {
                location.cancel(); locationEntry.failed()
                returningFromLocationSettings = false
            }
        }
        .sheet(isPresented: $binding.searchPresented, onDismiss: {
            if pendingLocationAlert { pendingLocationAlert = false; locationAlert = true }
        }) {
            CitySearchView(app: app, locate: locate, locating: location.locating,
                           requiresSelection: locationEntry.blocksWeather)
        }
        .onChange(of: location.error) { _, error in
            guard error != nil else { return }
            locationEntry.failed()
            if app.searchPresented {
                pendingLocationAlert = true; app.searchPresented = false
            } else { locationAlert = true }
        }
        .onChange(of: locationAlert) { _, shown in if !shown { location.clearError() } }
        .alert(locationEntry.blocksWeather ? "请选择天气城市" : "暂时无法定位", isPresented: $locationAlert) {
            Button("手动选择城市", action: showCitySelection)
            if location.canOpenSettings {
                Button("前往系统设置") {
                    returningFromLocationSettings = true
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            if !locationEntry.blocksWeather { Button("保留当前城市", role: .cancel) {} }
        } message: { Text(location.error ?? "请选择一座城市，查看当地天气。") }
    }
    private func startLocationIfNeeded() {
        guard entryReady, phase == .active else { return }
        if app.offline || app.tab != .weather { locationEntry.choseCity(); return }
        if locationEntry.begin(usesManualCity: app.usesManualCity) { locate() }
    }
    private func showCitySelection() {
        location.cancel(); locationEntry.failed()
        app.searchPresented = true
    }
    private func locate() {
        guard !app.offline else { return }
        locationEntry.retry()
        let selectionRevision = app.citySelectionRevision
        location.onLocated = { place in
            guard selectionRevision == app.citySelectionRevision else { return }
            locationEntry.located(); app.searchPresented = false; app.selectLocation(place)
        }
        location.onResolved = { place in
            guard selectionRevision == app.citySelectionRevision else { return }
            app.resolveLocation(place)
        }
        location.request()
    }
}


#if DEBUG
/// Reproduce the first-launch permission delay on a simulator without changing
/// system networking. Real weather is fetched only after two simulated failures.
private actor StartupConnectionCheck {
    private var attempts = 0
    func fetch(_ place: WeatherPlace) async throws -> Data {
        attempts += 1
        try await Task.sleep(for: .seconds(5))
        if attempts <= 2 { throw URLError(.dataNotAllowed) }
        return try await WeatherService.fetch(place: place)
    }
}
#endif

/// Location and city choice are resolved before starting the first weather request.
private struct WeatherLocationEntryView: View {
    var choosingCity: Bool
    var locate: () -> Void
    var chooseCity: () -> Void
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WeatherBrandMark().frame(width: 112, height: 112)
                Text(choosingCity ? "选择一座天气小岛" : "正在寻找你的小岛")
                    .font(WeatherTypography.display(27))
                if !choosingCity { ProgressView().tint(WeatherPalette.ink) }
                Text(choosingCity ? "手动选择城市，也能收到当地的天气来信。" : "请允许使用期间访问位置，获取附近的天气。\n也可以手动选择城市。")
                    .font(.system(size: 14)).lineSpacing(6).foregroundStyle(WeatherPalette.secondary)
                Button("手动选择城市", action: chooseCity).buttonStyle(.borderedProminent)
                    .tint(WeatherPalette.ink).foregroundStyle(WeatherPalette.paper)
                if choosingCity { Button("重新定位", action: locate).buttonStyle(.bordered) }
            }
            .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.vertical, 56)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WeatherPalette.paper.ignoresSafeArea()).foregroundStyle(WeatherPalette.ink)
    }
}

/// The first weather response gates entry; cached launches skip this screen.
private struct WeatherStartupView: View {
    let weather: WeatherStore
    let retry: () -> Void
    let enter: () -> Void
    @State private var showHelp = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                WeatherBrandMark().frame(width: 112, height: 112)
                Text(weather.error == nil ? "正在接通天空" : "等待天气来信")
                    .font(WeatherTypography.display(27))
                if weather.loading || weather.connectionFailed || weather.error == nil {
                    ProgressView().tint(WeatherPalette.ink)
                }
                Text(message)
                    .font(.system(size: 14)).lineSpacing(6)
                    .foregroundStyle(WeatherPalette.secondary)
                if showHelp || weather.error != nil {
                    VStack(spacing: 16) {
                        Button(action: retry) {
                            Text("重新连接").foregroundStyle(WeatherPalette.paper)
                        }.buttonStyle(.borderedProminent)
                        Button("检查网络设置") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }.buttonStyle(.bordered)
                        Button("稍后进入", action: enter).buttonStyle(.plain)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36).padding(.vertical, 56)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WeatherPalette.paper.ignoresSafeArea())
        .foregroundStyle(WeatherPalette.ink)
        .onChange(of: weather.error, initial: true) { _, error in
            if error != nil { showHelp = true }
        }
        .task {
            do { try await Task.sleep(for: .seconds(12)) } catch { return }
            showHelp = true
        }
    }
    private var message: String {
        if weather.connectionFailed || showHelp && weather.error == nil {
            return "还没有连接到天气服务。请检查网络，并允许气象岛使用无线局域网或蜂窝网络。连接恢复后会自动加载。"
        }
        if let error = weather.error { return error }
        return "首次使用时，请在系统弹窗中允许联网。\n收到天气后，将自动进入小岛。"
    }
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
    var requiresSelection = false
    @State private var query = ""
    @State private var search = CitySearchController()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section { HStack { Image(systemName: "magnifyingglass"); TextField("搜索城市、区县 · 支持中英文", text: $query).autocorrectionDisabled(); if search.loading || search.resolving { ProgressView() } }.padding(.vertical, 6) }
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: locate) { Label(locating ? "正在定位…" : "使用我的位置", systemImage: "location") }
                    if requiresSelection {
                        Text("选择天气城市后进入首页；无需开启定位。")
                            .font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                        Section("常用城市") {
                            ForEach([WeatherPlace.beijing, .tokyo, .london, .newYork]) { place in
                                Button(place.title) { app.add(place) }
                            }
                        }
                    }
                    Section("已收藏") { ForEach(app.places) { place in Button { app.select(place); app.searchPresented = false } label: { VStack(alignment: .leading, spacing: 5) { Text(place.title); Text(place.subtitle).font(.caption).foregroundStyle(WeatherPalette.secondary) } } } }
                } else {
                    ForEach(search.results, id: \.self) { result in Button { search.choose(result) { place in app.add(place) } } label: { VStack(alignment: .leading, spacing: 5) { Text(result.title).font(.system(size: 15, weight: .medium)); Text(result.subtitle).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }.padding(.vertical, 5) }.disabled(search.resolving) }
                    if let error = search.error { Text(error).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }
                    if !search.loading && !search.resolving && search.results.isEmpty && search.error == nil { Text("没有找到结果，试试城市全名或加上国家。").font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary) }
                }
            }.scrollContentBackground(.hidden).background(WeatherPalette.paper).navigationTitle("寻找一座小岛").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { if !requiresSelection { Button("完成") { dismiss() } } } }
        }.tint(WeatherPalette.ink).interactiveDismissDisabled(requiresSelection).onChange(of: query) { _, value in search.update(value) }.onDisappear { search.cancel() }
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
