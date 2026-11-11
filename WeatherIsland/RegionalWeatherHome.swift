import SwiftUI
import Charts

struct RegionalWeatherHome: View {
    let app: WeatherApplication
    let place: WeatherPlace
    var preview = false
    var snapshot = false
    var active = true
    var entryReady = true
    var locate: () -> Void = {}
    var locating = false
    var resolvingLocation = false
    var waitingLocationName = false
    @State private var weather: WeatherStore
    @State private var air: AirQualityStore
    @State private var appeared = false
    @State private var detail: WeatherReport?
    @State private var theatre = false
    @State private var insightSheet: HomeWeatherSheet?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var typeSize

    init(app:WeatherApplication,preview:Bool=false,snapshot:Bool=false,active:Bool=true,entryReady:Bool=true,locate:@escaping()->Void={},locating:Bool=false,resolvingLocation:Bool=false,waitingLocationName:Bool=false){
        self.app=app;place=app.selected;self.preview=preview;self.snapshot=snapshot;self.active=active;self.entryReady=entryReady;self.locate=locate;self.locating=locating;self.resolvingLocation=resolvingLocation;self.waitingLocationName=waitingLocationName
        _weather=State(initialValue:app.weather(for:app.selected));_air=State(initialValue:app.air(for:app.selected))
    }
    private var data:WeatherDataset? {preview ? RegionalPreview.dataset(place:place) : weather.dataset}
    private var report:WeatherReport? {data?.current}
    private var style:PaperSceneStyle {app.style}
    private var motion:Bool {active && entryReady && detail == nil && insightSheet == nil && !theatre && phase == .active && !snapshot}
    private func local(_ date:Date,_ format:String)->String {WeatherClock.string(date,format,timeZone:data?.timeZoneIdentifier ?? place.timeZoneIdentifier)}

