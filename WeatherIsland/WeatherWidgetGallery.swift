import SwiftUI

struct WeatherWidgetGallery: View {
    var app: WeatherApplication?
    @State private var style: IslandWidgetStyle = .landscape
    private var weather: IslandWidgetWeather {
        #if os(iOS)
        if let app, let dataset = app.weather(for: app.selected).dataset {
            return WeatherWidgetBridge.snapshot(dataset, place: app.selected)
        }
        #endif
        return .sample
    }
    private var demo: Bool {
        guard let app else { return true }
        return app.weather(for: app.selected).dataset == nil
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(WL("把晴雨，留在桌面")).font(WeatherTypography.display(28))
                    Text(WL("三种陪伴，九个尺寸。\n每一眼，都是你关心的天气。"))
                        .font(.subheadline).foregroundStyle(WeatherPalette.secondary).lineSpacing(5)
                }
                Picker(WL("小组件功能"), selection: $style) {
                    ForEach(IslandWidgetStyle.allCases) { item in Text(item.title).tag(item) }
                }.pickerStyle(.segmented).accessibilityIdentifier("widgets.style")
                VStack(alignment: .leading, spacing: 7) {
                    Label(style.title, systemImage: style.symbol).font(.title3.weight(.medium))
                    Text(style.subtitle).font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                    Text(demo ? WL("以下为示例数据，用于预览布局。") : WLF("预览使用%1$@的天气数据。", String(describing: weather.place.name)))
                        .font(.caption).foregroundStyle(WeatherPalette.secondary)
                }
                ForEach(IslandWidgetSize.allCases) { size in
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Text(size.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(sizeDescription(size)).font(.caption).foregroundStyle(WeatherPalette.secondary)
                        }
                        GeometryReader { geometry in
                            let full = min(geometry.size.width, 360)
                            let width = size == .small ? (full - 18) / 2 : full
                            let height = size == .large ? full : (full - 18) / 2
                            IslandWidgetContent(style: style, size: size, weather: weather,
                                                date: demo ? weather.fetchedAt : .now, demo: demo)
                                .background { IslandWidgetBackdrop(style: style) }
                                .frame(width: width, height: height)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 24).stroke(style.ink.opacity(0.06), lineWidth: 1) }
                                .shadow(color: style.ink.opacity(0.07), radius: 12, x: 0, y: 6)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("widgets.preview.\(style.rawValue).\(size.rawValue)")
                        }
                        .aspectRatio(size == .large ? 1 : 360.0 / 171, contentMode: .fit)
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Label(WL("添加到主屏幕"), systemImage: "plus.square.dashed").font(.headline)
                    Text(WL("1  长按主屏幕空白处，进入编辑模式。\n2  点添加小组件，搜索「气象岛」。\n3  选择功能与尺寸，轻点添加。"))
                        .font(.subheadline).lineSpacing(9)
                    Text(WL("小组件跟随 App 当前所选城市。点击后可查看相应详情；刷新时机由系统调度，离线时显示缓存与更新时间。"))
                        .font(.caption).foregroundStyle(WeatherPalette.secondary).lineSpacing(5)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(WeatherPalette.surface, in: RoundedRectangle(cornerRadius: 20))
            }.padding(22).weatherReadingWidth()
        }
        .background(WeatherPalette.paper.ignoresSafeArea())
        .foregroundStyle(WeatherPalette.ink)
        .navigationTitle(WL("桌面小组件")).widgetGalleryNavigationStyle()
    }
    private func sizeDescription(_ size: IslandWidgetSize) -> String {
        switch (style, size) {
        case (.landscape, .small): WL("此刻天气")
        case (.landscape, .medium): WL("天气 + 小时气温")
        case (.landscape, .large): WL("小时趋势 + 三日预报")
        case (.rain, .small): WL("带伞建议")
        case (.rain, .medium): WL("六小时降水概率")
        case (.rain, .large): WL("概率趋势 + 预计雨量")
        case (.daylight, .small): WL("日出日落时刻")
        case (.daylight, .medium): WL("倒计时 + 太阳轨迹")
        case (.daylight, .large): WL("太阳轨迹 + 白昼时长")
        }
    }
}

struct WeatherWidgetDestination: View {
    let app: WeatherApplication
    let style: IslandWidgetStyle
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(style.subtitle).font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                #if os(iOS)
                if let dataset = app.weather(for: app.selected).dataset {
                    let weather = WeatherWidgetBridge.snapshot(dataset, place: app.selected)
                    IslandWidgetContent(style: style, size: .large, weather: weather)
                        .background { IslandWidgetBackdrop(style: style) }
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    if style == .rain {
                        Text(WL("图表显示逐小时降水概率，预计雨量为未来六个预报小时的累计值。建议随天气变化调整行程。"))
                            .font(.subheadline).lineSpacing(5)
                    } else if style == .daylight {
                        Text(WL("日出、日落按所选城市当地时间显示。太阳轨迹为日照进度示意。"))
                            .font(.subheadline).lineSpacing(5)
                    }
                    NavigationLink(WL("查看天气与生活指南")) {
                        WeatherDetailView(report: dataset.current, sceneStyle: app.style)
                    }.buttonStyle(.bordered)
                } else {
                    ContentUnavailableView(WL("天气正在准备中"), systemImage: style.symbol,
                                           description: Text(WL("返回天气首页联网更新后，即可查看这座城市的天气。")))
                }
                #endif
            }.padding(22).weatherReadingWidth()
        }.background(WeatherPalette.paper.ignoresSafeArea()).foregroundStyle(WeatherPalette.ink)
            .navigationTitle(style.title).widgetGalleryNavigationStyle()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(WL("完成")) { dismiss() } } }
    }
}

private extension View {
    @ViewBuilder func widgetGalleryNavigationStyle() -> some View {
        #if os(iOS)
        self.toolbar(.visible, for: .navigationBar).navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
