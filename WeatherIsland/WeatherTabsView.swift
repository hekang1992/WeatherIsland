import SwiftUI
#if os(iOS)
import UIKit

struct WeatherTabsView: View {
    var entryReady = true
    @State private var app: WeatherApplication
    @State private var location = LocationController()
    @State private var locationNaming = WeatherLocationNaming()
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
    private var nameID: String? {
        guard phase == .active, !app.offline, !locationEntry.blocksWeather,
              !location.locating, !app.searchPresented, app.selected.isCurrentLocation,
              !app.selected.hasCityName else { return nil }
        let weatherVersion = selectedWeather.dataset?.fetchedAt.timeIntervalSince1970 ?? 0
        return "\(app.selected.cacheID):\(weatherVersion):\(app.citySelectionRevision)"
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
        } else if app == nil, arguments.contains("--settings-check") {
            let suite = "WeatherIsland.SettingsCheck"
            let defaults = UserDefaults(suiteName: suite)!
            if arguments.contains("--reset-settings-check") { defaults.removePersistentDomain(forName: suite) }
            application = WeatherApplication(defaults: defaults)
            application.select(.shanghai)
            application.tab = .settings
            _startupFinished = State(initialValue: true)
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
                        RegionalWeatherHome(app: app, preview: app.offline, active: app.tab == .weather, entryReady: entryReady, locate: locate, locating: location.locating, resolvingLocation: locationNaming.resolving, waitingLocationName: locationNaming.waiting).id(app.selected.cacheID)
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
        .preferredColorScheme(app.theme.colorScheme)
        .tint(WeatherPalette.ink)
        .onChange(of: selectedWeather.dataset != nil, initial: true) { _, ready in
            if ready && !locationEntry.blocksWeather { startupFinished = true }
        }
        .task(id: loadID) {
            guard loadID != nil else { return }
            await app.loadSelectedWeather()
        }
        .task(id: nameID) {
            guard nameID != nil else { locationNaming.cancel(); return }
            let place = app.selected
            let selectionRevision = app.citySelectionRevision
            await locationNaming.resolve(place, lookup: WeatherLocationLookup.name, sleep: { delay in
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--location-name-recovery-check") {
                    try await Task.sleep(for: .seconds(3)); return
                }
                #endif
                try await Task.sleep(for: delay)
            }) { named in
                guard selectionRevision == app.citySelectionRevision else { return }
                app.resolveLocation(named)
            }
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
                PaperCityScene(style: .automatic(for: place), kind: weather.dataset?.current.kind ?? .partlyCloudy, animate: false).aspectRatio(360.0 / 248, contentMode: .fit).frame(width: 85).clipped()
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
                HStack(spacing: 16) {
                    WeatherBrandMark().frame(width: 66, height: 66)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("气象岛").font(WeatherTypography.display(28))
                        Text("一卷山水，四时晴雨。")
                            .font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                    }
                }.padding(.vertical, 12)
                NavigationLink { SceneGalleryView(app: app) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("宋韵画境").font(WeatherTypography.display(24)); Spacer(); Image(systemName: "arrow.up.right") }
                        Text("十卷山水花鸟 · 五十幅晴雨意境。").font(.subheadline)
                        HStack(spacing: 6) {
                            ForEach([0, 15, 40], id: \.self) { i in
                                PaperCityScene(style: PaperSceneStyle.all[i], animate: false).aspectRatio(360.0 / 248, contentMode: .fit).clipped()
                            }
                        }
                        Text(app.automaticScene ? "当前 · 跟随地区自动匹配" : "当前 · \(app.style.name)")
                            .font(.subheadline.weight(.medium))
                    }.padding(20).background(RoundedRectangle(cornerRadius: 10).fill(WeatherPalette.lime.opacity(0.22)))
                }.buttonStyle(.plain).accessibilityIdentifier("settings.scenes")
                VStack(spacing: 0) {
                    NavigationLink { WeatherThemeView(app: app) } label: {
                        row("界面主题", subtitle: app.theme.title, symbol: "paintpalette")
                    }.accessibilityIdentifier("settings.theme")
                    Divider().overlay(WeatherPalette.line)
                    NavigationLink { WeatherAboutView() } label: {
                        row("关于我们", subtitle: "认识气象岛与数据来源", symbol: "heart")
                    }.accessibilityIdentifier("settings.about")
                    Divider().overlay(WeatherPalette.line)
                    NavigationLink { WeatherSettingsDocumentView(document: .terms) } label: {
                        row("服务协议", subtitle: "服务范围与使用说明", symbol: "doc.text")
                    }.accessibilityIdentifier("settings.terms")
                    Divider().overlay(WeatherPalette.line)
                    NavigationLink { WeatherSettingsDocumentView(document: .privacy) } label: {
                        row("隐私政策", subtitle: "定位、网络与本地数据", symbol: "hand.raised")
                    }.accessibilityIdentifier("settings.privacy")
                }
                .buttonStyle(.plain).padding(.horizontal, 18)
                .background(RoundedRectangle(cornerRadius: 23).fill(WeatherPalette.surface))
                Text("WEATHER ISLAND\n版本 \(WeatherAppInformation.version) · 山水入怀，晴雨有时")
                    .font(.footnote).lineSpacing(8).foregroundStyle(WeatherPalette.secondary)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }.padding(24).weatherReadingWidth()
        }
        .background(WeatherPalette.paper.ignoresSafeArea()).foregroundStyle(WeatherPalette.ink)
        .navigationTitle("设置").islandNavigationStyle()
    }
    private func row(_ name: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.title3).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(.body.weight(.medium))
                Text(subtitle).font(.footnote).foregroundStyle(WeatherPalette.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(WeatherPalette.secondary)
        }
        .padding(.vertical, 20).contentShape(Rectangle())
    }
}

