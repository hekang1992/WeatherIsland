import SwiftUI

struct PaperSceneStyle: Identifiable, Hashable, Sendable {
    enum Family: String, CaseIterable, Sendable {
        case metropolis = "世界都市", heritage = "古城手记", coast = "海岸来信", mountain = "山间日记", canal = "水乡慢调"
        case forest = "森林呼吸", desert = "旷野诗篇", snow = "冬日童话", tropical = "南方假日", countryside = "田园散步"
    }
    let id: String
    let name: String
    let subtitle: String
    let family: Family
    let variant: Int
    var artDirection:String {family.artDirection}
    var number: Int { Self.all.firstIndex(where: { $0.id == id }) ?? 0 }
    var tint: Color {
        switch family {
        case .metropolis: Color(hex: 0xC6D2C7)
        case .heritage: Color(hex: 0xD8CDB6)
        case .coast: Color(hex: 0xCAD6D0)
        case .mountain: Color(hex: 0xAFC6B3)
        case .canal: Color(hex: 0xC5D2BB)
        case .forest: Color(hex: 0xB8C5AF)
        case .desert: Color(hex: 0xD8C5A6)
        case .snow: Color(hex: 0xD6DCD5)
        case .tropical: Color(hex: 0xE4D0CA)
        case .countryside: Color(hex: 0xC9D1AD)
        }
    }
    static let all: [PaperSceneStyle] = {
        let groups: [(Family, [(String, String)])] = [
            (.metropolis, [("江渚烟岚","一江静水，半卷烟岚"),("春江远岫","远山含黛，春水初生"),("汀洲薄雾","风过汀洲，雾入平江"),("平湖落照","一痕暮色，万顷澄波"),("远浦归帆","归帆渐小，江天自阔")]),
            (.heritage, [("汀兰小筑","庭前一树，窗外四时"),("疏篱茅舍","竹篱不语，草舍生烟"),("一窗竹影","一窗清影，半日闲心"),("临水轩榭","水映疏檐，风来有信"),("松下茶烟","松风入座，茶烟绕阶")]),
            (.coast, [("江舟听雨","一舟静泊，细雨入江"),("远帆归泊","帆影一线，水天无际"),("寒汀双鹭","浅汀双影，独占秋光"),("芦岸秋声","芦花如雪，风有回声"),("长桥卧波","桥横一水，云过千山")]),
            (.mountain, [("千里烟岚","青绿入画，云气出岫"),("群峰叠翠","群山相望，翠色层生"),("深山观瀑","飞泉落玉，松壑生凉"),("云岫幽居","云深一舍，山静无尘"),("溪山行旅","溪回路转，人在画中")]),
            (.canal, [("半池荷风","一池清气，半扇荷风"),("曲桥听荷","桥边小坐，听叶间雨"),("莲舟轻渡","舟行莲隙，水动花香"),("一池月色","月色如水，莲影生凉"),("残荷听雨","疏荷留韵，细雨知秋")]),
            (.forest, [("寒松清韵","松针写风，山石留白"),("竹径通幽","竹深藏径，风入无声"),("疏竹听风","疏枝有节，清影无尘"),("丹枫映水","一枝秋色，落入清波"),("松泉小隐","松下清泉，石上微云")]),
            (.desert, [("平沙雁落","沙平水远，雁字归秋"),("秋水长天","秋水无声，天光自远"),("赭石远岫","山染浅赭，云留淡痕"),("芦汀晚照","晚照含金，芦花照水"),("山月初生","山月初上，空水生明")]),
            (.snow, [("江山初雪","一夜晴雪，满山无声"),("雪里人家","薄雪覆檐，微灯待归"),("寒江独钓","一舟一影，天地澄白"),("雪岭归樵","山径留痕，暮雪归人"),("雪汀鹤影","白鹤临汀，静候春信")]),
            (.tropical, [("玉兰清露","素瓣含露，清枝向春"),("海棠春睡","一枝浅绛，春意初匀"),("双雀栖枝","双雀小憩，满枝春声"),("白鹭青莲","白羽映水，青莲生风"),("山茶照水","花开有时，水静无言")]),
            (.countryside, [("春畴新绿","田水初满，春色徐来"),("牧笛晚风","远村炊烟，晚风过野"),("杏花疏雨","杏花如雪，小径微湿"),("桑野清和","桑阴满地，风物清和"),("溪桥归路","溪桥向晚，一路山青")])
        ]
        return groups.flatMap { family, entries in entries.enumerated().map { i, e in
            PaperSceneStyle(id: "\(family.rawValue)-\(i)", name: e.0, subtitle: e.1, family: family, variant: i)
        }}
    }()
    static func named(_ id: String?) -> PaperSceneStyle? { all.first { $0.id == id } }
    static func automatic(for place: WeatherPlace) -> PaperSceneStyle {
        let name = place.city.lowercased()
        let names: [(String,Int)] = [("上海",0),("shanghai",0),("东京",1),("tokyo",1),("london",2),("伦敦",2),("paris",3),("巴黎",3),("new york",4),("纽约",4),("北京",5),("beijing",5),("西安",6),("xi'an",6),("广州",8),("guangzhou",8),("成都",9),("chengdu",9),("重庆",16),("chongqing",16),("杭州",20),("hangzhou",20),("深圳",14),("shenzhen",14),("三亚",40),("sanya",40),("哈尔滨",36),("harbin",36)]
        if let match = names.first(where: { name.contains($0.0) }) {
            let country:[Int:String]=[0:"CN",1:"JP",2:"GB",3:"FR",4:"US",5:"CN",6:"CN",8:"CN",9:"CN",14:"CN",16:"CN",20:"CN",36:"CN",40:"CN"]
            if country[match.1] == place.countryCode.uppercased() {return all[match.1]}
        }
        // A suggested art scene, never presented as a factual local landscape.
        if abs(place.latitude) > 58 { return all[35 + stableIndex(place.city, count: 5)] }
        if abs(place.latitude) < 23 { return all[40 + stableIndex(place.city, count: 5)] }
        let families = [10,15,20,25,30,45]
        return all[families[stableIndex(place.id, count: families.count)] + stableIndex(place.city, count: 5)]
    }
    private static func stableIndex(_ text: String, count: Int) -> Int {
        Int(text.utf8.reduce(UInt64(5381)) { ($0 &* 33) &+ UInt64($1) } % UInt64(count))
    }
}