    var body: some View {
        Group {
            if snapshot {content}
            else {
                ScrollView {content}
                    .scrollIndicators(.hidden)
                    .refreshable {await refresh()}
            }
        }
        .background(WeatherPalette.paper.ignoresSafeArea())
        .foregroundStyle(WeatherPalette.ink)
        .islandNavigationStyle()
        .navigationDestination(item:$detail){report in WeatherDetailView(report:report, sceneStyle:style, animate:active)}
        .sheet(isPresented:$theatre){WeatherExplorerView(selected:report?.kind ?? .partlyCloudy,sceneStyle:style,demoPlace:place){_ in}}
        .sheet(item: $insightSheet) { selection in
            if let data {
                HomeWeatherInsightSheet(selection: selection, data: data, quality: quality,
                    airCached: air.cached, airFailed: air.failed,
                    weatherCached: weather.cached || weather.error != nil, preview: preview, style: style)
            }
        }
        .task(id:entryReady){guard entryReady else{return};withAnimation(reduceMotion ? nil : .easeOut(duration:0.55)){appeared=true}}
        .onChange(of:app.locationRefreshID){_,_ in if active,!preview{Task{await refresh()}}}
        .onChange(of:active){_,value in
            if value,!preview,Date.now.timeIntervalSince(data?.fetchedAt ?? .distantPast)>600{Task{await refresh()}}
        }
    }
    private func refresh() async {
        guard !preview else{return}
        async let forecast:Void=weather.refresh()
        async let quality:Void=air.refresh()
        _=await(forecast,quality)
    }
    private var content:some View {
        VStack(alignment:.leading,spacing:24){
            header
            if data != nil && (weather.cached || weather.error != nil) {status}
            if let report,let data {
                hero(report)
                summary(report)
                dailyCompanion(data)
                chapter("01", WL("未来怎么变"), WL("按地区当地时间排列"))
                trend(data)
                week(data)
                chapter("02", WL("此刻的环境"), WL("天气与空气质量独立更新"))
                airCard
                metrics(report)
                chapter("03", WL("把今天过好"), WL("日照与生活建议"))
                daylight(report)
                life(report)
                sources
            }else{loadingState}
        }
        .padding(.horizontal,24).padding(.top,14).padding(.bottom,28)
        .frame(maxWidth:720)
        .frame(maxWidth:.infinity)
    }
    private var header:some View {
        HStack(alignment:.center,spacing:10){
            WeatherBrandMark().frame(width:34,height:34)
            Button {app.presentCitySearch()} label:{
                VStack(alignment:.leading,spacing:4){
                    HStack(spacing:5){Text(place.title).font(WeatherTypography.display(22)).lineLimit(2);Image(systemName:"chevron.down").font(.system(size:11,weight:.bold))}
                    Text(place.isCurrentLocation ? (resolvingLocation ? WL("正在解析地区 · 天气同步加载") : !place.hasCityName ? (waitingLocationName ? WL("地区名称待更新 · 自动重试中") : WL("正在获取地区名称 · 坐标天气")) : place.approximate ? WL("近似位置 · 不展示区县") : WL("我的位置 · 坐标天气")) : place.subtitle)
                        .font(.system(size:12)).foregroundStyle(WeatherPalette.secondary).lineLimit(1)
                }.multilineTextAlignment(.leading)
            }.buttonStyle(.plain).accessibilityLabel(WLF("切换城市，当前%1$@", String(describing: place.title))).accessibilityIdentifier("home.city")
            Spacer(minLength:2)
            Button(action:locate){Group{if locating{ProgressView().tint(WeatherPalette.ink)}else{Image(systemName:place.isCurrentLocation ? "location.fill":"location")}}.font(.system(size:20)).frame(width:40,height:44)}
                .buttonStyle(.plain).disabled(locating).accessibilityLabel(WL("定位我的位置"))
            Button {theatre=true} label:{Image(systemName:"wind").font(.system(size:20)).frame(width:40,height:40).background(Circle().stroke(WeatherPalette.line,lineWidth:0.7))}
                .buttonStyle(.plain).accessibilityLabel(WL("打开天气剧场"))
        }
    }
    private func hero(_ report:WeatherReport)->some View {
        VStack(alignment:.leading,spacing:0){
            HStack{
                Text(local(report.metrics?.time ?? .now,"M月d日 EEEE")).font(.system(size:12))
                Spacer()
                Text(WL("观天 · 知时 / °C")).font(.system(size:11,design:.monospaced))
            }.foregroundStyle(WeatherPalette.secondary)
            Button { present(.feelsLike) } label: {
                WeatherTemperatureHeader(report: report)
            }.buttonStyle(.plain).accessibilityHint(WL("轻点查看气温与体感说明"))
                .padding(.top, 14).padding(.bottom, 14)
            quickLook.padding(.bottom, 18)
            Button {detail=report} label:{
                PaperCityScene(style:style,kind:report.kind,animate:motion)
                    .aspectRatio(360.0 / 248, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius:16))
                    .overlay(RoundedRectangle(cornerRadius:16).stroke(WeatherPalette.ink.opacity(0.12),lineWidth:0.6))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .medium))
                            .padding(10).background(.regularMaterial, in: Circle()).padding(12)
                    }
            }.buttonStyle(.plain).accessibilityLabel(WLF("%1$@，%2$@。打开天气详情", String(describing: place.title), String(describing: report.kind.name)))
            if let time=report.metrics?.time {Text(WLF("天气时刻 %1$@ · %2$@", String(describing: local(time,"HH:mm")), String(describing: weather.cached ? WL("缓存预报"):WL("当地时间")))).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary).padding(.top,12)}
            HStack{
                Text(style.artDirection + WL(" · 点击画境查看详情"))
                Spacer()
                Text(app.automaticScene ? WL("跟随地区") : WL("手动选择"))
            }.font(.system(size:12)).foregroundStyle(WeatherPalette.secondary).padding(.top,10)
        }
        .opacity(snapshot || appeared ? 1:0)
        .offset(y:snapshot || appeared ? 0:8)
    }
    private func present(_ topic: HomeWeatherTopic, report: WeatherReport? = nil) {
        insightSheet = HomeWeatherSheet(topic: topic, report: report)
    }
    private var quickLook: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { glanceButtons }
            VStack(alignment: .leading, spacing: 8) { glanceButtons }
        }
    }
    @ViewBuilder private var glanceButtons: some View {
        if let data {
            let insights = HomeWeatherInsights(data: data, referenceTime: preview ? nil : .now)
            glance("umbrella", WL("降水"), insights.rainChance.map { "\(Int($0.rounded()))%" } ?? "—", topic: .rain)
            glance("sun.max", WL("紫外线"), data.daily.first?.uvLevel ?? "—", topic: .uv)
            glance("aqi.medium", WL("空气"), quality?.label ?? WL("待更新"), topic: .air)
        }
    }
    private func glance(_ icon: String, _ title: String, _ value: String, topic: HomeWeatherTopic) -> some View {
        Button { present(topic) } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(title).foregroundStyle(WeatherPalette.secondary)
                Text(value).fontWeight(.medium).lineLimit(1)
            }.font(.system(size: 11)).padding(.horizontal, 10).padding(.vertical, 10)
                .background(Capsule().fill(WeatherPalette.lime.opacity(0.28)))
                .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("home.glance.\(topic.id)")
            .accessibilityLabel(topic == .rain ? WLF("未来6小时最高降水概率，%1$@", String(describing: value)) : "\(title)，\(value)")
    }
    private func summary(_ report:WeatherReport)->some View {
        Button { present(.briefing) } label: {
            HStack(alignment:.top,spacing:13){
                Text(WL("今日\n手记")).font(.system(size:11,weight:.semibold)).lineSpacing(3).foregroundStyle(WeatherPalette.accent)
                Rectangle().fill(WeatherPalette.line).frame(width:1,height:44)
                VStack(alignment:.leading,spacing:8){
                    Text(report.kind.poem).font(WeatherTypography.display(20))
                    Text(summaryText(report)).font(.system(size:12)).lineSpacing(4).foregroundStyle(WeatherPalette.secondary).fixedSize(horizontal:false,vertical:true)
                    HStack { Text(WL("天气生活指南 · 出门清单")); Spacer(); Image(systemName: "arrow.up.right") }
                        .font(.system(size:11)).foregroundStyle(WeatherPalette.accent).padding(.top, 3)
                }
            }.padding(18).frame(maxWidth:.infinity,alignment:.leading)
                .background(RoundedRectangle(cornerRadius:18).fill(WeatherPalette.surface))
                .overlay(RoundedRectangle(cornerRadius:18).stroke(WeatherPalette.line.opacity(0.5),lineWidth:0.6))
        }.buttonStyle(.plain).accessibilityIdentifier("home.briefing")
    }
    private func dailyCompanion(_ data: WeatherDataset) -> some View {
        let insights = HomeWeatherInsights(data: data, referenceTime: preview ? nil : .now)
        return Button { present(.outdoor) } label: {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: insights.outdoorWindow == nil ? "cup.and.saucer" : "leaf")
                    .font(.system(size: 24, weight: .light)).foregroundStyle(WeatherPalette.accent)
                    .frame(width: 42, height: 44).background(Circle().fill(WeatherPalette.surface))
                VStack(alignment: .leading, spacing: 6) {
                    Text(WL("给生活留一点空白")).font(WeatherTypography.display(20))
                    Text(insights.outdoorWindow == nil ? WL("一杯热茶，也是一种好天气") : insights.windowLabel + WL(" · 散步时间参考"))
                        .font(.system(size: 12)).foregroundStyle(WeatherPalette.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(WL("看看户外安排")).font(.system(size: 11, weight: .medium)).foregroundStyle(WeatherPalette.accent)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(WeatherPalette.secondary).padding(.top, 16)
            }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 18).fill(WeatherPalette.lime.opacity(0.3)))
        }.buttonStyle(.plain).accessibilityIdentifier("home.outdoor")
    }
    private func summaryText(_ r:WeatherReport)->String {
        let change=r.high-r.low
        let rain=data?.daily.first?.metrics?.probability.map{WLF("全天最高降水概率 %1$@%。", String(describing: Int($0)))} ?? ""
        return WLF("今天温差 %1$@°。%2$@%3$@", String(describing: change), String(describing: rain), String(describing: data?.daily.first?.uvAdvice ?? r.uvAdvice))
    }
    private func chapter(_ number:String,_ name:String,_ note:String)->some View {
        VStack(alignment:.leading,spacing:8){
            HStack(spacing:10){Text(number).font(.system(size:11,design:.serif)).foregroundStyle(WeatherPalette.accent).padding(7).overlay(Rectangle().stroke(WeatherPalette.accent.opacity(0.5),lineWidth:0.7));Text(name).font(WeatherTypography.display(25));Spacer()}
            Text(note).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)
        }.padding(.top,12)
    }
    private func title(_ name:String,_ english:String)->some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(name).font(WeatherTypography.display(21))
                    Text(english).font(.system(size:11,design:.monospaced)).tracking(WeatherLocalization.isChinese ? 0.5 : 0).foregroundStyle(WeatherPalette.secondary)
                }
            } else {
                HStack(alignment:.firstTextBaseline){Text(name).font(WeatherTypography.display(21));Spacer();Text(english).font(.system(size:11,design:.monospaced)).tracking(WeatherLocalization.isChinese ? 0.5 : 0).foregroundStyle(WeatherPalette.secondary)}
            }
        }
    }
    private func trend(_ data:WeatherDataset)->some View {
        VStack(alignment:.leading,spacing:15){
            title(WL("未来 24 小时"),WL("点击图表或时段"))
            HStack(spacing:15){Label(WL("气温 °C"),systemImage:"line.diagonal").foregroundStyle(WeatherPalette.ink);Label(WL("降水概率 %"),systemImage:"drop.fill").foregroundStyle(Color(hex:0x6B8D83));Spacer();Text(WL("轻点查看")).foregroundStyle(WeatherPalette.secondary)}.font(.system(size:12))
            Chart {
                ForEach(data.next24Hours){r in
                    if let t=r.metrics?.time{LineMark(x:.value(WL("时间"),t),y:.value(WL("温度"),r.temperature)).interpolationMethod(.catmullRom).foregroundStyle(WeatherPalette.ink).lineStyle(StrokeStyle(lineWidth:2));PointMark(x:.value(WL("时间"),t),y:.value(WL("温度"),r.temperature)).symbolSize(9).foregroundStyle(WeatherPalette.accent)}
                }
            }
            .chartYScale(domain:chartRange(data)).chartXAxis{
                AxisMarks(values:.stride(by:.hour,count:6)){v in AxisGridLine(stroke:StrokeStyle(lineWidth:0.4,dash:[2,3]));AxisValueLabel{if let t=v.as(Date.self){Text(local(t,local(t,"d") == local(data.current.metrics?.time ?? data.fetchedAt,"d") ? "HH时":"M/d HH时")).font(.system(size:12))}}}
            }
            .chartYAxis{AxisMarks(position:.leading,values:.automatic(desiredCount:3)){v in AxisGridLine(stroke:StrokeStyle(lineWidth:0.5,dash:[2,3]));AxisValueLabel{if let n=v.as(Int.self){Text("\(n)°").font(.system(size:12))}}}}
            .chartOverlay {proxy in GeometryReader{geometry in Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture{point in
                guard let frame=proxy.plotFrame else{return};let x=point.x-geometry[frame].origin.x
                if let date:Date=proxy.value(atX:x),let r=data.next24Hours.min(by:{abs(($0.metrics?.time ?? .distantPast).timeIntervalSince(date))<abs(($1.metrics?.time ?? .distantPast).timeIntervalSince(date))}){present(.forecast, report: r)}
            }}}
            .frame(height:134)
            .accessibilityLabel(WL("24小时气温趋势，可在下方时段卡片查看详情"))
            if data.next24Hours.contains(where:{$0.metrics?.probability != nil}) {
            Chart {
                ForEach(data.next24Hours) { r in
                    if let t=r.metrics?.time,let chance=r.metrics?.probability {
                        BarMark(x:.value(WL("时间"),t,unit:.hour),y:.value(WL("降水概率"),chance),width:.ratio(0.55)).foregroundStyle(Color(hex:0x6B8D83).opacity(0.85)).cornerRadius(2)
                    }
                }
            }.chartYScale(domain:0...100).chartXAxis(.hidden)
                .chartYAxis{AxisMarks(position:.leading,values:[0,100]){value in AxisValueLabel{if let n=value.as(Int.self){Text("\(n)%").font(.system(size:12))}}}}
                .frame(height:58).accessibilityLabel(WL("24小时降水概率，单位百分比"))
            } else {
                Label(WL("降水概率暂无预报"),systemImage:"drop").font(.system(size:12))
                    .foregroundStyle(WeatherPalette.secondary).frame(maxWidth:.infinity,alignment:.leading).frame(height:58)
            }
            horizontal {
                HStack(spacing:11){ForEach(snapshot ? Array(data.next24Hours.prefix(6)) : data.next24Hours){r in
                    Button {present(.forecast, report: r)} label:{VStack(spacing:9){Text(hourLabel(r,current:data.current)).frame(height:28).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary);Image(systemName:r.kind.symbol).symbolRenderingMode(.hierarchical).foregroundStyle(WeatherPalette.ink).font(.system(size:19)).frame(height:24);Text("\(r.temperature)°").font(.system(size:14,weight:.medium));Text(r.metrics?.probability.map{"\(Int($0))%"} ?? "—").font(.system(size:12)).foregroundStyle(Color(hex:0x59776A))}.frame(width:43)}.buttonStyle(.plain).accessibilityIdentifier("home.hour.\(r.id)")
                }}.padding(.vertical,2)
            }.scrollIndicators(.hidden)
        }.padding(18).background(RoundedRectangle(cornerRadius:23).fill(WeatherPalette.surface))
    }
    private func hourLabel(_ report:WeatherReport,current:WeatherReport)->String {
        guard report.id != current.id,let time=report.metrics?.time else{return WL("现在")}
        if local(time,"yyyy-MM-dd") != local(current.metrics?.time ?? time,"yyyy-MM-dd") {return WL("明日\n") + local(time,"HH时")}
        return local(time,"HH时")
    }
    private func chartRange(_ data:WeatherDataset)->ClosedRange<Int>{let values=data.next24Hours.map(\.temperature);return ((values.min() ?? 0)-2)...((values.max() ?? 1)+2)}
    private func week(_ data:WeatherDataset)->some View {
        VStack(alignment:.leading,spacing:14){
            title(WL("未来 7 天"),WL("每日最高 / 最低"))
            horizontal {HStack(spacing:9){ForEach(Array((snapshot ? Array(data.daily.prefix(3)) : data.daily).enumerated()),id:\.element.id){i,r in
                Button {present(.forecast, report: r)} label:{
                    VStack(alignment:.leading,spacing:12){
                        HStack{Text(i==0 ? WL("今天"):local(r.metrics!.time,"EEE")).font(.system(size:12,weight:.medium));Spacer();Text(String(format:"%02d",i+1)).font(.system(size:11,design:.monospaced)).opacity(0.5)}
                        Image(systemName:r.kind.symbol).font(.system(size:23,weight:.light)).frame(height:28)
                        Rectangle().fill(WeatherPalette.ink.opacity(0.15)).frame(height:0.5)
                        Text(WL("最高")).font(.system(size:11)).opacity(0.85)
                        Text("\(r.high)°").font(.system(size:26,weight:.light,design:.serif))
                        rangeBar(r,data:data,first:i==0)
                        Text(WLF("最低 %1$@°", String(describing: r.low))).font(.system(size:12)).opacity(0.65).lineLimit(1)
                        Text(r.metrics?.probability.map{WLF("降水 %1$@%", String(describing: Int($0)))} ?? WL("降水 —")).font(.system(size:12)).opacity(0.65)
                    }.foregroundStyle(i==0 ? WeatherPalette.paper:WeatherPalette.ink).padding(13).frame(width:99,alignment:.leading)
                        .background(RegionalTicketShape().fill(i==0 ? WeatherPalette.ink:WeatherPalette.lime.opacity(0.27)))
                }.buttonStyle(.plain).accessibilityIdentifier("home.day.\(i)")
            }}}.scrollIndicators(.hidden)
        }
    }
    @ViewBuilder private func horizontal<Content:View>(@ViewBuilder content:()->Content)->some View {
        if snapshot {content().frame(maxWidth:.infinity,alignment:.leading).clipped()}
        else {ScrollView(.horizontal){content()}.scrollIndicators(.hidden)}
    }
    private func rangeBar(_ r:WeatherReport,data:WeatherDataset,first:Bool)->some View {
        let minTemp=data.daily.map(\.low).min() ?? r.low,maxTemp=data.daily.map(\.high).max() ?? r.high
        let span=Double(max(maxTemp-minTemp,1)),fraction=Double(max(r.high-r.low,1))/span
        return GeometryReader{g in
            ZStack(alignment:.leading){Capsule().fill(first ? WeatherPalette.paper.opacity(0.16):WeatherPalette.ink.opacity(0.08));Capsule().fill(LinearGradient(colors:[Color(hex:0x9CBBC6),Color(hex:0xDDAC82)],startPoint:.leading,endPoint:.trailing)).frame(width:snapshot || appeared ? max(4,g.size.width*fraction):0).offset(x:g.size.width*Double(r.low-minTemp)/span)}
        }.frame(height:4).animation(reduceMotion ? nil:.easeOut(duration:0.5),value:appeared)
    }
    private var quality:AirQualityReading? {preview ? AirQualityReading(usAQI:42,pm25:12,pm10:23,time:RegionalPreview.date,fetchedAt:RegionalPreview.date):air.reading}
    private var airCard:some View {
        VStack(alignment: .leading, spacing: 10) {
        Button { present(.air) } label: {
        VStack(alignment:.leading,spacing:15){
            title(WL("空气质量"),WL("美国 AQI · 轻点了解 ↗"))
            HStack(alignment:.center,spacing:18){
                ZStack{Circle().stroke(WeatherPalette.line,lineWidth:5);Circle().trim(from:0,to:min((quality?.usAQI ?? 0)/300,1)).stroke(quality?.tint ?? WeatherPalette.secondary,style:StrokeStyle(lineWidth:5,lineCap:.round)).rotationEffect(.degrees(-90));VStack(spacing:3){Text(quality?.usAQI.map{String(Int($0))} ?? "—").font(.system(size:29,weight:.light,design:.serif));Text("US AQI").font(.system(size:10,weight:.semibold,design:.monospaced))}}.frame(width:77,height:77)
                VStack(alignment:.leading,spacing:8){Text(quality?.label ?? (air.loading ? WL("正在读取空气质量"):WL("暂无数据"))).font(.system(size:15,weight:.medium));Text(quality?.advice ?? WL("天气仍可正常查看，空气质量稍后再试。")).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary).lineSpacing(3)}
            }
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { pollutant("PM2.5",quality?.pm25); pollutant("PM10",quality?.pm10) }
            } else {
                HStack{pollutant("PM2.5",quality?.pm25);Spacer();pollutant("PM10",quality?.pm10)}
            }
            Text(WLF("美国 AQI 标准%1$@%2$@", String(describing: air.cached ? WL(" · 缓存"):""), String(describing: air.failed ? WL(" · 更新失败"):""))).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)
            if let quality {Text(WLF("预报时刻 %1$@ · 当地时间", String(describing: local(quality.time,"M/d HH:mm")))).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)}

        }.padding(18).background(RoundedRectangle(cornerRadius:23).stroke(WeatherPalette.line,lineWidth:0.8))
        }.buttonStyle(.plain).accessibilityIdentifier("home.air")
        if air.failed && !preview { Button(WL("重新获取空气质量")) { Task { await air.refresh() } }.font(.system(size: 12)).buttonStyle(.plain) }
        }
    }
    private func pollutant(_ name:String,_ value:Double?)->some View{HStack(alignment:.firstTextBaseline,spacing:6){Text(name).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary);Text(value.map{String(format:"%.1f",$0)} ?? "—").font(.system(size:18,weight:.light));Text("µg/m³").font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)}}
    private func metrics(_ r:WeatherReport)->some View {
        VStack(spacing:14){title(WL("天气详情"),WL("当前 + 最近小时预报"))
            LazyVGrid(columns:typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()),GridItem(.flexible())],spacing:11){
                metric(WL("风速 / 风向"),r.metrics?.wind.map{String(format:"%.0f km/h",$0)} ?? "—",windDirection(r.metrics?.windDirection),"wind")
                metric(WL("相对湿度"),r.metrics?.humidity.map{"\(Int($0))%"} ?? "—",WL("当前相对湿度"),"humidity")
                metric(WL("紫外线"),(data?.daily.first ?? r).uvText,WL("今日最高 · ") + (data?.daily.first ?? r).uvLevel,"sun.max")
                metric(WL("能见度"),r.metrics?.visibility.map{String(format:"%.1f km",$0)} ?? "—",WL("相近时刻预报"),"eye")
                metric(WL("降水量"),r.metrics?.precipitation.map{String(format:"%.1f",$0)} ?? "—",r.metrics?.localizedPrecipitationUnit ?? "—","drop")
                metric(WL("体感温度"),"\(r.feelsLike)°",WLF("当前气温 %1$@°", String(describing: r.temperature)),"thermometer.medium")
            }
        }
    }
    private func metric(_ name:String,_ value:String,_ note:String,_ icon:String)->some View{
        let topic: HomeWeatherTopic = ["wind": .wind, "humidity": .humidity, "sun.max": .uv, "eye": .visibility, "drop": .precipitation, "thermometer.medium": .feelsLike][icon] ?? .forecast
        return Button { present(topic) } label: { VStack(alignment:.leading,spacing:10){HStack { Label(name,systemImage:icon); Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.system(size: 9)) }.font(.system(size:12)).foregroundStyle(WeatherPalette.secondary);Text(value).font(.system(size:25,weight:.light,design:.serif)).minimumScaleFactor(0.7).lineLimit(1);Text(note).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(RoundedRectangle(cornerRadius:19).fill(WeatherPalette.surface)) }.buttonStyle(.plain).accessibilityIdentifier("home.metric.\(topic.id)")
    }
    private func windDirection(_ value:Double?)->String{guard let value else{return WL("风向暂无数据")};return [WL("北风"),WL("东北风"),WL("东风"),WL("东南风"),WL("南风"),WL("西南风"),WL("西风"),WL("西北风")][Int((value.truncatingRemainder(dividingBy:360)+360+22.5)/45)%8]}
    private func daylight(_ r:WeatherReport)->some View {
        let sunrise=r.metrics?.sunrise,sunset=r.metrics?.sunset
        let progress=DaylightProgress.fraction(at:preview ? RegionalPreview.date:Date.now,sunrise:sunrise,sunset:sunset)
        return Button { present(.daylight) } label: {
        VStack(alignment:.leading,spacing:16){
            title(WL("日出与日落"),WL("轻点追寻日光 ↗"))
            GeometryReader{geometry in
                let width=geometry.size.width
                ZStack(alignment:.topLeading){
                    Path{p in p.move(to:CGPoint(x:8,y:67));p.addQuadCurve(to:CGPoint(x:width-8,y:67),control:CGPoint(x:width/2,y:-46))}.stroke(WeatherPalette.accent.opacity(0.5),style:StrokeStyle(lineWidth:1,dash:[3,4]))
                    if let progress{Image(systemName:"sun.max.fill").foregroundStyle(WeatherPalette.accent).font(.system(size:23)).position(x:8+(width-16)*progress,y:67-226*progress*(1-progress))}
                    Rectangle().fill(WeatherPalette.line).frame(height:0.8).offset(y:68)
                }
            }.frame(height:76)
            HStack{Label(WL("日出 ") + (sunrise.map{local($0,"HH:mm")} ?? "—"),systemImage:"sunrise");Spacer();Text(DaylightProgress.duration(sunrise:sunrise,sunset:sunset)).foregroundStyle(WeatherPalette.secondary);Spacer();Label(WL("日落 ") + (sunset.map{local($0,"HH:mm")} ?? "—"),systemImage:"sunset")}.font(.system(size:12,weight:.medium))
            Text(WLF("当地时间 · %1$@", String(describing: data?.timeZoneIdentifier ?? place.timeZoneIdentifier))).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)
        }.padding(18).background(RoundedRectangle(cornerRadius:23).fill(WeatherPalette.lime.opacity(0.22)))
        }.buttonStyle(.plain).accessibilityIdentifier("home.daylight")
    }
    private func life(_ r:WeatherReport)->some View{
        VStack(alignment:.leading,spacing:14){title(WL("生活建议"),WL("根据预报生成"))
            advice("01",WL("穿衣手记"),r.outfitTitle+"。"+r.outfitAdvice,"tshirt")
            advice("02",WL("通勤备忘"),r.commute,"figure.walk")
            advice("03",WL("户外灵感"),r.kind.outing,"leaf")
            advice("04",WL("防晒提醒"),(data?.daily.first ?? r).uvAdvice,"sun.max")
            Text(WL("生活建议由本地规则结合预报生成，仅供日常参考。")).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)
        }
    }
    private func advice(_ index:String,_ title:String,_ text:String,_ symbol:String)->some View{
        let topic: HomeWeatherTopic = ["tshirt": .outfit, "figure.walk": .commute, "leaf": .outdoor, "sun.max": .uv][symbol] ?? .briefing
        return Button { present(topic) } label: {
        HStack(alignment:.top,spacing:13){Image(systemName:symbol).font(.system(size:21,weight:.light)).frame(width:30,height:30);VStack(alignment:.leading,spacing:7){HStack{Text(title).font(.system(size:13,weight:.semibold));Spacer();Image(systemName:"arrow.up.right").font(.system(size:11)).foregroundStyle(WeatherPalette.accent)};Text(text).font(.system(size:12)).lineSpacing(4).foregroundStyle(WeatherPalette.secondary).fixedSize(horizontal:false,vertical:true)}}.padding(16).background(RoundedRectangle(cornerRadius:18).fill(WeatherPalette.surface))
        }.buttonStyle(.plain).accessibilityIdentifier("home.life.\(topic.id)")
    }
    private var sources:some View{
        VStack(alignment:.leading,spacing:7){
            Rectangle().fill(WeatherPalette.line).frame(height:0.8).padding(.bottom,6)
            if snapshot {Text(WL("天气 · Open-Meteo ↗"))} else {WeatherWebLink(WL("天气 · Open-Meteo"),destination:URL(string:"https://open-meteo.com/")!)}
            if let data{Text(WLF("%1$@于 %2$@ · 当地时间", String(describing: weather.cached ? WL("缓存"):WL("更新")), String(describing: local(data.fetchedAt,"M/d HH:mm"))))}
            if snapshot {Text(WL("空气质量 · Open-Meteo / CAMS ↗"))} else {WeatherWebLink(WL("空气质量 · Open-Meteo / CAMS"),destination:URL(string:"https://open-meteo.com/en/docs/air-quality-api")!)}
            if let quality{Text(WLF("空气%1$@于 %2$@ · 预报时刻 %3$@", String(describing: air.cached ? WL("缓存"):WL("更新")), String(describing: local(quality.fetchedAt,"M/d HH:mm")), String(describing: local(quality.time,"HH:mm"))))}
            Text(WL("视觉 · 气象岛原创宋韵画境"))
            Text(preview ? WL("离线设计示例 · Preview 不联网"):WL("坐标对应模型预报，非气象站实测或官方预警。"))
            Text(WL("一座小岛 · 万千晴雨")).tracking(WeatherLocalization.isChinese ? 2 : 0).frame(maxWidth:.infinity).padding(.top,10)
        }.font(.system(size:12)).foregroundStyle(WeatherPalette.secondary)
    }
    private var status:some View{HStack(alignment:.top){Text(weather.error != nil ? WLF("更新失败，显示 %1$@ 的上次天气", String(describing: place.title)):WL("正在更新上次缓存…")).font(.system(size:12));Spacer();Button(WL("重试")){Task{await refresh()}}.font(.system(size:12,weight:.medium))}.padding(12).background(RoundedRectangle(cornerRadius:13).fill(WeatherPalette.lime.opacity(0.35)))}
    private var loadingState:some View{
        VStack(spacing:20){PaperCityScene(style:style,animate:motion).frame(height:240);Text(weather.error == nil ? WLF("正在接通%1$@的天空…", String(describing: place.title)):WL("暂时没收到天气来信")).font(.system(size:18,weight:.medium));if let error=weather.error{Text(error).font(.system(size:12)).foregroundStyle(WeatherPalette.secondary);Button(WL("重新连接")){Task{await refresh()}}.buttonStyle(.bordered);Button(WL("搜索其他城市")){app.presentCitySearch()}.buttonStyle(.plain)}else{ProgressView().tint(WeatherPalette.ink)}}.multilineTextAlignment(.center).frame(maxWidth:.infinity).padding(.vertical,40)
    }
}