struct WeatherThemeView: View {
    let app: WeatherApplication
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("让晴雨，随心明暗。").font(WeatherTypography.display(28))
                Text("外观应用于天气、地图、我的、设置与详情页。画境保留原作的绢色与淡墨。")
                    .font(.subheadline).foregroundStyle(WeatherPalette.secondary).lineSpacing(5)
                VStack(spacing: 12) {
                    ForEach(WeatherTheme.allCases) { theme in
                        Button { app.setTheme(theme) } label: {
                            VStack(alignment: .leading, spacing: 16) {
                                if dynamicTypeSize.isAccessibilitySize {
                                    HStack { themeIcon(theme); Spacer(); themeSelection(theme) }
                                    themeDescription(theme)
                                } else {
                                    HStack(spacing: 16) {
                                        themeIcon(theme)
                                        themeDescription(theme)
                                        themeSelection(theme)
                                    }
                                }
                            }
                            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 20).fill(WeatherPalette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(app.theme == theme ? WeatherPalette.accent : WeatherPalette.line, lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("settings.theme.\(theme.rawValue)")
                        .accessibilityAddTraits(app.theme == theme ? .isSelected : [])
                        .accessibilityValue(app.theme == theme ? "已选中" : "未选中")
                    }
                }
                Label("选择立即生效，并在下次启动时保留。", systemImage: "checkmark.seal")
                    .font(.footnote).foregroundStyle(WeatherPalette.secondary)
                Text("当前外观：\(app.theme.title)").font(.footnote)
                    .accessibilityIdentifier("settings.theme.current")
                Text("当前显示：\(colorScheme == .dark ? "深色" : "浅色")").font(.footnote)
                    .accessibilityIdentifier("settings.theme.effective")
            }.padding(24).weatherReadingWidth()
        }.weatherSettingsPage("界面主题")
    }
    private func themeIcon(_ theme: WeatherTheme) -> some View {
        Image(systemName: theme.symbol).font(.title2)
            .frame(width: 52, height: 64)
            .background(RoundedRectangle(cornerRadius: 14).fill(WeatherPalette.lime.opacity(0.28)))
            .accessibilityHidden(true)
    }
    private func themeDescription(_ theme: WeatherTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(theme.title).font(.body.weight(.medium))
            Text(theme.detail).font(.footnote).foregroundStyle(WeatherPalette.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
    private func themeSelection(_ theme: WeatherTheme) -> some View {
        Image(systemName: app.theme == theme ? "checkmark.circle.fill" : "circle")
            .font(.title3).foregroundStyle(app.theme == theme ? WeatherPalette.accent : WeatherPalette.secondary)
            .accessibilityHidden(true)
    }

}

private enum WeatherAppInformation {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1" }
}

struct WeatherAboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    WeatherBrandMark().frame(width: 100, height: 100)
                    Text("气象岛").font(WeatherTypography.display(32))
                    Text("山水入怀，晴雨有时。").font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                    Text("版本 \(WeatherAppInformation.version)（\(WeatherAppInformation.build)）")
                        .font(.footnote.monospacedDigit()).textSelection(.enabled)
                        .accessibilityIdentifier("settings.about.version")
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
                settingsTextCard("把天气，读成一卷山水。", text: "气象岛把城市天气、小时趋势、空气质量和晴雨地图收进宋韵画境。你可以关注多座城市，查看未来变化，也可以从十卷意境、五十幅原创画作中选一幅，陪伴日常。")
                settingsTextCard("读懂晴雨地图", text: "地图上的降水、气温、风速和云量来自预报网格，经过插值后显示。它们不是实时雷达或实地观测；请结合所选时间、数据更新时间和当地官方预警判断。天气剧场中的天气为离线演示。")
                VStack(alignment: .leading, spacing: 16) {
                    Text("数据与服务").font(WeatherTypography.display(22))
                    Text("天气由 Open-Meteo 提供；空气质量由 Open-Meteo 空气质量接口提供，包含 CAMS 数据。底图、城市搜索与地名解析使用 Apple 的地图和定位服务。")
                        .font(.subheadline).lineSpacing(5)
                    WeatherServiceLinks(resources: [.weather, .air, .dataTerms, .mapsPrivacy])
                }.settingsCard()
                VStack(alignment: .leading, spacing: 16) {
                    Text("使用与隐私").font(WeatherTypography.display(22))
                    NavigationLink { WeatherSettingsDocumentView(document: .terms) } label: {
                        Label("阅读服务协议", systemImage: "doc.text")
                    }.accessibilityIdentifier("settings.about.terms")
                    NavigationLink { WeatherSettingsDocumentView(document: .privacy) } label: {
                        Label("阅读隐私政策", systemImage: "hand.raised")
                    }.accessibilityIdentifier("settings.about.privacy")
                }.settingsCard()
                Text("原创画境为程序绘制的意境山水，不代表城市实景。")
                    .font(.footnote).foregroundStyle(WeatherPalette.secondary)
            }.padding(24).weatherReadingWidth()
        }.weatherSettingsPage("关于我们")
    }
}

