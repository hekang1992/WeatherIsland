import SwiftUI
import AppKit

/// Render the production widget views at their real layout sizes.
@main struct ExportWidgetPreviews {
    @MainActor static func main() throws {
        let destination = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Previews"
        let directory = URL(fileURLWithPath: destination, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for style in IslandWidgetStyle.allCases {
            for size in IslandWidgetSize.allCases {
                let width: CGFloat = size == .small ? 158 : 338
                let height: CGFloat = size == .large ? 354 : 158
                try save(card(style, size).frame(width: width, height: height),
                         to: directory.appendingPathComponent("Widget-\(style.rawValue)-\(size.rawValue).png"))
            }
        }
        let sheet = VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text(WL("气象岛 / 桌面小组件")).font(.system(size: 30, weight: .medium, design: WeatherLocalization.isChinese ? .serif : .default))
                Spacer()
                Text(WL("三种功能 · 九个布局")).font(.system(size: 14))
            }
            HStack(alignment: .top, spacing: 30) {
                ForEach(IslandWidgetStyle.allCases) { style in
                    VStack(alignment: .leading, spacing: 18) {
                        Text(style.title).font(.system(size: 22, weight: .medium, design: WeatherLocalization.isChinese ? .serif : .default)).foregroundStyle(style.ink)
                        Text(style.subtitle).font(.system(size: 12)).foregroundStyle(style.ink.opacity(0.7))
                        Text(WL("小号 · 随手一瞥")).font(.system(size: 11)).foregroundStyle(.secondary)
                        card(style, .small).frame(width: 158, height: 158)
                        Text(WL("中号 · 多一点从容")).font(.system(size: 11)).foregroundStyle(.secondary)
                        card(style, .medium).frame(width: 338, height: 158)
                        Text(WL("大号 · 展开一日晴雨")).font(.system(size: 11)).foregroundStyle(.secondary)
                        card(style, .large).frame(width: 338, height: 354)
                    }.frame(width: 338, alignment: .leading)
                }
            }
            Text(WL("示例数据 · 布局与实际 WidgetKit 小组件共用视图 · 设置 → 桌面小组件可逐一预览"))
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }.padding(38).background(Color(red: 0.97, green: 0.96, blue: 0.93))
        try save(sheet, to: directory.appendingPathComponent("Widgets-Overview.png"))
        print("Exported 9 widget previews and overview to \(directory.path)")
    }
    @MainActor private static func card(_ style: IslandWidgetStyle, _ size: IslandWidgetSize) -> some View {
        IslandWidgetContent(style: style, size: size, weather: .sample, date: IslandWidgetWeather.sample.fetchedAt, demo: true)
            .background { IslandWidgetBackdrop(style: style) }
            .clipShape(RoundedRectangle(cornerRadius: 23))
            .environment(\.colorScheme, .light).environment(\.locale, WeatherLocalization.locale)
    }
    @MainActor private static func save<V: View>(_ view: V, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
    }
}
