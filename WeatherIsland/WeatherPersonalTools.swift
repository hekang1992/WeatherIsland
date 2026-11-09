import SwiftUI

#if os(iOS)
/// Personal travel tools share the city's existing stores without selecting a weather region.
struct MyCityComparisonSheet: View {
    let app: WeatherApplication
    let addCity: () -> Void
    @State private var firstID: String
    @State private var secondID: String
    @State private var reload = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    init(app: WeatherApplication, addCity: @escaping () -> Void) {
        self.app = app; self.addCity = addCity
        let first = app.places.first(where: { $0.id == app.selected.id }) ?? app.places[0]
        _firstID = State(initialValue: first.id)
        _secondID = State(initialValue: app.places.first(where: { $0.id != first.id })?.id ?? "")
    }
    private var first: WeatherPlace { app.places.first { $0.id == firstID } ?? app.places[0] }
    private var second: WeatherPlace? { app.places.first { $0.id == secondID && $0.id != first.id } }
    private func dataset(_ place: WeatherPlace) -> WeatherDataset? {
        app.offline ? RegionalPreview.dataset(place: place) : app.weather(for: place).dataset
    }
    private var updating: Bool {
        app.weather(for: first).loading || (second.map { app.weather(for: $0).loading } ?? false)
    }

    var body: some View {
        MyTravelSheet(title: "双城天气对比", initiallyExpanded: true) {
            VStack(alignment: .leading, spacing: 20) {
                Text("下一程，穿得刚刚好。口袋里的两座城市，一起看看。")
                    .font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                if let second {
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 16) {
                        comparisonColumn(place: first, selection: $firstID, excluding: second.id, label: "城市一", identifier: "my.compare.first")
                        comparisonColumn(place: second, selection: $secondID, excluding: first.id, label: "城市二", identifier: "my.compare.second")
                    }
                    if let a = dataset(first), let b = dataset(second) {
                        let difference = abs(a.current.temperature - b.current.temperature)
                        VStack(alignment: .leading, spacing: 8) {
                            Label(difference == 0 ? "两地记录气温相同" : "两地记录温差 \(difference)°", systemImage: "thermometer.medium")
                                .font(.headline)
                            Text("\(first.title)：\(a.current.outfitTitle)\n\(second.title)：\(b.current.outfitTitle)")
                                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                            .background(WeatherPalette.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 18))
                        Text(app.offline ? "离线示例，仅供体验。" : "按两地各自的观测记录比较，请留意更新时间；跨时区城市的当地日期可能不同。")
                            .font(.caption).foregroundStyle(WeatherPalette.secondary)
                    } else {
                        Text("两地天气齐备后，会显示记录温差与衣物建议。暂无数据的城市可以重试更新。")
                            .font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                            .accessibilityIdentifier("my.compare.unavailable")
                    }
                    if !app.offline {
                        Button { reload += 1 } label: {
                            Label(updating ? "正在更新…" : "更新两地天气", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }.buttonStyle(.bordered).tint(WeatherPalette.accent).disabled(updating)
                            .accessibilityIdentifier("my.compare.refresh")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("再收藏一座城市", systemImage: "mappin.and.ellipse").font(.headline)
                        Text("已有 \(first.title)。添加目的地后，就能比较两地天气；添加时会保留正在查看的地区。")
                            .font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                        Button("添加城市", systemImage: "plus") { addCity(); dismiss() }
                            .buttonStyle(.borderedProminent).tint(WeatherPalette.accent)
                            .accessibilityIdentifier("my.compare.add")
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(WeatherPalette.surface, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    private func comparisonColumn(place: WeatherPlace, selection: Binding<String>, excluding: String, label: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label).font(.caption).foregroundStyle(WeatherPalette.secondary)
            Picker(label, selection: selection) {
                ForEach(app.places.filter { $0.id != excluding }) { city in
                    Text(city.title).tag(city.id)
                }
            }.pickerStyle(.menu).tint(WeatherPalette.accent).labelsHidden()
                .accessibilityLabel(label).accessibilityIdentifier(identifier)
            MyComparisonWeatherCard(app: app, place: place, reload: reload).id(place.id)
        }.frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct MyComparisonWeatherCard: View {
    let app: WeatherApplication
    let place: WeatherPlace
    let reload: Int
    @State private var weather: WeatherStore
    init(app: WeatherApplication, place: WeatherPlace, reload: Int) {
        self.app = app; self.place = place; self.reload = reload
        _weather = State(initialValue: app.weather(for: place))
    }
    private var data: WeatherDataset? { app.offline ? RegionalPreview.dataset(place: place) : weather.dataset }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let data {
                Image(systemName: data.current.kind.symbol).font(.title2).foregroundStyle(WeatherPalette.accent).accessibilityHidden(true)
                Text("\(data.current.temperature)°").font(WeatherTypography.display(38))
                Text(data.current.kind.name).font(.headline)
                Text("体感 \(data.current.feelsLike)°\n最低 \(data.current.low)° / 最高 \(data.current.high)°")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                Divider()
                Text(app.offline ? "离线示例" : (weather.cached || weather.error != nil ? "上次天气" : "最近更新"))
                    .font(.caption.weight(.medium))
                Text(WeatherClock.string(data.fetchedAt, "M/d HH:mm", timeZone: data.timeZoneIdentifier))
                    .font(.caption.monospacedDigit())
                if weather.error != nil && !app.offline {
                    Text("更新失败，保留记录").font(.caption).foregroundStyle(WeatherPalette.secondary)
                }
            } else {
                Image(systemName: "cloud").font(.title2).accessibilityHidden(true)
                Text(weather.loading ? "更新中…" : "暂无天气").font(.headline)
                Text(weather.loading ? "正在获取这座城市的天气。" : "未取得天气记录，请稍后重试。")
                    .font(.caption).foregroundStyle(WeatherPalette.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(WeatherPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine).accessibilityIdentifier("my.compare.weather.\(place.city)")
            .task(id: reload) {
                guard !app.offline else { return }
                if reload > 0 || weather.dataset == nil || weather.cached || weather.error != nil || Date.now.timeIntervalSince(weather.dataset?.fetchedAt ?? .distantPast) > 600 {
                    await weather.refresh()
                }
            }
    }
}

struct MyCityClocksSheet: View {
    let app: WeatherApplication
    @State private var reference: WeatherPlace
    @State private var hoursAhead: Double = 0
    init(app: WeatherApplication) {
        self.app = app
        _reference = State(initialValue: app.selected)
    }
    private var cities: [WeatherPlace] {
        [reference] + app.places.filter { $0.id != reference.id }
    }
    var body: some View {
        MyTravelSheet(title: "城市时钟") {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let date = context.date.addingTimeInterval(hoursAhead * 3600)
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(hoursAhead == 0 ? "此刻，同一片天空下" : "\(Int(hoursAhead)) 小时后，各地是几点？", systemImage: "globe.asia.australia")
                            .font(.headline).accessibilityIdentifier("my.clocks.heading")
                        Text("以 \(reference.title) 为参照，按各地时区换算。")
                            .font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                        Slider(value: $hoursAhead, in: 0...24, step: 1)
                            .tint(WeatherPalette.accent).accessibilityLabel("查看未来时间")
                            .accessibilityValue(hoursAhead == 0 ? "现在" : "\(Int(hoursAhead))小时后")
                            .accessibilityIdentifier("my.clocks.slider")
                        HStack {
                            Text("现在")
                            Spacer()
                            Button("回到现在") { hoursAhead = 0 }
                                .accessibilityIdentifier("my.clocks.now").disabled(hoursAhead == 0)
                            Spacer()
                            Text("24小时后")
                        }.font(.caption).foregroundStyle(WeatherPalette.secondary)
                    }.padding(18).background(WeatherPalette.lime.opacity(0.25), in: RoundedRectangle(cornerRadius: 20))
                    ForEach(cities) { city in
                        clockRow(city, date: date)
                    }
                    Text("时差按所查看时刻计算，包含夏令时变化。时间换算不依赖天气网络；未知时区会单独标注。")
                        .font(.caption).foregroundStyle(WeatherPalette.secondary)
                }
            }
        }
    }
    private func clockRow(_ city: WeatherPlace, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(city.title).font(.headline)
                if city.id == reference.id {
                    Text("参照").font(.caption).foregroundStyle(WeatherPalette.accent)
                }
            }
            if TimeZone(identifier: city.timeZoneIdentifier) != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        clockTime(city, date: date)
                        Spacer(minLength: 12)
                        clockDate(city, date: date)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        clockTime(city, date: date)
                        clockDate(city, date: date)
                    }
                }
                Text(WeatherClock.difference(from: reference.timeZoneIdentifier, to: city.timeZoneIdentifier, at: date))
                    .font(.subheadline).foregroundStyle(WeatherPalette.accent)
            } else {
                Text("时区未知，暂不能换算当地时间。").font(.subheadline).foregroundStyle(WeatherPalette.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(WeatherPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .accessibilityElement(children: .combine).accessibilityIdentifier("my.clocks.city.\(city.city)")
    }
    private func clockTime(_ city: WeatherPlace, date: Date) -> some View {
        Text(WeatherClock.string(date, "HH:mm", timeZone: city.timeZoneIdentifier))
            .font(WeatherTypography.display(32)).monospacedDigit().fixedSize()
    }
    private func clockDate(_ city: WeatherPlace, date: Date) -> some View {
        Text(WeatherClock.string(date, "M月d日 EEE", timeZone: city.timeZoneIdentifier))
            .font(.subheadline).foregroundStyle(WeatherPalette.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

private struct MyTravelSheet<Content: View>: View {
    let title: String
    var initiallyExpanded = false
    @ViewBuilder let content: () -> Content
    @State private var detent: PresentationDetent = .medium
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        NavigationStack {
            ScrollView {
                content().padding(22).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
            }.background(WeatherPalette.paper).foregroundStyle(WeatherPalette.ink)
                .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.presentationDetents([.medium, .large], selection: $detent)
            .presentationDragIndicator(.visible).presentationCornerRadius(28).presentationBackground(WeatherPalette.paper)
            .onAppear { if initiallyExpanded || typeSize.isAccessibilitySize { detent = .large } }
    }
}
#endif
