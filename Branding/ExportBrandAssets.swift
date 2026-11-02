import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct WeatherAppIconArtwork: View {
    var body: some View {
        ZStack {
            WeatherPalette.paper
            WeatherBrandMark().padding(104)
        }.frame(width: 1024, height: 1024)
    }
}

struct WeatherBrandPresentation: View {
    var body: some View {
        HStack(alignment: .center, spacing: 90) {
            VStack(alignment: .leading, spacing: 0) {
                Text("WEATHER ISLAND").font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(3)
                    .foregroundStyle(WeatherPalette.secondary)
                Text("气象岛").font(WeatherTypography.display(40)).padding(.top, 14)
                Text("一卷山水 · 四时晴雨").font(.system(size: 13)).foregroundStyle(WeatherPalette.secondary).padding(.top, 10)
                WeatherAppIconArtwork()
                    .scaleEffect(224.0 / 1024)
                    .frame(width: 224, height: 224)
                    .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 50).stroke(WeatherPalette.ink.opacity(0.12), lineWidth: 1))
                    .padding(.top, 48)
                Text("远山 / 江渚 / 朱色").font(.system(size: 15, weight: .medium)).padding(.top, 24)
                Text("把山水与晴雨，收进一枚圆境。")
                    .font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary).padding(.top, 10)
                HStack(spacing: 18) {
                    swatch(WeatherPalette.ink, "淡墨绿")
                    swatch(WeatherPalette.accent, "印泥朱")
                    swatch(Color(hex: 0x91A99A), "山岚青")
                }.padding(.top, 38)
                Text("APP ICON + LAUNCH").font(.system(size: 9, design: .monospaced)).tracking(2)
                    .foregroundStyle(WeatherPalette.secondary).padding(.top, 54)
            }
            VStack(spacing: 18) {
                ZStack(alignment: .top) {
                    WeatherSplashView(snapshot: true, onEnter: {})
                    HStack {
                        Text("9:41").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "wifi")
                        Image(systemName: "battery.100percent")
                    }.font(.system(size: 15)).padding(.horizontal, 30).padding(.top, 21)
                    Capsule().fill(.black).frame(width: 126, height: 36).offset(y: 11)
                    VStack {
                        Spacer()
                        Capsule().fill(.black.opacity(0.9)).frame(width: 134, height: 5).padding(.bottom, 8)
                    }
                }
                .frame(width: 393, height: 852)
                .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 48).stroke(WeatherPalette.ink.opacity(0.15), lineWidth: 1))
                Text("轻触进入，或等待片刻自动抵达小岛。")
                    .font(.system(size: 11)).foregroundStyle(WeatherPalette.secondary)
            }
        }
        .foregroundStyle(WeatherPalette.ink)
        .padding(55)
        .background(Color(hex: 0xE9EEDF))
        .environment(\.colorScheme, .light)
    }
    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: 8) {
            Circle().fill(color).frame(width: 24, height: 24)
            Text(name).font(.system(size: 9)).foregroundStyle(WeatherPalette.secondary)
        }
    }
}

@main struct ExportBrandAssets {
    @MainActor static func save<V: View>(_ view: V, scale: CGFloat, opaque: Bool, to url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = scale
        renderer.isOpaque = opaque
        guard let image = renderer.cgImage,
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "BrandExport", code: 1)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "BrandExport", code: 2) }
    }
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let assets = root.appendingPathComponent("WeatherIsland/Assets.xcassets", isDirectory: true)
        for pixels in [40, 58, 60, 80, 87, 120, 180, 1024] {
            try save(WeatherAppIconArtwork(), scale: CGFloat(pixels) / 1024, opaque: true,
                     to: assets.appendingPathComponent("AppIcon.appiconset/AppIcon-\(pixels).png"))
        }
        for scale in [1, 2, 3] {
            try save(WeatherBrandMark().frame(width: 144, height: 144), scale: CGFloat(scale), opaque: false,
                     to: assets.appendingPathComponent("BrandMark.imageset/BrandMark@\(scale)x.png"))
        }
        try save(WeatherBrandPresentation(), scale: 1.5, opaque: true,
                 to: root.appendingPathComponent("Previews/Brand-Launch.png"))
        print("Exported all app icon sizes, launch logo assets and the brand preview.")
    }
}