@MainActor private func settingsTextCard(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title).font(WeatherTypography.display(22))
        Text(text).font(.subheadline).lineSpacing(6).fixedSize(horizontal: false, vertical: true)
    }.settingsCard()
}

/// Local documents describe the implemented app; no network is required to read them.
enum WeatherSettingsDocument: String, CaseIterable, Identifiable {
    case terms, privacy
    var id: String { rawValue }
    var title: String { self == .terms ? "服务协议" : "隐私政策" }
    var introduction: String {
        switch self {
        case .terms: "欢迎使用气象岛。以下说明适用于当前版本的天气查询、地图与个性化功能，请在使用前阅读。"
        case .privacy: "这份说明介绍气象岛在何时使用定位、向哪些服务发出请求，以及在设备上保存哪些内容。你可以拒绝定位并手动选择城市。"
        }
    }
    var sections: [(title: String, text: String)] {
        switch self {
        case .terms: [
            ("1. 服务范围", "气象岛提供所选地区的天气预报、小时与多日趋势、空气质量、生活参考和天气地图，并提供城市收藏、画境与外观设置。实际可用的数据以接口返回和页面展示为准。天气剧场及标为演示的页面使用示例数据。"),
            ("2. 天气信息的使用", "天气与空气质量可能因模型更新、地形、观测条件和网络延迟而与实况不同。生活建议仅作日常参考，不作为医疗建议。航行、航空、户外探险及其他涉及人身财产安全的安排，请查询当地气象部门的实况、预警和专业意见。"),
            ("3. 地图与时间", "地图热力层展示预报网格的插值结果，不是实时雷达。请核对图层、预报时点、覆盖范围和更新时间；透明或缺失区域不代表没有降水。城市天气按页面标注的当地时间显示。"),
            ("4. 网络与定位", "获取最新天气、搜索城市与加载地图需要网络。定位需经系统授权，仅用于前台获取当前位置；拒绝定位后可以手动选择城市。首次联网尚未放行或请求失败时，应用会显示等待、重试或缓存状态。离线缓存不等于最新天气。"),
            ("5. 数据来源与作品", "天气和空气质量来自页面标注的第三方服务，相应数据的许可和归属以来源方说明为准。Apple 地图受其服务条款约束。应用内宋韵画境是原创程序绘制作品，不表示对应城市的真实景观。请尊重第三方数据、地图及作品的权利与署名。"),
            ("6. 个人设置与服务变化", "收藏城市、所选地区、画境、主题和天气缓存保存在设备上。更换设备、卸载应用或清除设备数据可能影响这些内容，系统备份是否恢复由设备设置决定。第三方接口维护、网络限制或版本更新可能导致部分信息暂时不可用。"),
            ("7. 说明更新", "功能或数据处理方式发生变化时，本说明会随应用版本更新，并在本页标注更新日期。你可以随时在设置中重新阅读本说明和隐私政策。")
        ]
        case .privacy: [
            ("1. 定位由你决定", "首次进入天气功能时，应用会申请使用期间定位权限，用于获取当前位置的天气和地区名称。你可以拒绝，改为手动选择城市；也可以在系统设置中更改权限。应用没有后台定位功能。使用近似位置时，首页不展示区县名称。"),
            ("2. 天气与空气质量请求", "查询天气时，应用会将所选城市或当前位置的经纬度，以及所需气象字段发送至 Open-Meteo 天气接口；查询空气质量时会将经纬度发送至 Open-Meteo 空气质量接口。使用当前位置时，这些坐标可能来自系统授予的精确位置。请求通过 HTTPS 发出，服务方会接收建立网络连接所需的 IP 地址等信息，并按其自身政策处理。"),
            ("3. 地图、城市搜索与地名解析", "加载底图、搜索城市、将位置转换成地区名称时，会使用 Apple MapKit、城市搜索和地名解析服务。输入的搜索文字、请求位置或浏览区域会按相关服务需要交给 Apple 处理。查看或刷新地图天气区域时，该区域的采样网格坐标会发送至 Open-Meteo，获取对应的气象预报。"),
            ("4. 设备上的数据", "应用在设备偏好与缓存中保存收藏城市、默认城市、最近选择的地区及坐标、画境、主题、手动选城偏好，以及天气和空气质量数据与获取时间。地图预报另有运行期间的内存缓存；系统网络层也可能保留响应缓存。设备备份是否包含本地数据由系统及你的备份设置决定。"),
            ("5. 当前版本的其他数据处理", "当前版本无需注册账号，未接入广告、支付或第三方行为分析 SDK，也不读取通讯录、照片、麦克风或健康数据。应用没有自建的账号同步或位置上传后台；使用天气和地图时向上述服务发出的必要请求仍会包含对应坐标或区域信息。"),
            ("6. 管理你的选择", "你可以在“我的”中管理收藏，手动选择城市以停止使用当前位置，在设置中更改画境与主题。修改系统定位权限不会自动删除已保存的地区或历史缓存；停止使用当前位置后，新的城市天气请求使用手动选择的城市坐标。卸载应用或管理设备与备份可影响本地数据，已交由第三方处理的信息以其政策为准。"),
            ("7. 第三方政策与更新", "你可以通过下方入口查看 Open-Meteo 与 Apple 地图的隐私说明。外部页面由相应服务方维护，并需要网络访问。本说明随应用功能变化更新，更新日期显示在本页顶部；阅读本页本身无需联网。")
        ]
        }
    }
}