struct WeatherTemperatureHeader: View {
    let report: WeatherReport
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize = 84
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize { stacked }
            else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .lastTextBaseline, spacing: 20) {
                        reading
                        Spacer(minLength: 0)
                        details(alignment: .trailing).fixedSize(horizontal: true, vertical: true)
                    }
                    stacked
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var reading: some View {
        HStack(alignment: .top, spacing: 2) {
            Text("\(report.temperature)")
                .font(.system(size: min(readingSize, 112), weight: .light, design: .serif))
                .tracking(-3).fixedSize()
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: report.temperature)
            Text("°")
                .font(.system(size: min(readingSize, 112) * 0.4, weight: .regular, design: .serif))
                .padding(.top, min(readingSize, 112) * 0.13)
        }
        .fixedSize().accessibilityElement(children: .ignore)
        .accessibilityLabel(WLF("%1$@摄氏度", String(describing: report.temperature)))
        .accessibilityIdentifier("home.temperature")
    }
    private var stacked: some View {
        VStack(alignment: .leading, spacing: 12) {
            reading
            details(alignment: .leading)
        }
    }
    private func details(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Label(report.kind.name, systemImage: report.kind.symbol).font(.headline)
                .accessibilityIdentifier("home.condition")
            Text(WLF("体感 %1$@°", String(describing: report.feelsLike))).font(.subheadline).foregroundStyle(WeatherPalette.secondary)
                .accessibilityIdentifier("home.feelsLike")
            Text(WLF("今天 %1$@° — %2$@°", String(describing: report.low), String(describing: report.high))).font(.caption.monospacedDigit())
                .accessibilityIdentifier("home.temperatureRange")
        }
    }
}

