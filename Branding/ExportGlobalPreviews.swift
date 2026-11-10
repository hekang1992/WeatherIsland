import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct SceneContactSheet:View {
    var body:some View {
        VStack(alignment:.leading,spacing:24){
            HStack(alignment:.bottom){VStack(alignment:.leading,spacing:10){Text("气象岛 · 宋韵画境").font(WeatherTypography.display(34));Text("山水入怀 · 晴雨有时").font(.system(size:11,design:.monospaced)).tracking(3)};Spacer();Text("十卷意境 · 五十幅画境 · 十一种晴雨").font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)}
            ForEach(PaperSceneStyle.Family.allCases,id:\.self){family in
                VStack(alignment:.leading,spacing:8){
                    Text((PaperSceneStyle.all.first{$0.family==family}?.artDirection ?? "") + " · " + "卷之" + String(PaperSceneStyle.Family.allCases.firstIndex(of:family)!+1)).font(WeatherTypography.display(17)).tracking(2)
                    HStack(spacing:14){ForEach(PaperSceneStyle.all.filter{$0.family==family}){style in
                        VStack(alignment:.leading,spacing:5){PaperCityScene(style:style,animate:false).frame(width:232,height:160).background(style.tint.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius:4));Text(String(format:"%02d",style.number+1)+" / "+style.displayName).font(.system(size:11,weight:.medium)).padding(.leading,6)}
                    }}
                }
            }
            Text("原创意境插画，非古画复制，非当地实景 · 设置 → 宋韵画境 → 预览并应用").font(.system(size:11)).foregroundStyle(WeatherPalette.secondary)
        }.padding(36).foregroundStyle(WeatherPalette.ink).background(WeatherPalette.paper)
    }
}

struct ArtDirectionBoard:View {
    private let picks=[0,15,20,25,35,40]
    var body:some View {
        VStack(alignment:.leading,spacing:22){
            Text("一卷山水，四时晴雨。").font(WeatherTypography.display(32))
            Text("宋韵画境 / 绢色、淡墨、青绿与留白").font(.system(size:13)).foregroundStyle(WeatherPalette.secondary)
            ForEach(0..<3){row in
                HStack(alignment:.top,spacing:16){ForEach(Array(picks[(row*2)..<(row*2+2)]),id:\.self){i in
                    let style=PaperSceneStyle.all[i]
                    VStack(alignment:.leading,spacing:10){
                        PaperCityScene(style:style,animate:false).frame(width:300,height:207).clipShape(RoundedRectangle(cornerRadius:5))
                        HStack{Text(style.artDirection).font(WeatherTypography.display(19));Spacer();Text(style.displayName).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)}
                    }.frame(width:300)
                }}
            }
            Text("气象岛 · 原创宋韵画境 · SwiftUI 绘制").font(.system(size:11,design:.monospaced)).tracking(1)
        }.padding(28).foregroundStyle(WeatherPalette.ink).background(WeatherPalette.paper)
    }
}

struct WeatherClarityBoard: View {
    private let kinds: [WeatherKind] = [.clear, .partlyCloudy, .overcast]
    private let descriptions = ["暖阳明亮 · 水面映金", "云遮半日 · 青白浮云", "日光隐去 · 灰青层云"]
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("晴 · 云 · 阴，各有天色").font(WeatherTypography.display(28))
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(kinds.enumerated()), id: \.element.id) { index, kind in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(kind.name).font(WeatherTypography.display(22))
                        Text(descriptions[index]).font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary)
                        ForEach([0, 15, 40], id: \.self) { scene in
                            PaperCityScene(style: PaperSceneStyle.all[scene], kind: kind, animate: false)
                                .frame(width: 300, height: 207).clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                        HStack(spacing: 12) {
                            PaperCityScene(style: PaperSceneStyle.all[0], kind: kind, animate: false)
                                .frame(width: 85, height: 59).clipShape(RoundedRectangle(cornerRadius: 4))
                            Text("城市卡片缩略图").font(.system(size: 11)).foregroundStyle(WeatherPalette.secondary)
                        }
                    }.frame(width: 300)
                }
            }
        }.padding(28).foregroundStyle(WeatherPalette.ink).background(WeatherPalette.paper)
    }
}

