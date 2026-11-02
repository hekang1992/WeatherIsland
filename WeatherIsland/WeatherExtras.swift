import SwiftUI
import Foundation

struct AirQualityReading: Codable, Sendable {
    let usAQI: Double?
    let pm25: Double?
    let pm10: Double?
    let time: Date
    let fetchedAt: Date
    var label: String {
        guard let usAQI else { return "暂无数据" }
        switch usAQI { case ...50: return "优"; case ...100: return "良"; case ...150: return "敏感人群需留意"; case ...200: return "不健康"; case ...300: return "很不健康"; default: return "危险" }
    }
    var tint: Color { guard let usAQI else { return WeatherPalette.secondary }; return usAQI <= 50 ? Color(hex:0x769777) : usAQI <= 100 ? Color(hex:0xAC985D) : WeatherPalette.accent }
    var advice: String {
        guard let usAQI else { return "空气质量数据暂缺。" }
        if usAQI > 150 { return "减少长时间户外活动，敏感人群优先安排室内活动。" }
        if usAQI > 100 { return "敏感人群减少长时间户外活动，运动时留意身体感受。" }
        return "根据自身情况安排户外活动，出门前再看一眼天气。"
    }
}

enum AirQualityService {
    static func endpoint(for place: WeatherPlace) -> URL {
        var components = URLComponents(string:"https://air-quality-api.open-meteo.com/v1/air-quality")!
        components.queryItems = [.init(name:"latitude",value:String(place.latitude)),.init(name:"longitude",value:String(place.longitude)),.init(name:"timezone",value:"auto"),.init(name:"timeformat",value:"unixtime"),.init(name:"current",value:"us_aqi,pm2_5,pm10")]
        return components.url!
    }
    static func decode(_ data: Data, fetchedAt: Date = .now) throws -> AirQualityReading {
        struct Payload: Decodable { let current: Current; struct Current: Decodable { let time: Double; let us_aqi: Double?; let pm2_5: Double?; let pm10: Double? } }
        let c = try JSONDecoder().decode(Payload.self,from:data).current
        func clean(_ value:Double?) -> Double? { value.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } }
        guard c.time.isFinite else { throw WeatherServiceError.invalidData }
        return AirQualityReading(usAQI:clean(c.us_aqi),pm25:clean(c.pm2_5),pm10:clean(c.pm10),time:Date(timeIntervalSince1970:c.time),fetchedAt:fetchedAt)
    }
    static func fetch(_ place: WeatherPlace) async throws -> AirQualityReading {
        let (data,response) = try await URLSession.shared.data(for:URLRequest(url:endpoint(for:place),timeoutInterval:15))
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw WeatherServiceError.invalidData }
        return try decode(data)
    }
}

@MainActor @Observable final class AirQualityStore {
    private(set) var reading: AirQualityReading?
    private(set) var failed = false
    private(set) var loading = false
    private(set) var cached = false
    let place: WeatherPlace
    private let defaults: UserDefaults
    private var key: String { "WeatherIsland.Air.v1." + place.cacheID }
    init(place:WeatherPlace,defaults:UserDefaults = .standard,live:Bool = true) {
        self.place=place;self.defaults=defaults
        if live, let data=defaults.data(forKey:key), let value=try? JSONDecoder().decode(AirQualityReading.self,from:data){reading=value;cached=true}
    }
    func refresh() async {
        guard !loading else{return};loading=true;failed=false
        defer{loading=false}
        do {let value=try await AirQualityService.fetch(place);try Task.checkCancellation();reading=value;cached=false;defaults.set(try JSONEncoder().encode(value),forKey:key)}
        catch is CancellationError {} catch let e as URLError where e.code == .cancelled {} catch {failed=true}
    }
}