/// Fifty original Song-inspired landscape and flower-and-bird compositions.
struct PaperCityScene: View {
    let style: PaperSceneStyle
    var kind: WeatherKind = .partlyCloudy
    var animate = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var epoch = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24.0, paused: !animate || reduceMotion || phase != .active)) { timeline in
            let time = animate && !reduceMotion && phase == .active ? timeline.date.timeIntervalSince(epoch) : 2.8
            Canvas { context, size in
                // Every painting is composed on the same 360 × 248 sheet. Keep
                // a single scale so circles, birds and architecture retain their shape.
                let scale = min(size.width / 360, size.height / 248)
                context.translateBy(x: (size.width - 360 * scale) / 2,
                                    y: (size.height - 248 * scale) / 2)
                context.scaleBy(x: scale, y: scale)
                context.clip(to: Path(CGRect(x: 0, y: 0, width: 360, height: 248)))
                SongPainting.draw(style, kind: kind, time: time, context: &context)
                context.translateBy(x: 0, y: (248 - 230) / 2)
                WeatherParticles.draw(kind: kind, time: time, context: &context, onDark: false, subtle: true)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension PaperSceneStyle.Family {
    var artDirection: String {
        switch self {
        case .metropolis: "烟岚江渚"
        case .heritage: "庭院清供"
        case .coast: "水墨行舟"
        case .mountain: "青绿山水"
        case .canal: "荷风莲影"
        case .forest: "墨竹松风"
        case .desert: "远山秋霁"
        case .snow: "寒江晴雪"
        case .tropical: "花鸟小景"
        case .countryside: "田园清和"
        }
    }
}

/// Original programmatic paintings, not reproductions of historical artworks.
/// All shapes are static except a very slight movement of mist and weather.
enum SongPainting {
    private static let ink = Color(hex:0x39483E)
    private static let moss = Color(hex:0x647E69)
    private static let blue = Color(hex:0x79938B)
    private static let silk = Color(hex:0xEEE7D7)
    private static let seal = Color(hex:0x9F5143)
    private static func point(_ x:Double,_ y:Double)->CGPoint {CGPoint(x:x,y:y)}
    private static func noise(_ i:Int,_ seed:Int)->Double {
        let n=sin(Double(i &* 137 &+ seed &* 73))*43758.5453
        return n-floor(n)
    }
    static func draw(_ s:PaperSceneStyle,kind:WeatherKind,time:Double,context c:inout GraphicsContext) {
        let v=s.variant
        paper(&c,seed:s.number)
        weatherSky(kind, time: time, &c)
        var scene=c
        scene.clip(to:Path(CGRect(x:0,y:0,width:360,height:248)))
        switch s.family {
        case .metropolis:
            distant(&scene,v:v,tint:blue)
            if v == 3 && ![WeatherKind.clear, .partlyCloudy, .overcast].contains(kind) {disc(234,91,14,Color(hex:0xC49B76).opacity(0.24),&scene)}
            bank(-67,218,240,66,moss.opacity(0.36),&scene)
            ripples(174,180,130,&scene)
            boat(177+Double(v)*7,181,scale:v == 4 ? 1.2:0.8,sail:v == 4,&scene)
            if v%2 == 0 {willow(42,226,0.75,&scene)} else {reeds(44,220,0.75,&scene)}
            birds(172,101,count:3+v%3,&scene)
            mist(132+sin(time*0.12)*3,&scene)
        case .heritage:
            distant(&scene,v:v,tint:moss.opacity(0.6))
            bank(25,219,265,40,moss.opacity(0.18),&scene)
            if v == 2 {
                var window=Path(roundedRect:CGRect(x:110,y:51,width:122,height:139),cornerRadius:60)
                scene.stroke(window,with:.color(ink.opacity(0.3)),lineWidth:1.4)
                window=Path(CGRect(x:170,y:60,width:0.6,height:127));scene.fill(window,with:.color(ink.opacity(0.22)))
                bamboo(124,191,0.62,seed:2,&scene)
                rock(53,218,57,42,&scene)
            } else {
                pavilion(159+Double(v)*8,185,scale:v == 1 ? 0.8:1.05,&scene)
                if v == 0 || v == 3 {flowerBranch(26,204,0.8,blossom:Color(hex:0xEEE9DA),seed:v,&scene)}
                else {pine(43,215,0.85,seed:v,&scene)}
            }
            ripples(160,213,115,&scene)
        case .coast:
            distant(&scene,v:v,tint:blue.opacity(0.55))
            ripples(110,177,157,&scene)
            bank(-15,228,154,36,moss.opacity(0.26),&scene)
            reeds(38,230,0.85,&scene)
            if v == 2 {egret(221,182,0.85,&scene);egret(247,186,0.66,&scene)}
            else if v == 3 {reeds(218,221,0.8,&scene);birds(163,96,count:4,&scene)}
            else if v == 4 {bridge(156,184,&scene)}
            else {boat(175,168,scale:1.05,sail:v == 1,&scene)}
        case .mountain:
            ridge(83,37,seed:v+4,color:blue.opacity(0.27),rocky:true,&scene)
            ridge(142,83,seed:v+11,color:Color(hex:0x8EA99A).opacity(0.72),rocky:true,&scene)
            mist(141,&scene)
            ridge(222,121,seed:v+21,color:Color(hex:0x4D7764).opacity(0.88),rocky:true,&scene)
            if v == 2 {curve([(165,106),(156,150),(173,181),(146,215)],silk.opacity(0.92),3.5,&scene)}
            bank(-19,259,170,71,ink.opacity(0.7),&scene)
            pine(42,239,0.65,seed:v,&scene)
            if v == 3 {pavilion(211,208,scale:0.6,&scene)}
            if v == 4 {bridge(204,203,&scene);boat(185,231,scale:0.45,sail:false,&scene)}
            birds(200,68,count:2,&scene)
        case .canal:
            fan(&scene){ fan in
                for i in 0..<5 {let x=91+Double(i)*35;lotus(x,214,scale:0.65+Double(i%2)*0.15,flower:i%2 == v%2,dry:v == 4,seed:i+v,&fan)}
                ripples(101,217,157,&fan)
                if v == 2 {boat(216,204,scale:0.5,sail:false,&fan)}
                if v == 3 {disc(235,65,16,silk.opacity(0.9),&fan)}
                if v == 1 {bridge(157,205,&fan)}
            }
        case .forest:
            ridge(187,37,seed:v,color:blue.opacity(0.13),rocky:false,&scene)
            rock(76,233,103,51,&scene)
            if v == 2 || v == 1 {
                bamboo(78,231,1.06,seed:v,&scene);bamboo(153,228,0.78,seed:8+v,&scene)
            } else if v == 3 {
                flowerBranch(24,234,1.1,blossom:Color(hex:0xA5674D),seed:8,&scene)
                ripples(167,229,117,&scene)
            } else {
                pine(96,233,1.2,seed:v,&scene)
                if v == 4 {curve([(177,198),(204,208),(189,232),(237,249)],blue.opacity(0.3),3,&scene)}
            }
        case .desert:
            if v == 4 && ![WeatherKind.clear, .partlyCloudy, .overcast].contains(kind) {disc(235,77,19,Color(hex:0xD4C29E).opacity(0.4),&scene)}
            ridge(140,39,seed:v+6,color:Color(hex:0xB8AE92).opacity(0.25),rocky:false,&scene)
            ridge(182,46,seed:v+1,color:Color(hex:0xAC9874).opacity(0.34),rocky:false,&scene)
            bank(-21,232,258,49,Color(hex:0xAA956A).opacity(0.4),&scene)
            reeds(51,233,1.0,&scene)
            birds(153,92,count:6,&scene)
            boat(233,194,scale:0.6,sail:false,&scene)
        case .snow:
            ridge(134,64,seed:v+4,color:blue.opacity(0.24),rocky:true,&scene)
            ridge(202,86,seed:v+13,color:ink.opacity(0.32),rocky:true,&scene)
            mist(182,&scene)
            bank(-25,254,207,56,Color(hex:0xF5F2E9),&scene)
            if v == 1 {pavilion(178,199,scale:0.8,&scene)}
            else if v == 4 {egret(225,218,0.85,&scene)}
            else {boat(201,209,scale:0.73,sail:false,&scene)}
            pine(48,236,0.85,seed:8+v,&scene)
            curve([(13,230),(70,224),(112,239)],silk.opacity(0.9),2.3,&scene)
        case .tropical:
            fan(&scene){ fan in
                if v == 3 {
                    lotus(135,225,scale:1.0,flower:true,dry:false,seed:2,&fan)
                    egret(223,208,1.1,&fan)
                } else {
                    let petal:Color = v == 0 ? Color(hex:0xF7F3E8):v == 4 ? Color(hex:0xA45A4C):Color(hex:0xD5A59C)
                    flowerBranch(88,231,1.04,blossom:petal,seed:v,&fan)
                    if v == 2 {sparrow(190,129,1.0,&fan);sparrow(223,145,0.84,&fan)}
                    else {sparrow(212,161,0.75,&fan)}
                }
            }
        case .countryside:
            ridge(132,44,seed:v+5,color:blue.opacity(0.25),rocky:false,&scene)
            for i in 0..<3 {bank(-21+Double(i)*62,228+Double(i)*13,260,60,Color(hex:0x9CA882).opacity(0.2+Double(i)*0.1),&scene)}
            pavilion(187,179,scale:0.67,&scene)
            if v == 2 {flowerBranch(24,231,1.0,blossom:Color(hex:0xF7F2E9),seed:1,&scene)}
            else if v == 4 {bridge(104,206,&scene);willow(37,231,0.66,&scene)}
            else {pine(52,225,0.71,seed:v,&scene)}
            for i in 0..<6 {curve([(99+Double(i)*13,206),(128+Double(i)*15,222),(141+Double(i)*18,247)],ink.opacity(0.12),0.5,&scene)}
        }
        if kind == .clear {
            // Warm reflected light follows the weather, while the original brushwork stays visible.
            c.fill(Path(CGRect(x:0,y:0,width:360,height:248)),with:.radialGradient(
                Gradient(colors:[Color(hex:0xE7BE70).opacity(0.16),Color(hex:0xE7BE70).opacity(0)]),
                center:point(245,48),startRadius:20,endRadius:215))
            if [.metropolis, .coast, .canal, .desert, .countryside].contains(s.family) {
                for i in 0..<7 {
                    let y=164+Double(i)*7
                    let halfWidth=7+Double(i)*2.5
                    let x=241+sin(time*0.45+Double(i)*1.7)*3
                    curve([(x-halfWidth,y),(x,y-0.8),(x+halfWidth,y)],Color(hex:0xC29A51).opacity(0.42-Double(i)*0.035),0.9,&c)
                }
            }
        }
        if kind == .overcast || kind.severe {
            c.fill(Path(CGRect(x:0,y:0,width:360,height:248)),with:.color(ink.opacity(kind.severe ? 0.075:0.09)))
        }
        if kind == .fog {mist(110+sin(time*0.12)*5,&c);mist(180-sin(time*0.12)*3,&c)}
        inscription(s,&c)
    }
    /// Weather cues remain legible in still frames and in small city thumbnails.
    /// Draw the sky before the landscape so clouds stay behind mountains and trees.
    private static func weatherSky(_ kind: WeatherKind, time: Double, _ c: inout GraphicsContext) {
        let sky = Path(CGRect(x: 0, y: 0, width: 360, height: 190))
        switch kind {
        case .clear:
            c.fill(sky, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xEED7A5).opacity(0.55), Color(hex: 0xEED7A5).opacity(0)]),
                startPoint: point(180, 0), endPoint: point(180, 185)))
            sunlight(x: 245, y: 44, radius: 19, time: time, clear: true, &c)
        case .partlyCloudy:
            c.fill(sky, with: .linearGradient(
                Gradient(colors: [Color(hex: 0xBCD0CC).opacity(0.32), Color(hex: 0xBCD0CC).opacity(0)]),
                startPoint: point(180, 0), endPoint: point(180, 175)))
            sunlight(x: 245, y: 43, radius: 17, time: time, clear: false, &c)
            let drift = sin(time * 0.22) * 7
            paintedCloud(x: 28 + drift, y: 19, width: 108, height: 33,
                         top: 0xF9F5E9, base: 0xB3C0B8, opacity: 0.88, &c)
            // This cloud overlaps the sun even when motion is disabled.
            paintedCloud(x: 201 + drift, y: 39, width: 91, height: 35,
                         top: 0xFBF7EC, base: 0xA7B8B1, opacity: 0.96, &c)
        case .overcast:
            c.fill(sky, with: .linearGradient(
                Gradient(colors: [Color(hex: 0x7F9592).opacity(0.5), Color(hex: 0xA9B6AE).opacity(0.2), Color(hex: 0xA9B6AE).opacity(0)]),
                startPoint: point(180, 0), endPoint: point(180, 185)))
            let drift = sin(time * 0.13) * 4
            paintedCloud(x: -34 + drift, y: 4, width: 226, height: 61,
                         top: 0x8D9F9A, base: 0xB8C1B8, opacity: 0.88, &c)
            paintedCloud(x: 136 - drift, y: 17, width: 174, height: 54,
                         top: 0x859792, base: 0xB3BDB4, opacity: 0.84, &c)
            paintedCloud(x: 32 + drift, y: 50, width: 242, height: 35,
                         top: 0xA5B2A9, base: 0xD1D5C8, opacity: 0.78, &c)
        default:
            break
        }
    }

    private static func sunlight(x: Double, y: Double, radius: Double, time: Double, clear: Bool, _ c: inout GraphicsContext) {
        let glow = radius * (clear ? 3.2 : 2.2) + sin(time * 0.65) * 1.5
        c.fill(Path(ellipseIn: CGRect(x: x-glow, y: y-glow, width: glow*2, height: glow*2)),
               with: .radialGradient(Gradient(colors: [Color(hex: 0xE4BC70).opacity(clear ? 0.42 : 0.24), Color(hex: 0xE4BC70).opacity(0)]),
                                     center: point(x,y), startRadius: radius*0.7, endRadius: glow))
        c.fill(Path(ellipseIn: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2)),
               with: .linearGradient(Gradient(colors: [Color(hex: 0xDCAD5C), Color(hex: 0xBD7848)]),
                                     startPoint: point(x,y-radius), endPoint: point(x,y+radius)))
        if clear {
            c.stroke(Path(ellipseIn: CGRect(x: x-radius-5, y: y-radius-5, width: (radius+5)*2, height: (radius+5)*2)),
                     with: .color(Color(hex: 0xC49A54).opacity(0.32)), lineWidth: 0.65)
        }
    }

    private static func paintedCloud(x: Double, y: Double, width: Double, height: Double,
                                     top: UInt32, base: UInt32, opacity: Double, _ c: inout GraphicsContext) {
        var cloud = Path()
        cloud.move(to: point(x, y+height*0.74))
        cloud.addCurve(to: point(x+width*0.2, y+height*0.36),
                       control1: point(x-width*0.02, y+height*0.43), control2: point(x+width*0.1, y+height*0.3))
        cloud.addCurve(to: point(x+width*0.52, y+height*0.21),
                       control1: point(x+width*0.25, y-height*0.14), control2: point(x+width*0.46, y-height*0.08))
        cloud.addCurve(to: point(x+width*0.8, y+height*0.44),
                       control1: point(x+width*0.65, y+height*0.03), control2: point(x+width*0.79, y+height*0.13))
        cloud.addCurve(to: point(x+width, y+height*0.76),
                       control1: point(x+width*0.92, y+height*0.36), control2: point(x+width*1.04, y+height*0.58))
        cloud.addCurve(to: point(x, y+height*0.74),
                       control1: point(x+width*0.88, y+height*1.08), control2: point(x+width*0.12, y+height*1.04))
        cloud.closeSubpath()
        c.fill(cloud, with: .linearGradient(
            Gradient(colors: [Color(hex: top).opacity(opacity), Color(hex: base).opacity(opacity*0.68)]),
            startPoint: point(x,y), endPoint: point(x,y+height)))
    }

    private static func paper(_ c:inout GraphicsContext,seed:Int) {
        c.fill(Path(CGRect(x:0,y:0,width:360,height:248)),with:.linearGradient(Gradient(colors:[Color(hex:0xF1EADA),Color(hex:0xE9E2D1)]),startPoint:point(0,0),endPoint:point(360,248)))
        for i in 0..<820 {
            let x=noise(i,7)*360,y=noise(i,31)*248
            let r=0.13+noise(i,23)*0.4
            c.fill(Path(ellipseIn:CGRect(x:x,y:y,width:r,height:r)),with:.color(ink.opacity(0.035+noise(i,11)*0.06)))
        }
        for i in 0..<90 {let y=Double(i)*2.8;c.stroke(Path{p in p.move(to:point(0,y));p.addLine(to:point(360,y+0.2))},with:.color(Color.white.opacity(0.045)),lineWidth:0.25)}
    }
    private static func ridge(_ base:Double,_ height:Double,seed:Int,color:Color,rocky:Bool,_ c:inout GraphicsContext) {
        var edge:[CGPoint]=[]
        for i in 0...100 {
            let x=Double(i)*3.6
            let u=x/360
            var n=0.35+0.2*sin(u*7+Double(seed))+0.25*sin(u*12+Double(seed)*0.7)
            n += (rocky ? 0.14:0.04)*sin(u*39+Double(seed))
            n += (rocky ? 0.07:0.01)*sin(u*79+Double(seed)*3)
            edge.append(point(x,base-height*max(0.08,n)))
        }
        var p=Path();p.addLines(edge);p.addLine(to:point(360,base+24));p.addLine(to:point(0,base+24));p.closeSubpath()
        c.fill(p,with:.linearGradient(Gradient(colors:[color,color.opacity(0)]),startPoint:point(0,base-height),endPoint:point(0,base+22)))
        var outline=Path();outline.addLines(edge)
        c.stroke(outline,with:.color(ink.opacity(rocky ? 0.22:0.09)),lineWidth:0.5)
        if rocky {
            for i in 0..<55 {
                let x=noise(i,seed+22)*305;let index=min(100,Int(x/3.6));let top=edge[index].y
                let length=9+noise(i,seed)*height*0.5
                curve([(x,top+4),(x-4,top+length*0.4),(x+3,top+length)],ink.opacity(0.035+noise(i,5)*0.06),0.5,&c)
            }
        }
    }
    private static func distant(_ c:inout GraphicsContext,v:Int,tint:Color) {
        ridge(122,47,seed:v+2,color:tint.opacity(0.28),rocky:false,&c)
        ridge(147,34,seed:v+9,color:tint.opacity(0.2),rocky:false,&c)
    }
    private static func mist(_ y:Double,_ c:inout GraphicsContext) {
        c.fill(Path(CGRect(x:0,y:y,width:360,height:35)),with:.linearGradient(Gradient(colors:[silk.opacity(0),silk.opacity(0.76),silk.opacity(0)]),startPoint:point(0,y),endPoint:point(0,y+35)))
    }
    private static func bank(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:Color,_ c:inout GraphicsContext) {
        var p=Path();p.move(to:point(x,258));p.addLine(to:point(x,y));p.addCurve(to:point(x+w,258),control1:point(x+w*0.22,y-h),control2:point(x+w*0.66,y-h*0.7));p.closeSubpath()
        c.fill(p,with:.linearGradient(Gradient(colors:[color,color.opacity(0.3)]),startPoint:point(0,y-h/2),endPoint:point(0,248)))
        for i in 0..<17 {let px=x+noise(i,9)*w,py=y-h*0.2+noise(i,8)*17;c.fill(Path(ellipseIn:CGRect(x:px,y:py,width:2,height:0.7)),with:.color(ink.opacity(0.12)))}
    }
    private static func disc(_ x:Double,_ y:Double,_ r:Double,_ color:Color,_ c:inout GraphicsContext){c.fill(Path(ellipseIn:CGRect(x:x-r,y:y-r,width:r*2,height:r*2)),with:.color(color))}
    private static func curve(_ points:[(Double,Double)],_ color:Color,_ width:Double,_ c:inout GraphicsContext) {
        guard points.count>=3 else{return};var p=Path();p.move(to:point(points[0].0,points[0].1))
        if points.count==4 {p.addCurve(to:point(points[3].0,points[3].1),control1:point(points[1].0,points[1].1),control2:point(points[2].0,points[2].1))}
        else {p.addQuadCurve(to:point(points[2].0,points[2].1),control:point(points[1].0,points[1].1))}
        c.stroke(p,with:.color(color),style:StrokeStyle(lineWidth:width,lineCap:.round,lineJoin:.round))
    }
    private static func ripples(_ x:Double,_ y:Double,_ w:Double,_ c:inout GraphicsContext) {
        for i in 0..<17 {
            let px=x+noise(i,4)*w*0.6,py=y+Double(i)*3.2,len=9+noise(i,8)*w*0.32
            curve([(px,py),(px+len*0.5,py+0.8),(px+len,py-0.3)],blue.opacity(0.11+noise(i,2)*0.12),0.45,&c)
        }
    }
    private static func boat(_ x:Double,_ y:Double,scale s:Double,sail:Bool,_ c:inout GraphicsContext) {
        var p=Path();p.move(to:point(x-17*s,y));p.addQuadCurve(to:point(x+21*s,y-1*s),control:point(x+2*s,y+12*s));p.addQuadCurve(to:point(x-17*s,y),control:point(x+1*s,y+4*s));c.fill(p,with:.color(ink.opacity(0.78)))
        curve([(x-7*s,y-2*s),(x+3*s,y-16*s),(x+12*s,y-1*s)],ink.opacity(0.6),1.1*s,&c)
        disc(x-8*s,y-6*s,1.6*s,ink,&c)
        curve([(x-8*s,y-4*s),(x-12*s,y-1*s),(x-10*s,y+1*s)],ink,1.2*s,&c)
        curve([(x-12*s,y),(x-22*s,y+7*s),(x-30*s,y+10*s)],ink.opacity(0.6),0.7*s,&c)
        if sail {
            curve([(x+3*s,y-2*s),(x+4*s,y-28*s),(x+3*s,y-45*s)],ink.opacity(0.6),0.8*s,&c)
            var sailPath=Path();sailPath.move(to:point(x+5*s,y-42*s));sailPath.addQuadCurve(to:point(x+16*s,y-14*s),control:point(x+20*s,y-24*s));sailPath.addLine(to:point(x+4*s,y-13*s));sailPath.closeSubpath();c.fill(sailPath,with:.color(Color(hex:0xC4B18E).opacity(0.65)));c.stroke(sailPath,with:.color(ink.opacity(0.35)),lineWidth:0.5)
        }
    }
    private static func birds(_ x:Double,_ y:Double,count:Int,_ c:inout GraphicsContext) {
        for i in 0..<count {let px=x+Double(i)*15,py=y+sin(Double(i)*1.5)*7;curve([(px-3,py-1),(px,py-4),(px+1,py)],ink.opacity(0.5),0.65,&c);curve([(px+1,py),(px+3,py-3),(px+6,py-1)],ink.opacity(0.5),0.65,&c)}
    }
    private static func reeds(_ x:Double,_ y:Double,_ s:Double,_ c:inout GraphicsContext) {
        for i in 0..<15 {let dx=(noise(i,5)-0.5)*55*s,h=(17+noise(i,12)*37)*s
            curve([(x+dx,y),(x+dx-10*s,y-h*0.7),(x+dx-15*s,y-h)],moss.opacity(0.6),0.6*s,&c)
            for j in 0..<3 {let yy=y-h+Double(j)*3*s;curve([(x+dx-15*s,yy),(x+dx-23*s,yy-6*s),(x+dx-24*s,yy-10*s)],Color(hex:0xA59370).opacity(0.6),0.8*s,&c)}
        }
    }
    private static func willow(_ x:Double,_ y:Double,_ s:Double,_ c:inout GraphicsContext) {
        curve([(x,y),(x+18*s,y-66*s),(x-10*s,y-145*s)],ink.opacity(0.75),2*s,&c)
        for i in 0..<8 {let px=x-33*s+Double(i)*12*s,py=y-110*s+sin(Double(i))*16*s
            curve([(x-3*s,y-125*s),(px,py-20*s),(px+15*s,py+57*s)],moss.opacity(0.6),0.7*s,&c)
            for j in 0..<7 {let yy=py+Double(j)*7*s;leaf(px+Double(j)*1.2*s,yy,7*s,0.8,moss.opacity(0.5),&c)}
        }
    }
    private static func pine(_ x:Double,_ y:Double,_ s:Double,seed:Int,_ c:inout GraphicsContext) {
        curve([(x,y),(x+22*s,y-69*s),(x-4*s,y-133*s)],ink.opacity(0.85),3.2*s,&c)
        curve([(x-3*s,y),(x+15*s,y-70*s),(x-6*s,y-130*s)],silk.opacity(0.65),0.8*s,&c)
        for i in 0..<9 {
            let side=i%2 == 0 ? -1.0:1.0,px=x+side*(21+noise(i,seed)*24)*s,py=y-(45+Double(i)*10)*s
            curve([(x+4*s,py+13*s),(px-side*11*s,py),(px,py)],ink.opacity(0.7),1.5*s,&c)
            for j in 0..<16 {let dx=(noise(j,i+1)-0.5)*31*s,dy=(noise(j,i+5)-0.5)*8*s
                curve([(px+dx,py+dy),(px+dx-4*s,py+dy-5*s),(px+dx-8*s,py+dy-6*s)],moss.opacity(0.6),0.6*s,&c)
                curve([(px+dx,py+dy),(px+dx+4*s,py+dy-6*s),(px+dx+7*s,py+dy-6*s)],ink.opacity(0.65),0.5*s,&c)
            }
        }
    }
    private static func leaf(_ x:Double,_ y:Double,_ length:Double,_ angle:Double,_ color:Color,_ c:inout GraphicsContext) {
        var g=c;g.translateBy(x:x,y:y);g.rotate(by:.radians(angle));var p=Path();p.move(to:.zero);p.addQuadCurve(to:point(length,0),control:point(length*0.45,-length*0.23));p.addQuadCurve(to:.zero,control:point(length*0.45,length*0.15));g.fill(p,with:.color(color))
    }
    private static func bamboo(_ x:Double,_ y:Double,_ s:Double,seed:Int,_ c:inout GraphicsContext) {
        for i in 0..<3 {let px=x+Double(i)*25*s,h=(108+Double(i)*19)*s
            curve([(px,y),(px-8*s,y-h*0.6),(px-14*s,y-h)],moss.opacity(0.75),1.5*s,&c)
            for j in 1..<6 {let yy=y-Double(j)*h/6,xx=px-Double(j)*2*s
                curve([(xx-2*s,yy),(xx,yy+1),(xx+2*s,yy)],ink.opacity(0.7),1*s,&c)
                for k in 0..<5 {let angle=Double(k)*0.51-2.3+Double((j+i)%2)*2.4
                    leaf(xx,yy-3,Double(14+k%3*5)*s,angle,ink.opacity(0.4+noise(k,j)*0.35),&c)
                }
            }
        }
    }
    private static func rock(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:inout GraphicsContext) {
        var p=Path();p.move(to:point(x,y));p.addCurve(to:point(x+w,y),control1:point(x-w*0.1,y-h*0.8),control2:point(x+w*0.6,y-h*1.3));p.closeSubpath()
        c.fill(p,with:.linearGradient(Gradient(colors:[blue.opacity(0.48),silk.opacity(0.1)]),startPoint:point(x,y-h),endPoint:point(x,y)));c.stroke(p,with:.color(ink.opacity(0.32)),lineWidth:0.65)
        for i in 0..<13 {let px=x+noise(i,4)*w;curve([(px,y-3),(px-4,y-h*0.3),(px+4,y-h*0.55)],ink.opacity(0.14),0.5,&c)}
    }
    private static func pavilion(_ x:Double,_ y:Double,scale s:Double,_ c:inout GraphicsContext) {
        let roof=Color(hex:0x5E6860)
        var p=Path();p.move(to:point(x-38*s,y-27*s));p.addQuadCurve(to:point(x-19*s,y-43*s),control:point(x-27*s,y-31*s));p.addQuadCurve(to:point(x+29*s,y-29*s),control:point(x+4*s,y-38*s));p.addLine(to:point(x+40*s,y-25*s));p.addQuadCurve(to:point(x-38*s,y-27*s),control:point(x,y-26*s));c.fill(p,with:.color(roof.opacity(0.84)))
        c.fill(Path(CGRect(x:x-29*s,y:y-27*s,width:57*s,height:29*s)),with:.color(silk.opacity(0.86)))
        for i in 0..<5 {let xx=x-28*s+Double(i)*14*s;curve([(xx,y+2*s),(xx,y-10*s),(xx,y-27*s)],ink.opacity(0.75),0.8*s,&c)}
        curve([(x-33*s,y+3*s),(x,y+4*s),(x+34*s,y+3*s)],ink.opacity(0.65),0.8*s,&c)
        for i in 0..<10 {let xx=x-25*s+Double(i)*5*s;curve([(xx,y-28*s),(xx+3*s,y-32*s),(xx+5*s,y-35*s)],silk.opacity(0.32),0.5*s,&c)}
    }
    private static func bridge(_ x:Double,_ y:Double,_ c:inout GraphicsContext) {
        curve([(x-48,y),(x,y-26),(x+48,y)],ink.opacity(0.5),2,&c)
        curve([(x-48,y-5),(x,y-30),(x+48,y-5)],ink.opacity(0.6),0.6,&c)
        for i in 0..<9 {let xx=x-44+Double(i)*11,yy=y-12*(1-pow((xx-x)/48,2));curve([(xx,yy),(xx,yy-3),(xx,yy-6)],ink.opacity(0.6),0.5,&c)}
    }
    private static func fan(_ c:inout GraphicsContext,paint:(inout GraphicsContext)->Void) {
        let rect=CGRect(x:63,y:19,width:228,height:228);let p=Path(ellipseIn:rect)
        var g=c;g.clip(to:p);g.fill(p,with:.radialGradient(Gradient(colors:[Color(hex:0xE4DDC5),silk]),center:point(170,120),startRadius:0,endRadius:135));paint(&g)
        c.stroke(p,with:.color(Color(hex:0xA99C80).opacity(0.6)),lineWidth:0.6)
        c.stroke(Path(ellipseIn:rect.insetBy(dx:2,dy:2)),with:.color(Color(hex:0xB9AC93).opacity(0.3)),lineWidth:0.35)
    }
    private static func lotus(_ x:Double,_ y:Double,scale s:Double,flower:Bool,dry:Bool,seed:Int,_ c:inout GraphicsContext) {
        let h=(70+noise(seed,4)*54)*s
        curve([(x,y),(x-8*s,y-h*0.5),(x+11*s,y-h)],moss.opacity(0.65),0.8*s,&c)
        let lx=x+8*s,ly=y-h
        if !dry {
            var leafPath=Path();leafPath.move(to:point(lx,ly+4*s))
            leafPath.addCurve(to:point(lx-35*s,ly-4*s),control1:point(lx-23*s,ly+17*s),control2:point(lx-47*s,ly+1*s))
            leafPath.addCurve(to:point(lx+36*s,ly-3*s),control1:point(lx-35*s,ly-27*s),control2:point(lx+27*s,ly-31*s))
            leafPath.addCurve(to:point(lx,ly+4*s),control1:point(lx+51*s,ly+10*s),control2:point(lx+9*s,ly+18*s))
            c.fill(leafPath,with:.linearGradient(Gradient(colors:[moss.opacity(0.78),blue.opacity(0.37)]),startPoint:point(lx,ly-20*s),endPoint:point(lx,ly+15*s)))
            for i in 0..<8 {let a=Double(i) * .pi / 4;curve([(lx,ly),(lx+cos(a)*13*s,ly+sin(a)*7*s),(lx+cos(a)*30*s,ly+sin(a)*13*s)],silk.opacity(0.33),0.45,&c)}
        } else {curve([(lx-22*s,ly),(lx,ly-7*s),(lx+21*s,ly+5*s)],ink.opacity(0.55),1.2,&c)}
        if flower {
            let fx=x-17*s,fy=y-h-23*s
            curve([(x-5*s,y),(fx+6*s,fy+28*s),(fx,fy)],moss.opacity(0.7),0.6,&c)
            for i in 0..<7 {let a=Double(i)*0.32-2.55;petal(fx,fy,24*s,a,Color(hex:0xE2C7BC),&c)}
            disc(fx,fy,2*s,Color(hex:0xB5A078),&c)
        }
    }
    private static func petal(_ x:Double,_ y:Double,_ size:Double,_ angle:Double,_ color:Color,_ c:inout GraphicsContext) {
        var g=c;g.translateBy(x:x,y:y);g.rotate(by:.radians(angle));var p=Path();p.move(to:.zero);p.addCurve(to:point(size,0),control1:point(size*0.3,-size*0.38),control2:point(size*0.85,-size*0.3));p.addCurve(to:.zero,control1:point(size*0.8,size*0.35),control2:point(size*0.3,size*0.25));g.fill(p,with:.linearGradient(Gradient(colors:[color.opacity(0.8),Color(hex:0xF7F2E7)]),startPoint:.zero,endPoint:point(size,0)));g.stroke(p,with:.color(Color(hex:0xA28C72).opacity(0.5)),lineWidth:0.4)
    }
    private static func flowerBranch(_ x:Double,_ y:Double,_ s:Double,blossom:Color,seed:Int,_ c:inout GraphicsContext) {
        curve([(x,y),(x+38*s,y-42*s),(x+103*s,y-66*s),(x+145*s,y-132*s)],ink.opacity(0.82),2.4*s,&c)
        curve([(x-1*s,y),(x+38*s,y-43*s),(x+103*s,y-67*s),(x+145*s,y-132*s)],silk.opacity(0.6),0.55*s,&c)
        for i in 0..<6 {
            let t=0.2+Double(i)*0.12,op=1-t
            let b1=3.0*op*op*t,b2=3.0*op*t*t,b3=t*t*t
            let px=x+s*(b1*38.0+b2*103.0+b3*145.0)
            let py=y-s*(b1*42.0+b2*66.0+b3*132.0)
            let side=i%2 == 0 ? -1.0:1.0,fx=px+side*14*s,fy=py-(18+noise(i,seed)*13)*s
            curve([(px,py),(fx-4*s,fy+10*s),(fx,fy)],ink.opacity(0.65),0.7*s,&c)
            if seed == 0 {
                // Magnolia: large, upright ivory petals with fine warm outlines.
                for j in 0..<6 {petal(fx,fy,(15+noise(i,j)*7)*s,Double(j)*0.35-2.4,blossom,&c)}
            } else {
                for j in 0..<5 {let a=Double(j)*2 * .pi/5;petal(fx,fy,(7+noise(i,seed)*5)*s,a,blossom,&c)}
            }
            disc(fx,fy,1.1*s,Color(hex:0xA68A55),&c)
            leaf(px+6*s,py-3*s,15*s,-0.5,moss.opacity(0.7),&c)
            if i%2 == 0 {leaf(px+2*s,py-3*s,12*s,-2.4,moss.opacity(0.5),&c)}
        }
    }
    private static func sparrow(_ x:Double,_ y:Double,_ s:Double,_ c:inout GraphicsContext) {
        var g=c;g.translateBy(x:x,y:y);g.rotate(by:.degrees(-12))
        g.fill(Path(ellipseIn:CGRect(x:-7*s,y:-4*s,width:15*s,height:9*s)),with:.color(Color(hex:0x9B8D73)))
        g.fill(Path(ellipseIn:CGRect(x:-3*s,y:-3*s,width:9*s,height:5*s)),with:.color(ink.opacity(0.75)))
        disc(7*s,-5*s,4*s,Color(hex:0x80755E),&g);disc(8*s,-6*s,0.6*s,ink,&g)
        curve([(-5*s,0),(-12*s,-1*s),(-17*s,1*s)],ink.opacity(0.85),1.5*s,&g)
        curve([(10*s,-5*s),(13*s,-4*s),(11*s,-3*s)],ink,0.6,&g)
        curve([(0,4*s),(0,7*s),(3*s,8*s)],ink.opacity(0.65),0.6,&g)
    }
    private static func egret(_ x:Double,_ y:Double,_ s:Double,_ c:inout GraphicsContext) {
        c.fill(Path(ellipseIn:CGRect(x:x-8*s,y:y-14*s,width:19*s,height:9*s)),with:.color(Color(hex:0xFAF7EE)))
        curve([(x+6*s,y-12*s),(x+15*s,y-26*s),(x+3*s,y-33*s),(x+11*s,y-37*s)],Color(hex:0xF7F3E7),3.7*s,&c)
        curve([(x+11*s,y-37*s),(x+16*s,y-36*s),(x+23*s,y-34*s)],ink.opacity(0.7),0.65*s,&c)
        disc(x+12*s,y-37*s,0.65*s,ink,&c)
        for i in 0..<2 {let xx=x+Double(i)*6*s;curve([(xx,y-6*s),(xx+1*s,y+3*s),(xx-1*s,y+11*s)],ink.opacity(0.65),0.65*s,&c)}
    }
    private static func inscription(_ s:PaperSceneStyle,_ c:inout GraphicsContext) {
        let font=Font.custom("STSongti-SC-Regular",size:15)
        for (i,ch) in s.name.enumerated() {c.draw(Text(String(ch)).font(font).foregroundStyle(ink.opacity(0.85)),at:point(329,33+Double(i)*19))}
        let words="风来有信"
        for (i,ch) in words.enumerated() {c.draw(Text(String(ch)).font(.custom("STSongti-SC-Regular",size:6.5)).foregroundStyle(ink.opacity(0.55)),at:point(310,36+Double(i)*9))}
        let sealY=36+Double(s.name.count)*19
        let stamp=Path(roundedRect:CGRect(x:322,y:sealY,width:14,height:23),cornerRadius:0.5)
        c.fill(stamp,with:.color(seal.opacity(0.8)))
        c.draw(Text("气").font(.custom("STSongti-SC-Regular",size:8)).foregroundStyle(silk),at:point(329,sealY+6))
        c.draw(Text("象").font(.custom("STSongti-SC-Regular",size:8)).foregroundStyle(silk),at:point(329,sealY+16))
    }
}
