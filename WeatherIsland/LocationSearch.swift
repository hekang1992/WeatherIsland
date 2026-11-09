#if os(iOS)
import SwiftUI
import CoreLocation
import MapKit
import UIKit

extension WeatherPlace {
    @MainActor static func from(_ placemark:CLPlacemark?, coordinate:CLLocationCoordinate2D, current:Bool = false, approximate:Bool = false) -> WeatherPlace {
        let city=placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.administrativeArea ?? ""
        let rawDistrict=placemark?.subLocality ?? ((placemark?.subAdministrativeArea != city) ? placemark?.subAdministrativeArea : nil) ?? ""
        return WeatherPlace(city:city,district:approximate || rawDistrict == city ? "" : rawDistrict,region:placemark?.administrativeArea ?? "",country:placemark?.country ?? "",countryCode:placemark?.isoCountryCode ?? "",latitude:coordinate.latitude,longitude:coordinate.longitude,timeZoneIdentifier:placemark?.timeZone?.identifier ?? "UTC",isCurrentLocation:current,approximate:approximate)
    }
}

@MainActor @Observable final class LocationController:NSObject,@preconcurrency CLLocationManagerDelegate {
    private let manager=CLLocationManager()
    private var timeout:Task<Void,Never>?
    private var generation=0
    private var wantsLocation=false
    private var fixing=false
    private(set) var locating=false
    private(set) var error:String?
    private(set) var canOpenSettings=false
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    var authorized: Bool { authorization == .authorizedAlways || authorization == .authorizedWhenInUse }
    var onLocated:((WeatherPlace)->Void)?
    override init(){super.init();authorization=manager.authorizationStatus;manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters}
    func request(){
        guard !locating else{return}
        generation += 1
        timeout?.cancel();fixing=false
        error=nil;canOpenSettings=false;wantsLocation=true;locating=true
        authorization = manager.authorizationStatus
        switch authorization {
        case .notDetermined:manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse:startFix()
        case .denied:fail("定位权限未开启，请手动选择天气城市，也可以前往系统设置开启定位。",settings:true)
        case .restricted:fail("此设备限制了定位权限，请手动选择天气城市。")
        @unknown default:fail("暂时无法使用定位，请搜索城市。")
        }
    }
    private func startFix(){
        guard wantsLocation,!fixing else{return}
        fixing=true
        #if DEBUG
        let suppressFix = ProcessInfo.processInfo.arguments.contains("--location-no-fix-check")
        #else
        let suppressFix = false
        #endif
        // A recent system fix avoids waiting for another GPS acquisition on repeated taps.
        if !suppressFix, let recent=manager.location,recent.horizontalAccuracy>=0,abs(recent.timestamp.timeIntervalSinceNow)<60 {
            accept(recent);return
        }
        if !suppressFix { manager.startUpdatingLocation() }
        let token=generation
        timeout=Task{
            do {try await Task.sleep(for:.seconds(12))} catch {return}
            guard token==generation,wantsLocation else{return}
            fail("定位超时，请到信号较好的位置重试，或搜索城市。")
        }
    }
    private func fail(_ message:String,settings:Bool=false){
        cancel()
        error=message;canOpenSettings=settings
    }
    func cancel() {
        generation += 1; timeout?.cancel(); timeout=nil
        manager.stopUpdatingLocation(); fixing=false
        locating=false; wantsLocation=false
        error=nil; canOpenSettings=false
    }
    func refreshAuthorization() { authorization = manager.authorizationStatus }
    func clearError(){error=nil}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){
        authorization = manager.authorizationStatus
        guard wantsLocation else{return}
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse:startFix()
        case .denied:fail("定位权限未开启，请手动选择天气城市，也可以前往系统设置开启定位。",settings:true)
        case .restricted:fail("此设备限制了定位权限，请手动选择天气城市。")
        default:break
        }
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error){
        guard wantsLocation else{return}
        if let locationError=error as? CLError {
            if locationError.code == .locationUnknown {return} // Transient; retain the bounded acquisition window.
            if locationError.code == .denied {fail("定位服务已关闭，请在系统设置中开启，或搜索城市。",settings:true);return}
        }
        fail("暂时无法取得位置，请稍后重试或搜索城市。")
    }
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]){
        guard wantsLocation,let location=locations.filter({$0.horizontalAccuracy>=0 && abs($0.timestamp.timeIntervalSinceNow)<60}).min(by:{$0.horizontalAccuracy<$1.horizontalAccuracy}) else{return}
        accept(location)
    }
    private func accept(_ location:CLLocation){
        guard wantsLocation else{return}
        timeout?.cancel();manager.stopUpdatingLocation();wantsLocation=false;fixing=false
        locating=false
        let approximate=manager.accuracyAuthorization == .reducedAccuracy || location.horizontalAccuracy>1000
        onLocated?(WeatherPlace.from(nil,coordinate:location.coordinate,current:true,approximate:approximate))
    }
}

