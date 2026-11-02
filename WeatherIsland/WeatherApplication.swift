import SwiftUI

@MainActor @Observable final class WeatherApplication {
    enum Tab: Hashable { case weather, map, cities, settings }
    var tab: Tab = .weather
    private(set) var collection: CityCollection
    var searchPresented = false
    private(set) var locationRefreshID = 0
    private let defaults: UserDefaults
    private let live: Bool
    private var weather: [String:WeatherStore] = [:]
    private var air: [String:AirQualityStore] = [:]
    private static let collectionKey = "WeatherIsland.CityCollection.v1"
    init(defaults:UserDefaults = .standard, live:Bool = true) {
        self.defaults=defaults;self.live=live
        var restored = live ? defaults.data(forKey:Self.collectionKey).flatMap { try? JSONDecoder().decode(CityCollection.self,from:$0) } ?? CityCollection() : CityCollection()
        restored.validate();collection=restored
    }
    var offline:Bool {!live}
    var selected: WeatherPlace {collection.selected}
    var places:[WeatherPlace] {collection.places}
    var style: PaperSceneStyle { PaperSceneStyle.named(collection.sceneID) ?? .automatic(for:selected) }
    var automaticScene: Bool {collection.sceneID == nil}
    func weather(for place:WeatherPlace) -> WeatherStore {
        if let store=weather[place.cacheID] {store.updateMetadata(place);return store}
        let store=WeatherStore(live:live,place:place,defaults:defaults);weather[place.cacheID]=store;return store
    }
    func air(for place:WeatherPlace) -> AirQualityStore {
        if let store=air[place.cacheID] {return store}
        let store=AirQualityStore(place:place,defaults:defaults,live:live);air[place.cacheID]=store;return store
    }
    func select(_ place:WeatherPlace) {guard place.valid else{return};collection.selected=place;tab = .weather;save()}
    func selectLocation(_ place:WeatherPlace) { select(place); locationRefreshID += 1 }
    func resolveLocation(_ place:WeatherPlace) {
        guard selected.isCurrentLocation,selected.cacheID == place.cacheID else{return}
        weather[place.cacheID]?.updateMetadata(place)
        collection.selected=place;save()
    }
    func add(_ place:WeatherPlace) {collection.add(place);tab = .weather;searchPresented=false;save()}
    func remove(_ id:String) {collection.remove(id);save()}
    func setDefault(_ id:String) {guard places.contains(where:{$0.id==id})else{return};collection.defaultID=id;save()}
    func move(from:IndexSet,to:Int) {collection.places.move(fromOffsets:from,toOffset:to);save()}
    func apply(_ style:PaperSceneStyle?) {collection.sceneID=style?.id;save()}
    private func save() {guard live else{return};if let data=try? JSONEncoder().encode(collection){defaults.set(data,forKey:Self.collectionKey)}}
}