struct WeatherSettingsDocumentView: View {
    let document: WeatherSettingsDocument
    @Environment(\.openURL) private var openURL
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(document.title).font(WeatherTypography.display(30))
                Text("更新日期：2026 年 11 月 2 日 · 适用于当前版本")
                    .font(.footnote).foregroundStyle(WeatherPalette.secondary)
                Text(document.introduction).font(.body).lineSpacing(6)
                ForEach(document.sections.indices, id: \.self) { index in
                    let section = document.sections[index]
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title).font(.headline)
                        Text(section.text).font(.body).lineSpacing(7)
                            .fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 16) {
                    Text("相关服务说明").font(.headline)
                    WeatherServiceLinks(resources: document == .privacy ? [.dataPrivacy, .mapsPrivacy] : [.dataTerms, .weather, .air])
                }.settingsCard()
                if document == .privacy {
                    #if os(iOS)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("管理系统权限", systemImage: "gearshape")
                            .font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered).accessibilityIdentifier("settings.privacy.permissions")
                    #endif
                }
                Text("气象岛 · \(document.title)全文完")
                    .font(.footnote).foregroundStyle(WeatherPalette.secondary)
                    .accessibilityIdentifier("settings.\(document.rawValue).end")
            }.padding(24).weatherReadingWidth().textSelection(.enabled)
        }
        .weatherSettingsPage(document.title)
        .accessibilityIdentifier("settings.document.\(document.rawValue)")
    }
}

