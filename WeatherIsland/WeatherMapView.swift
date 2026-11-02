#if os(iOS)
import SwiftUI
import MapKit

struct WeatherMapView: View {
    let app: WeatherApplication
    @State private var store = WeatherMapStore()
    @State private var place: WeatherPlace
    @State private var area: WeatherMapArea
    @State private var selected: CLLocationCoordinate2D
    @State private var viewport: MKCoordinateRegion?
    @State private var layer: WeatherMapLayer = .precipitation
    @State private var hour = 0.0
    @State private var duration = 24
    @State private var playing = false
    @State private var satellite = false
    @State private var picker = false
    @State private var information = false
    @State private var recenter = 0
    @State private var reload = 0
    @State private var appliedReload = 0
    @State private var raster: CGImage?
    @State private var rasterID = UUID()
    @State private var timelineHeight: CGFloat = 150
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(app: WeatherApplication) {
        self.app = app
        _place = State(initialValue: app.selected)
        _area = State(initialValue: .around(latitude: app.selected.latitude, longitude: app.selected.longitude))
        _selected = State(initialValue: .init(latitude: app.selected.latitude, longitude: app.selected.longitude))
        #if DEBUG
        if let flag = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--map-layer=") }),
           let layer = WeatherMapLayer(rawValue: String(flag.dropFirst("--map-layer=".count))) { _layer = State(initialValue: layer) }
        #endif
    }
    private var forecast: WeatherMapForecast? { store.forecast }
    private var index: Int { min(Int(hour), forecast?.lastHour ?? 0) }
    private var limit: Int { min(duration, forecast?.lastHour ?? duration) }
    private var sampledValue: Double? {
        guard let forecast, let position = forecast.area.fractions(latitude: selected.latitude, longitude: selected.longitude) else { return nil }
        return forecast.value(layer: layer, hour: index, x: position.x, y: position.y)
    }
    private var isPlace: Bool { abs(selected.latitude - place.latitude) < 0.005 && abs(selected.longitude - place.longitude) < 0.005 }
    private var selectedTitle: String { isPlace ? place.title : "地图选点" }
    private var valueText: String { sampledValue.map { layer.formatted($0) + (layer == .temperature ? "°" : "") } ?? "—" }
    private var requestKey: String { "\(area)-\(reload)-\(app.tab == .map)" }
    private var imageKey: String { "\(forecast?.fetchedAt.timeIntervalSince1970 ?? 0)-\(area)-\(layer.rawValue)-\(index)" }
    private var shouldPlay: Bool { playing && app.tab == .map && phase == .active && forecast != nil && !store.loading }
    private var selectedTime: String {
        guard let forecast, forecast.times.indices.contains(index) else { return "等待预报" }
        return WeatherClock.string(forecast.times[index], "M月d日 HH:mm", timeZone: place.timeZoneIdentifier)
    }

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height && geometry.size.width >= 600
            if landscape {
                HStack(alignment: .top, spacing: 10) {
                    ScrollView {
                        VStack(spacing: 8) {
                            header
                            selectionCard(compact: true)
                            bottomPanel
                        }.padding(.vertical, 8).padding(.horizontal, 2)
                    }
                    .frame(width: min(300, geometry.size.width * 0.36))
                    mapCanvas()
                        .overlay(alignment: .topTrailing) {
                            rightControls(compact: true).padding(8)
                        }
                }.padding(.horizontal, 12).padding(.bottom, 8)
            } else {
                mapCanvas(bottomInset: timelineHeight + geometry.safeAreaInsets.bottom + 28)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .overlay(alignment: .topLeading) {
                        selectionCard(compact: true)
                            .padding(.leading, 14).padding(.trailing, 84).padding(.top, 8)
                    }
                    .overlay(alignment: .topTrailing) {
                        rightControls(compact: geometry.size.height < 650)
                            .padding(.trailing, 12).padding(.vertical, geometry.size.height < 650 ? 4 : 8)
                    }
                    .safeAreaInset(edge: .top, spacing: 4) {
                        header.padding(.horizontal, 14).padding(.top, 6)
                    }
                    .safeAreaInset(edge: .bottom, spacing: 6) {
                        bottomPanel
                            .background(GeometryReader { proxy in
                                Color.clear.preference(key: MapTimelineHeightKey.self, value: proxy.size.height)
                            })
                            .onPreferenceChange(MapTimelineHeightKey.self) { timelineHeight = $0 }
                            .frame(maxWidth: 600)
                            .padding(.horizontal, 14).padding(.bottom, 12)
                    }
            }
        }
        .foregroundStyle(WeatherPalette.ink)
        .background(WeatherPalette.paper)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $picker) { WeatherMapPlacePicker(places: app.places, selected: place, onSelect: choose) }
        .sheet(isPresented: $information) { sourceSheet }
        .task(id: requestKey) {
            guard app.tab == .map else { return }
            let attempt = reload
            await store.load(area: area, offline: app.offline, force: attempt != appliedReload)
            guard !Task.isCancelled else { return }
            appliedReload = attempt
            hour = min(hour, Double(limit))
        }
        .task(id: imageKey) {
            guard let forecast, forecast.area == area else { raster = nil; rasterID = UUID(); return }
            let currentLayer = layer, currentIndex = index
            let work = Task.detached(priority: .userInitiated) { WeatherMapRaster.image(forecast: forecast, layer: currentLayer, hour: currentIndex) }
            let image = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            guard !Task.isCancelled else { return }
            raster = image; rasterID = UUID()
        }
        .task(id: shouldPlay) {
            guard shouldPlay else { return }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(reduceMotion ? 1.5 : 0.8)) } catch { return }
                guard !Task.isCancelled else { return }
                hour = Int(hour) >= limit ? 0 : hour + 1
            }
        }
        .onChange(of: app.selected.cacheID) { _, _ in choose(app.selected) }
        .onChange(of: app.tab) { _, value in if value != .map { playing = false } }
        .onChange(of: phase) { _, value in if value != .active { playing = false } }
        .onChange(of: duration) { _, _ in playing = false; hour = min(hour, Double(limit)) }
        .onChange(of: area) { _, _ in raster = nil; rasterID = UUID() }
    }

    // Keep the timeline above the system tab bar; float tools over the map's right edge.
    private func mapCanvas(bottomInset: CGFloat = 16) -> some View {
        WeatherMapCanvas(place: place, selected: selected, pinText: valueText, layer: layer, recenter: recenter,
            satellite: satellite, raster: raster, rasterID: rasterID, area: area, bottomInset: bottomInset,
            onRegion: { viewport = $0 }, onSelect: { selected = $0; playing = false })
            .accessibilityLabel("天气地图，可拖动缩放，轻点地图查看该位置预报")
    }

    private func rightControls(compact: Bool) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: compact ? 6 : 10) {
                VStack(spacing: compact ? 0 : 3) {
                    Button(action: loadViewport) {
                        VStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 16))
                            Text("查看\n此区域").font(.system(size: compact ? 9 : 10, weight: .medium))
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        }.frame(width: 46, height: compact ? 44 : 56)
                            .foregroundStyle(movedOutsideCenter ? WeatherPalette.ink : WeatherPalette.secondary)
                    }.accessibilityLabel("查看此区域").disabled(store.loading || viewport == nil)
                    Divider().padding(.horizontal, 8)
                    ForEach(WeatherMapLayer.allCases) { item in
                        Button { layer = item } label: {
                            VStack(spacing: 3) {
                                Image(systemName: item.symbol).font(.system(size: 17))
                                Text(item.title).font(.system(size: 10, weight: .medium))
                            }
                            .frame(width: 46, height: compact ? 44 : 46)
                            .foregroundStyle(layer == item ? WeatherPalette.surface : WeatherPalette.secondary)
                            .background(layer == item ? Color(hex: item.accent) : .clear, in: RoundedRectangle(cornerRadius: 17))
                        }.accessibilityLabel("\(item.title)图层")
                            .accessibilityAddTraits(layer == item ? [.isSelected] : [])
                    }
                }.padding(compact ? 3 : 4).mapGlass(radius: 25)
                VStack(spacing: 0) {
                    mapButton("切换底图", symbol: satellite ? "map.fill" : "square.3.layers.3d") { satellite.toggle() }
                    Divider().padding(.horizontal, 12)
                    mapButton("回到所选城市", symbol: "location.north.line") { choose(place) }
                }.mapGlass(radius: 25)
            }.padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .frame(width: 54)
        .accessibilityIdentifier("地图右侧工具栏")
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("晴雨地图").font(.system(size: 25, weight: .semibold, design: .serif))
                Text("WEATHER ATLAS").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(2.4).foregroundStyle(WeatherPalette.secondary)
            }
            Spacer(minLength: 4)
            Button { picker = true } label: {
                HStack(spacing: 8) { Image(systemName: "magnifyingglass").font(.system(size: 13)); Text(place.city).font(.system(size: 13, weight: .medium)).lineLimit(1); Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)) }
                    .padding(.horizontal, 14).frame(height: 43).mapGlass(radius: 24)
            }.accessibilityLabel("搜索或切换城市，当前\(place.title)")
            Button { information = true } label: { Image(systemName: "info").font(.system(size: 16, weight: .medium)).frame(width: 43, height: 43).mapGlass(radius: 24) }.accessibilityLabel("天气地图数据说明")
        }.padding(.bottom, 3)
    }
    private func selectionCard(compact: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: layer.symbol).font(.system(size: 20)).foregroundStyle(Color(hex: layer.accent)).frame(width: 36, height: 40).background(Color(hex: layer.accent).opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { Text(selectedTitle).font(.system(size: 15, weight: .semibold)).lineLimit(1); Image(systemName: "mappin.circle.fill").font(.system(size: 11)).foregroundStyle(WeatherPalette.secondary) }
                Text(selectionDetail).font(.system(size: 11)).foregroundStyle(WeatherPalette.secondary).lineLimit(2).minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            if store.loading { ProgressView().tint(WeatherPalette.ink).frame(width: 48) }
            else if store.error != nil {
                Button { reload += 1 } label: { Image(systemName: "arrow.clockwise").frame(width: 42, height: 42) }.accessibilityLabel("重试天气图层")
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(valueText).font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Color(hex: layer.accent))
                    Text(layer.unit).font(.system(size: 10)).foregroundStyle(WeatherPalette.secondary)
                }
            }
        }.padding(compact ? 9 : 13).mapGlass(radius: 22)
        .accessibilityElement(children: .contain)
    }
    private var selectionDetail: String {
        if store.loading { return "正在绘制这一片天空…" }
        if let error = store.error { return error }
        guard let value = sampledValue else { return "此处暂无数据 · 移动地图后加载此区域" }
        if layer == .precipitation { return value < 0.1 ? "该小时预计无明显降水" : "该小时累计降水预报" }
        if layer == .temperature { return "近地面气温 · 等温线间隔 5°C" }
        if layer == .wind { return "10 米风速 · 等值线间隔 10 km/h" }
        return "云覆盖比例 · 越浓表示云越多"
    }
    private func mapButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.system(size: 18)).frame(width: 54, height: 44) }.accessibilityLabel(title)
    }
    private var bottomPanel: some View {
        VStack(spacing: 4) {
            VStack(spacing: 3) {
                HStack {
                    Label(layer.title + " · " + layer.unit, systemImage: layer.symbol).font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text(forecast?.isDemo == true ? "示例 · " + layer.scaleDescription : layer.scaleDescription).font(.system(size: 10)).foregroundStyle(WeatherPalette.secondary)
                }
                RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: layer.palette.map { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing)).frame(height: 4)
                HStack {
                    ForEach(Array(layer.ticks.enumerated()), id: \.offset) { offset, tick in
                        if offset > 0 { Spacer(minLength: 0) }
                        Text(tick.formatted(.number.precision(.fractionLength(0...1)))).font(.system(size: 9, design: .monospaced)).foregroundStyle(WeatherPalette.secondary)
                    }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    forecastTime.fixedSize()
                    Spacer(minLength: 8)
                    durationPicker
                }
                VStack(alignment: .leading, spacing: 8) {
                    forecastTime
                    durationPicker
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 9) {
                Button { playing.toggle() } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill").font(.system(size: 15)).frame(width: 32, height: 32).foregroundStyle(WeatherPalette.surface).background(WeatherPalette.ink, in: Circle()).frame(width: 44, height: 44)
                }.accessibilityLabel(playing ? "暂停预报播放" : "播放预报").disabled(forecast == nil || store.loading)
                VStack(spacing: 0) {
                    Slider(value: $hour, in: 0...Double(max(1, limit)), step: 1, onEditingChanged: { if $0 { playing = false } })
                        .tint(WeatherPalette.ink).frame(height: 26).disabled(forecast == nil || store.loading)
                        .accessibilityLabel("预报时间").accessibilityValue(index == 0 ? "当前小时" : "未来\(index)小时")
                    HStack { Text("现在"); Spacer(); Text("+\(limit / 3)h"); Spacer(); Text("+\(limit * 2 / 3)h"); Spacer(); Text("+\(limit)h") }.font(.system(size: 9, design: .monospaced)).foregroundStyle(WeatherPalette.secondary)
                }
            }
            Button { information = true } label: {
                HStack(spacing: 5) { Circle().fill(forecast?.isDemo == true ? WeatherPalette.accent : WeatherPalette.ink.opacity(0.5)).frame(width: 4, height: 4); Text(sourceText).font(.system(size: 9)); Spacer(minLength: 0); Image(systemName: "chevron.right").font(.system(size: 8)) }.foregroundStyle(WeatherPalette.secondary)
            }.accessibilityLabel("数据来源及更新说明，\(sourceText)")
        }.padding(.horizontal, 12).padding(.vertical, 9).mapGlass(radius: 22, translucent: true)
        .accessibilityIdentifier("地图时间轴")
    }
    private var forecastTime: some View {
        Text(selectedTime).font(.system(size: 12, weight: .semibold)).monospacedDigit()
            .accessibilityLabel("\(selectedTime)，\(index == 0 ? "当前小时预报" : "未来 \(index) 小时")")
    }

    private var durationPicker: some View {
        HStack(spacing: 2) {
            ForEach([12, 24, 66], id: \.self) { value in
                Button { duration = value } label: {
                    Text("\(value)h").font(.system(size: 11, weight: .semibold))
                        .frame(width: 35, height: 27)
                        .background(duration == value ? WeatherPalette.ink : .clear, in: Capsule())
                        .foregroundStyle(duration == value ? WeatherPalette.surface : WeatherPalette.secondary)
                }.accessibilityLabel("未来\(value)小时").accessibilityAddTraits(duration == value ? [.isSelected] : [])
            }
        }.padding(3).background(WeatherPalette.paper, in: Capsule())
    }
    private var sourceText: String {
        guard let forecast else { return store.loading ? "Open-Meteo · 正在加载区域预报" : "Open-Meteo · 图层尚未就绪" }
        if forecast.isDemo { return "演示数据 · 仅用于预览效果" }
        return "Open-Meteo · \(WeatherClock.string(forecast.fetchedAt, "HH:mm", timeZone: place.timeZoneIdentifier)) 更新 · 网格插值"
    }
    private var movedOutsideCenter: Bool {
        guard let viewport else { return false }
        return abs(viewport.center.latitude - (area.north + area.south) / 2) > (area.north - area.south) * 0.15 || abs(WeatherMapArea.longitude(viewport.center.longitude - (area.west + area.east) / 2)) > (area.east - area.west) * 0.15 || viewport.span.longitudeDelta > (area.east - area.west) * 1.3
    }
    private func choose(_ next: WeatherPlace) {
        playing = false; place = next
        selected = .init(latitude: next.latitude, longitude: next.longitude)
        area = .around(latitude: next.latitude, longitude: next.longitude)
        hour = 0; recenter += 1; picker = false
    }
    private func loadViewport() {
        guard let viewport else { return }
        playing = false
        selected = viewport.center
        area = .around(latitude: viewport.center.latitude, longitude: viewport.center.longitude, span: max(viewport.span.latitudeDelta, viewport.span.longitudeDelta) * 1.1)
        hour = 0
    }
    private var sourceSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Label("把晴雨，铺在地图上。", systemImage: "map").font(.system(size: 23, weight: .medium, design: .serif))
                    Text("底图由 Apple 地图提供。天气图层使用 Open-Meteo 的区域网格小时预报，在采样点之间平滑插值；颜色表示预报值，并非气象雷达实测。")
                    Text("支持降水、近地面气温、10 米风速和云覆盖比例。降水显示该小时的累计量（mm/h），最长可浏览未来 66 小时；没有分钟级雨停判断。")
                    Text("轻点地图可读取采样区域内的预报；拖动后点「查看此区域」加载新区域。每个区域使用 7 × 7 个采样点，适合查看天气分布趋势，局部细节可能与实际天气不同。")
                    Text("时间按搜索城市的时区显示：\(place.timeZoneIdentifier)。地图选点和移动区域沿用这个时区。缺测区域保持透明，加载失败时可以重试；同一区域的已加载数据保留并展示获取时间。")
                    if forecast?.isDemo == true { Text("当前为离线预览，地图颜色与读数使用明确标注的演示数据。").foregroundStyle(WeatherPalette.accent) }
                }.font(.system(size: 15)).lineSpacing(6).padding(24)
            }.background(WeatherPalette.paper).navigationTitle("关于天气地图").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { information = false } } }
        }.tint(WeatherPalette.ink).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
}