struct RegionalTicketShape:Shape{
    func path(in r:CGRect)->Path{var p=Path(roundedRect:r,cornerRadius:14);p.addEllipse(in:CGRect(x:-4,y:r.height*0.58,width:8,height:8));p.addEllipse(in:CGRect(x:r.width-4,y:r.height*0.58,width:8,height:8));return p}
}

enum DaylightProgress {
    static func fraction(at date:Date,sunrise:Date?,sunset:Date?)->Double?{guard let sunrise,let sunset,sunset>sunrise else{return nil};return min(max(date.timeIntervalSince(sunrise)/sunset.timeIntervalSince(sunrise),0),1)}
    static func duration(sunrise:Date?,sunset:Date?)->String{guard let sunrise,let sunset,sunset>sunrise else{return WL("日照数据暂缺")};let minutes=Int(sunset.timeIntervalSince(sunrise)/60);return WLF("白昼 %1$@时%2$@分", String(describing: minutes/60), String(describing: minutes%60))}
}

enum RegionalPreview {
    static let date=Date(timeIntervalSince1970:1793325600)
    static func dataset(place:WeatherPlace = .shanghai)->WeatherDataset {
        func make(_ i:Int,daily:Bool=false)->WeatherReport{
            var t=23+Int(sin(Double(i)*0.4)*3)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--home-layout-check"),
               let value = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--temperature=") })?.split(separator: "=").last,
               let supplied = Int(value), (-100...100).contains(supplied) { t = supplied }
            #endif
            let time=date.addingTimeInterval(Double(i)*(daily ? 86400:3600))
            return WeatherReport(kind:i%7==5 ? .lightRain:.partlyCloudy,temperature:t,low:18,high:26,feelsLike:t-1,scope:place.title,isDemo:true,metrics:WeatherMetrics(time:time,uv:3.2,probability:daily ? Double([63,35,20,10,45,80,30][i%7]):Double((i*7)%70),precipitation:daily ? Double([1.2,0.5,0,0,0.7,4.1,0.3][i%7]):0.1,precipitationUnit:daily ? WL("mm/天"):"mm/h",wind:12,windDirection:125,humidity:65,visibility:18,sunrise:date.addingTimeInterval(-4*3600),sunset:date.addingTimeInterval(7*3600),daily:daily,timeZoneIdentifier:place.timeZoneIdentifier),place:place)
        }
        let hours=(0..<24).map{make($0)}
        return WeatherDataset(current:hours[0],hourly:Array(hours.prefix(6)),daily:(0..<7).map{make($0,daily:true)},fetchedAt:date,next24Hours:hours,timeZoneIdentifier:place.timeZoneIdentifier)
    }
}

#if DEBUG
struct RegionalWeatherHome_Previews:PreviewProvider{
    static var previews:some View{WeatherNavigationStack{RegionalWeatherHome(app:WeatherApplication(live:false),preview:true)}.preferredColorScheme(.light).previewDisplayName(WL("离线 · 宋韵山水首页"))}
}
#endif