private enum WeatherServiceResource: String, Identifiable {
    case weather, air, dataTerms, dataPrivacy, mapsPrivacy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .weather: "Open-Meteo · 天气数据"
        case .air: "Open-Meteo / CAMS · 空气质量"
        case .dataTerms: "Open-Meteo · 数据许可与条款"
        case .dataPrivacy: "Open-Meteo · 隐私说明"
        case .mapsPrivacy: "Apple 地图 · 隐私说明"
        }
    }
    var url: URL {
        let address: String
        switch self {
        case .weather: address = "https://open-meteo.com/"
        case .air: address = "https://open-meteo.com/en/docs/air-quality-api"
        case .dataTerms: address = "https://open-meteo.com/en/terms"
        case .dataPrivacy: address = "https://open-meteo.com/en/terms#privacy"
        case .mapsPrivacy: address = "https://www.apple.com/legal/privacy/data/en/apple-maps/"
        }
        return URL(string: address)!
    }
}

private struct WeatherServiceLinks: View {
    let resources: [WeatherServiceResource]
    var body: some View {
        ForEach(resources) { resource in
            Link(destination: resource.url) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(resource.title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").accessibilityHidden(true)
                }.font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityIdentifier("settings.source.\(resource.rawValue)")
        }
    }
}

private extension View {
    func settingsCard() -> some View {
        self.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(RoundedRectangle(cornerRadius: 20).fill(WeatherPalette.surface))
    }
    @ViewBuilder func weatherSettingsPage(_ title: String) -> some View {
        #if os(iOS)
        self.background(WeatherPalette.paper.ignoresSafeArea()).foregroundStyle(WeatherPalette.ink)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(WeatherPalette.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self.background(WeatherPalette.paper.ignoresSafeArea()).foregroundStyle(WeatherPalette.ink).navigationTitle(title)
        #endif
    }
}