/// One bounded lookup. Cancellation belongs to the foreground naming task;
/// each attempt owns a geocoder so cancelling an old lookup cannot cancel a new one.
@MainActor enum WeatherLocationLookup {
    #if DEBUG
    private static var checkAttempts = 0
    #endif
    static func name(for place: WeatherPlace) async throws -> WeatherPlace? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--location-name-recovery-check") {
            checkAttempts += 1
            try await Task.sleep(for: .seconds(2))
            if checkAttempts == 1 { throw URLError(.notConnectedToInternet) }
            if checkAttempts == 2 { return place } // Country-only or nameless response is not success.
            // Leave enough time for UI checks to observe populated coordinate
            // weather before the simulated administrative name arrives.
            try await Task.sleep(for: .seconds(8))
            var named = place
            named.city = "北京市"; named.district = place.approximate ? "" : "海淀区"
            named.region = "北京市"; named.country = "中国"; named.countryCode = "CN"
            named.timeZoneIdentifier = "Asia/Shanghai"
            return named
        }
        #endif
        let request = Attempt()
        let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
        let timeout = Task {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            request.cancel()
        }
        defer { timeout.cancel() }
        let placemarks = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await request.lookup(location)
        } onCancel: {
            Task { @MainActor in request.cancel() }
        }
        try Task.checkCancellation()
        guard let placemark = placemarks.first else { return nil }
        return WeatherPlace.from(placemark, coordinate: location.coordinate, current: true, approximate: place.approximate)
    }

    // The actor-isolated owner can safely cross the cancellation handler's
    // Sendable boundary; the non-Sendable geocoder stays on the main actor.
    @MainActor private final class Attempt {
        private let geocoder = CLGeocoder()
        func cancel() { geocoder.cancelGeocode() }
        func lookup(_ location: CLLocation) async throws -> [CLPlacemark] {
            try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN"))
        }
    }
}

