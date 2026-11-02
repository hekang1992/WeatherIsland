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
    private let geocoder=CLGeocoder()
    private var timeout:Task<Void,Never>?
    private var geocoding:Task<Void,Never>?
    private var generation=0
    private var wantsLocation=false
    private var fixing=false
    private(set) var locating=false
    private(set) var resolvingName=false
    private(set) var error:String?
    private(set) var canOpenSettings=false
    var onLocated:((WeatherPlace)->Void)?
    var onResolved:((WeatherPlace)->Void)?
    override init(){super.init();manager.delegate=self;manager.desiredAccuracy=kCLLocationAccuracyHundredMeters}
    func request(){
        guard !locating else{return}
        generation += 1
        timeout?.cancel();geocoding?.cancel();geocoder.cancelGeocode()
        resolvingName=false;geocoding=nil;fixing=false
        error=nil;canOpenSettings=false;wantsLocation=true;locating=true
        switch manager.authorizationStatus {
        case .notDetermined:manager.requestWhenInUseAuthorization()
        case .authorizedAlways,.authorizedWhenInUse:startFix()
        case .denied,.restricted:fail("定位权限未开启，你仍可以搜索城市。",settings:true)
        @unknown default:fail("暂时无法使用定位，请搜索城市。")
        }
    }
    private func startFix(){
        guard wantsLocation,!fixing else{return}
        fixing=true
        // A recent system fix avoids waiting for another GPS acquisition on repeated taps.
        if let recent=manager.location,recent.horizontalAccuracy>=0,abs(recent.timestamp.timeIntervalSinceNow)<60 {
            accept(recent);return
        }
        manager.startUpdatingLocation()
        let token=generation
        timeout=Task{
            do {try await Task.sleep(for:.seconds(12))} catch {return}
            guard token==generation,wantsLocation else{return}
            fail("定位超时，请到信号较好的位置重试，或搜索城市。")
        }
    }
    private func fail(_ message:String,settings:Bool=false){
        generation += 1;timeout?.cancel();geocoding?.cancel();geocoding=nil
        geocoder.cancelGeocode();manager.stopUpdatingLocation();fixing=false
        locating=false;resolvingName=false;wantsLocation=false;error=message;canOpenSettings=settings
    }
    func clearError(){error=nil}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager){
        guard wantsLocation else{return}
        switch manager.authorizationStatus {
        case .authorizedAlways,.authorizedWhenInUse:startFix()
        case .denied,.restricted:fail("定位权限未开启，你仍可以搜索城市。",settings:true)
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
        locating=false;resolvingName=true
        let token=generation
        let approximate=manager.accuracyAuthorization == .reducedAccuracy || location.horizontalAccuracy>1000
        // Weather starts immediately from coordinates. Naming is a separate, nonblocking task.
        onLocated?(WeatherPlace.from(nil,coordinate:location.coordinate,current:true,approximate:approximate))
        geocoding=Task{
            let placemark=try? await geocoder.reverseGeocodeLocation(location,preferredLocale:Locale(identifier:"zh_CN")).first
            guard !Task.isCancelled,token==generation else{return}
            timeout?.cancel();resolvingName=false;geocoding=nil
            if let placemark {onResolved?(WeatherPlace.from(placemark,coordinate:location.coordinate,current:true,approximate:approximate))}
        }
        timeout=Task{
            do {try await Task.sleep(for:.seconds(5))} catch {return}
            guard token==generation,resolvingName else{return}
            generation += 1;geocoding?.cancel();geocoder.cancelGeocode();geocoding=nil;resolvingName=false
            // Keep coordinate weather. A missing administrative name must never discard a valid fix.
        }
    }
}

@MainActor @Observable final class CitySearchController:NSObject,@preconcurrency MKLocalSearchCompleterDelegate {
    private(set) var results:[MKLocalSearchCompletion]=[]
    private(set) var loading=false
    private(set) var resolving=false
    private(set) var error:String?
    private var debounce:Task<Void,Never>?
    private var completer:MKLocalSearchCompleter?
    private var localSearch:MKLocalSearch?
    private var resolveTask:Task<Void,Never>?
    func update(_ query:String){
        debounce?.cancel();completer?.cancel();completer?.delegate=nil;completer=nil
        localSearch?.cancel();localSearch=nil;resolveTask?.cancel();resolving=false;results=[];error=nil
        let text=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else{loading=false;return};loading=true
        debounce=Task{
            do{try await Task.sleep(for:.milliseconds(350))}catch{return}
            let next=MKLocalSearchCompleter();next.resultTypes = [.address];next.delegate=self
            completer=next;next.queryFragment=text
        }
    }
    func completerDidUpdateResults(_ completer:MKLocalSearchCompleter){guard completer===self.completer else{return};results=completer.results;loading=false}
    func completer(_ completer:MKLocalSearchCompleter,didFailWithError error:Error){guard completer===self.completer else{return};loading=false;self.error="搜索暂时不可用，请检查网络后再试。"}
    func choose(_ result:MKLocalSearchCompletion,onSelect:@escaping(WeatherPlace)->Void){
        guard !resolving else{return};resolving=true;error=nil
        let search=MKLocalSearch(request:MKLocalSearch.Request(completion:result));localSearch=search
        resolveTask=Task{
            defer{if localSearch === search {resolving=false;localSearch=nil}}
            do {
                let response=try await search.start();try Task.checkCancellation();guard localSearch === search else{return}
                guard let item=response.mapItems.first else{error="没有找到可用的城市坐标。";return}
                let placemark=item.placemark
                let place=WeatherPlace.from(placemark,coordinate:placemark.coordinate)
                guard place.valid,!place.city.isEmpty else{error="请选择包含城市或区县名称的地区。";return}
                onSelect(place)
            }catch is CancellationError{}catch{if !Task.isCancelled{self.error="无法取得地区信息，请重新选择。"}}
        }
    }
    func cancel(){debounce?.cancel();completer?.cancel();completer?.delegate=nil;localSearch?.cancel();resolveTask?.cancel()}
}
#endif