@main struct ExportGlobalPreviews {
    @MainActor static func save<V:View>(_ view:V,to url:URL,scale:CGFloat=2)throws{
        let renderer=ImageRenderer(content:view.environment(\.colorScheme,.light));renderer.scale=scale;renderer.isOpaque=true
        guard let image=renderer.cgImage,let dest=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)else{throw NSError(domain:"Preview",code:1)}
        CGImageDestinationAddImage(dest,image,nil);guard CGImageDestinationFinalize(dest)else{throw NSError(domain:"Preview",code:2)}
    }
    @MainActor static func main()throws{
        _=NSApplication.shared
        let root=URL(fileURLWithPath:CommandLine.arguments[1]);let previews=CommandLine.arguments.count > 2 && !CommandLine.arguments[2].hasPrefix("--") ? URL(fileURLWithPath: CommandLine.arguments[2]) : root.appendingPathComponent("Previews")
        try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
        try save(WeatherClarityBoard(),to:previews.appendingPathComponent("Weather-Clear-Cloudy-Overcast.png"),scale:1.5)
        try save(HStack(spacing:16) {
            ForEach([WeatherKind.clear, .partlyCloudy, .overcast]) { kind in
                VStack(alignment:.leading,spacing:8) {
                    IslandScene(kind:kind,animate:false).frame(width:300,height:192)
                    Text(kind.name).font(.system(size:15,weight:.medium))
                }
            }
        }.padding(24).foregroundStyle(WeatherPalette.ink).background(WeatherPalette.paper),
        to:previews.appendingPathComponent("Weather-Island-Clarity.png"),scale:1.5)
        if CommandLine.arguments.contains("--weather-only") {
            print("Exported clear, partly cloudy and overcast comparison boards.")
            return
        }
        if !CommandLine.arguments.contains("--store-assets") {
        try save(SceneContactSheet(),to:previews.appendingPathComponent("50-Paper-Scenes.png"),scale:1.5)
        try save(ArtDirectionBoard(),to:previews.appendingPathComponent("Art-Directions.png"),scale:1.5)
        }
        let weatherKinds:[WeatherKind]=[.clear,.overcast,.lightRain,.heavyRain,.thunderstorm,.hail]
        try save(VStack(spacing:18){
            Text(WL("一江山水 · 六种晴雨")).font(.system(size:25,weight:.semibold))
            ForEach(0..<3){row in HStack(spacing:16){ForEach(Array(weatherKinds[(row*2)..<(row*2+2)])){kind in
                VStack(alignment:.leading,spacing:8){PaperCityScene(style:PaperSceneStyle.all[0],kind:kind,animate:false).frame(width:300,height:207).clipShape(RoundedRectangle(cornerRadius:5));Text(kind.name).font(.system(size:15,weight:.medium))}
            }}}
        }.padding(24).foregroundStyle(WeatherPalette.ink).background(WeatherPalette.paper),to:previews.appendingPathComponent("Weather-Effects-Grid.png"),scale:1.5)
        let app=WeatherApplication(live:false)
        try save(RegionalWeatherHome(app:app,preview:true,snapshot:true).frame(width:393).fixedSize(horizontal:false,vertical:true),to:previews.appendingPathComponent("Global-Weather-Home.png"))
        try save(RegionalWeatherHome(app:app,preview:true,snapshot:true).frame(width:393).fixedSize(horizontal:false,vertical:true).frame(height:852,alignment:.top).clipped(),to:previews.appendingPathComponent("Weather-First-Screen.png"))
        for i in [0,5,10,15,16,20,21,25,30,35,40,45,46]{try save(PaperCityScene(style:PaperSceneStyle.all[i],kind:.partlyCloudy,animate:false).frame(width:393,height:270).background(WeatherPalette.paper),to:previews.appendingPathComponent("Scene-\(i+1).png"))}
        print("Exported 50-scene contact sheet and offline homepage.")
    }
}