@MainActor @Observable final class CitySearchController: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private(set) var results: [MKLocalSearchCompletion] = []
    private(set) var cities: [GeocodedCity] = []
    private(set) var resolving = false
    private(set) var error: String?
    private(set) var globalLoading = false
    private var localLoading = false
    var loading: Bool { globalLoading || localLoading }
    private var globalFailed = false
    private var localFailed = false
    private var generation = 0
    private var debounce: Task<Void, Never>?
    private var globalTask: Task<Void, Never>?
    private var localTimeout: Task<Void, Never>?
    private var completer: MKLocalSearchCompleter?
    private var localSearch: MKLocalSearch?
    private var resolveTask: Task<Void, Never>?

    func update(_ query: String) {
        cancel()
        results = []; cities = []; error = nil
        globalFailed = false; localFailed = false
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        globalLoading = true; localLoading = true
        let token = generation
        debounce = Task {
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard token == generation else { return }
            globalTask = Task {
                do {
                    let matches = try await lookup(text)
                    try Task.checkCancellation()
                    guard token == generation else { return }
                    cities = matches; globalLoading = false; updateError()
                } catch {
                    guard !Task.isCancelled, token == generation else { return }
                    globalFailed = true; globalLoading = false; updateError()
                }
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--city-search-check") {
                localLoading = false
                return
            }
            #endif
            let next = MKLocalSearchCompleter()
            next.resultTypes = [.address]; next.delegate = self
            completer = next; next.queryFragment = text
            localTimeout = Task {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                guard token == generation, localLoading else { return }
                next.cancel(); next.delegate = nil
                localLoading = false; localFailed = true; updateError()
            }
        }
    }

    private func lookup(_ query: String) async throws -> [GeocodedCity] {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--city-search-check") {
            // Isolated UI checks exercise the same alias mapping and decoder.
            let name = CityGeocodingService.queryNames(for: query).first ?? ""
            try await Task.sleep(for: .milliseconds(name == "Tokyo" ? 1400 : 100))
            if query == "networkerror" { throw URLError(.notConnectedToInternet) }
            let matches = CityGeocodingService.checkCities.filter {
                $0.english.caseInsensitiveCompare(name) == .orderedSame
            }.map { $0.json }
            let data = Data(("{\"results\":[" + matches.joined(separator: ",") + "]}").utf8)
            return try CityGeocodingService.decode(data)
        }
        #endif
        return try await CityGeocodingService.search(query)
    }

    private func updateError() {
        guard !loading else { return }
        if globalFailed {
            error = "全球城市搜索暂时不可用，请检查网络后重试。"
        } else if localFailed && cities.isEmpty && results.isEmpty {
            error = "部分地区搜索暂时不可用，请稍后重试。"
        } else { error = nil }
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        localTimeout?.cancel(); results = completer.results; localLoading = false; updateError()
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        localTimeout?.cancel(); localLoading = false; localFailed = true; updateError()
    }
    func choose(_ city: GeocodedCity, onSelect: (WeatherPlace) -> Void) {
        guard !resolving else { return }
        cancel()
        onSelect(city.place)
    }
    func choose(_ result: MKLocalSearchCompletion, onSelect: @escaping (WeatherPlace) -> Void) {
        guard !resolving else { return }
        resolving = true; error = nil
        let token = generation
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: result)); localSearch = search
        resolveTask = Task {
            defer { if localSearch === search { resolving = false; localSearch = nil } }
            do {
                let response = try await search.start(); try Task.checkCancellation()
                guard token == generation, localSearch === search else { return }
                guard let item = response.mapItems.first else { error = "没有找到可用的城市坐标。"; return }
                let place = WeatherPlace.from(item.placemark, coordinate: item.placemark.coordinate)
                guard place.valid, !place.city.isEmpty else { error = "请选择包含城市或区县名称的地区。"; return }
                onSelect(place)
            } catch {
                if !Task.isCancelled, token == generation { self.error = "无法取得地区信息，请重新选择。" }
            }
        }
    }
    func cancel() {
        generation += 1
        debounce?.cancel(); globalTask?.cancel(); localTimeout?.cancel()
        completer?.cancel(); completer?.delegate = nil; completer = nil
        localSearch?.cancel(); localSearch = nil; resolveTask?.cancel()
        globalLoading = false; localLoading = false; resolving = false
    }
}

#if DEBUG
extension CityGeocodingService {
    static let checkCities: [(english: String, json: String)] = [
        ("Tokyo", #"{"id":1850147,"name":"東京","latitude":35.6895,"longitude":139.6917,"feature_code":"PPLC","country_code":"JP","country":"日本","admin1":"东京都","timezone":"Asia/Tokyo","population":8336599}"#),
        ("New York", #"{"id":5128581,"name":"紐約市","latitude":40.71427,"longitude":-74.00597,"feature_code":"PPL","country_code":"US","country":"美国","admin1":"纽约州","timezone":"America/New_York","population":8804190}"#),
        ("Los Angeles", #"{"id":5368361,"name":"洛杉矶","latitude":34.05223,"longitude":-118.24368,"feature_code":"PPLA2","country_code":"US","country":"美国","admin1":"加州","timezone":"America/Los_Angeles","population":3898747}"#)
    ]
}
#endif
#endif
