import SwiftUI

struct WeatherExplorerView: View {
    @Environment(\.dismiss) private var dismiss
    let selected: WeatherKind
    var sceneStyle:PaperSceneStyle? = nil
    var demoPlace:WeatherPlace = .shanghai
    @State private var previewKind:WeatherKind?
    @State private var demoDetail:WeatherReport?
    private var selection:WeatherKind {previewKind ?? selected}
    var snapshot = false
    let onSelect: (WeatherKind) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("天气剧场").font(WeatherTypography.display(26)).tracking(2)
                    Text("听风看雨，观云知时。")
                        .font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(Circle().stroke(WeatherPalette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭天气剧场")
            }
            .padding(.horizontal, 24).padding(.top, 25).padding(.bottom, 20)
            if snapshot { collection }
            else { ScrollView { collection }.scrollIndicators(.hidden) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(WeatherPalette.ink)
        .background(WeatherPalette.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .presentationDragIndicator(.visible)
        .sheet(item:$demoDetail){ report in WeatherDetailView(report:report,sceneStyle:sceneStyle) }

    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let sceneStyle {
                PaperCityScene(style:sceneStyle,kind:selection,animate:!snapshot && demoDetail == nil)
                    .aspectRatio(360.0/248,contentMode:.fit).clipShape(RoundedRectangle(cornerRadius:22))
                HStack {
                    VStack(alignment:.leading,spacing:5){Text(selection.name).font(.system(size:20,weight:.semibold));Text(selection.effectLabel).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)}
                    Spacer()
                    Button("演示生活建议") {
                        var report=WeatherReport.demo(selection);report.place=demoPlace;report.scope="\(demoPlace.title) · 离线天气演示";demoDetail=report
                    }.font(.system(size:13,weight:.semibold)).buttonStyle(.bordered)
                }
            }
            HStack(spacing: 7) {
                Circle().fill(WeatherPalette.accent).frame(width: 5, height: 5)
                Text("11 种天空 / 离线演示，点选体验")
                    .font(.system(size: 12, weight: .medium))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                ForEach(WeatherKind.allCases) { kind in
                    Button { previewKind=kind;onSelect(kind) } label: {
                        VStack(spacing: 9) {
                            HStack {
                                Text(String(format: "%02d", (WeatherKind.allCases.firstIndex(of: kind) ?? 0) + 1))
                                    .font(.system(size: 12, design: .monospaced)).opacity(0.55)
                                Spacer()
                                if kind == selection {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                                }
                            }
                            Image(systemName: kind.symbol)
                                .font(.system(size: 27, weight: .light))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(kind == selection ? WeatherPalette.lime : kind.tint)
                                .frame(height: 31)
                            Text(kind.name).font(.system(size: 12, weight: .semibold))
                            Text(kind.effectLabel).font(.system(size: 12)).opacity(0.6)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 128)
                        .foregroundStyle(kind == selection ? WeatherPalette.paper : WeatherPalette.ink)
                        .background(RoundedRectangle(cornerRadius: 18).fill(kind == selection ? WeatherPalette.ink : WeatherPalette.surface))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(WeatherPalette.line.opacity(kind == selection ? 0 : 1), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(kind.name)，\(kind.effectLabel)，切换示例天气")
                    .accessibilityAddTraits(kind == selection ? .isSelected : [])
                }
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("每一种天空，都有自己的生活方式。")
                    .font(.system(size: 12, weight: .medium))
                Text(sceneStyle == nil ? "选择后回到小岛，点主画面查看紫外线、穿衣与出行建议。此处是离线天气演示，所有场景均非实时预报。":"独立体验天气特效与示例生活建议。关闭后继续查看当前地区的真实预报。")
                    .font(.system(size: 12)).lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(WeatherPalette.secondary)
            }
            .padding(.vertical, 3)
        }
        .padding(.horizontal, 24).padding(.bottom, 25)
    }
}

#if DEBUG && os(iOS)
struct WeatherExplorer_Previews: PreviewProvider {
    static var previews: some View {
        WeatherExplorerView(selected: .partlyCloudy, onSelect: { _ in })
            .previewDevice("iPhone 15 Pro")
            .previewDisplayName("天气剧场 · 全部 11 种天空")
    }
}
#endif