private struct MapTimelineHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 150
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private extension View {
    func mapGlass(radius: CGFloat, translucent: Bool = false) -> some View {
        background(translucent ? .ultraThinMaterial : .regularMaterial, in: RoundedRectangle(cornerRadius: radius))
            .background(WeatherPalette.surface.opacity(translucent ? 0.12 : 0.8), in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(.white.opacity(translucent ? 0.5 : 0.85), lineWidth: 1))
            .shadow(color: WeatherPalette.ink.opacity(0.08), radius: 14, x: 0, y: 5)
    }
}

private struct WeatherMapPlacePicker: View {
    var places: [WeatherPlace]
    var selected: WeatherPlace
    var onSelect: (WeatherPlace) -> Void
    @State private var query = ""
    @State private var search = CitySearchController()
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack { Image(systemName: "magnifyingglass"); TextField("搜索城市或区县", text: $query).autocorrectionDisabled(); if search.loading || search.resolving { ProgressView() } }.padding(.vertical, 7)
                }
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("我的城市") {
                        ForEach(places) { place in
                            Button { onSelect(place); dismiss() } label: {
                                HStack { VStack(alignment: .leading, spacing: 4) { Text(place.title); Text(place.subtitle).font(.caption).foregroundStyle(WeatherPalette.secondary) }; Spacer(); if place.cacheID == selected.cacheID { Image(systemName: "checkmark") } }.padding(.vertical, 5)
                            }
                        }
                    }
                } else {
                    ForEach(search.results, id: \.self) { result in
                        Button { search.choose(result) { place in onSelect(place); dismiss() } } label: {
                            VStack(alignment: .leading, spacing: 5) { Text(result.title); Text(result.subtitle).font(.caption).foregroundStyle(WeatherPalette.secondary) }.padding(.vertical, 5)
                        }.disabled(search.resolving)
                    }
                    if let error = search.error { Text(error).font(.caption) }
                    else if !search.loading && !search.resolving && search.results.isEmpty { Text("没有找到地区，试试城市全名。").font(.caption) }
                }
            }.scrollContentBackground(.hidden).background(WeatherPalette.paper).navigationTitle("寻找一片天空").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.tint(WeatherPalette.ink).onChange(of: query) { _, value in search.update(value) }.onDisappear { search.cancel() }
    }
}

#Preview("晴雨地图 · 离线示例") {
    let app = WeatherApplication(live: false)
    app.tab = .map
    return WeatherTabsView(app: app)
}
#endif
