import Foundation

@main struct WeatherServiceChecks {
    @MainActor static func main() async throws {
        try await checkCitySearch()
        if CommandLine.arguments.contains("--city-search-live") { try await checkLiveCitySearch() }
        let path = CommandLine.arguments[1]
        let fixture = try Data(contentsOf: URL(fileURLWithPath: path))
        try await checkWeatherLocalization(fixture: fixture)
        let clockWinter = ISO8601DateFormatter().date(from: "2026-11-03T16:30:00Z")!
        let clockSummer = ISO8601DateFormatter().date(from: "2026-07-01T12:00:00Z")!
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Asia/Tokyo", at: clockWinter) == "比参照城市快 1小时")
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Asia/Kolkata", at: clockWinter) == "比参照城市慢 2小时30分钟")
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Asia/Shanghai", at: clockWinter) == "与参照城市同一时间")
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Europe/London", at: clockWinter) == "比参照城市慢 8小时")
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Europe/London", at: clockSummer) == "比参照城市慢 7小时")
        precondition(WeatherClock.difference(from: "invalid", to: "Asia/Tokyo", at: clockWinter) == "时区未知")
        precondition(WeatherClock.string(clockWinter, "yyyy-MM-dd HH:mm", timeZone: "Asia/Shanghai") == "2026-11-04 00:30")
        precondition(WeatherClock.string(clockWinter, "yyyy-MM-dd HH:mm", timeZone: "Europe/London") == "2026-11-03 16:30")
        let dstBefore = ISO8601DateFormatter().date(from: "2026-10-25T00:30:00Z")!
        let dstAfter = ISO8601DateFormatter().date(from: "2026-10-25T01:30:00Z")!
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Europe/London", at: dstBefore) == "比参照城市慢 7小时")
        precondition(WeatherClock.difference(from: "Asia/Shanghai", to: "Europe/London", at: dstAfter) == "比参照城市慢 8小时")
        checkHomeWeatherInsights()
        try checkWeatherWidgets(fixture: fixture)
        try await checkWeatherConnection(fixture: fixture)
        checkSavedCityManagement()
        try checkWeatherLocationEntry()
        await checkWeatherLocationNaming()
        try checkWeatherSettings()
        let data = try WeatherService.decode(fixture)
        precondition(data.hourly.count == 6 && data.daily.count == 7)
        precondition(data.hours.first?.time == "现在")
        precondition(data.daily.first?.metrics?.daily == true)
        precondition(data.daily.first?.metrics?.humidity == nil)
        precondition(data.current.metrics?.precipitationUnit == "mm/15分")
        precondition(data.current.isLive && !WeatherReport.demo(.hail).isLive)
        let raw = try JSONSerialization.jsonObject(with: fixture) as! [String: Any]
        let current = raw["current"] as! [String: Any]
        precondition(data.current.temperature == Int((current["temperature_2m"] as! Double).rounded()))
        precondition(data.current.metrics?.humidity == current["relative_humidity_2m"] as? Double)
        precondition(data.hourly.dropFirst().allSatisfy { $0.metrics!.time > data.current.metrics!.time })
        precondition(data.daily.first!.low <= data.daily.first!.high)
        let cases: [(Int, WeatherKind)] = [(0,.clear),(1,.clear),(2,.partlyCloudy),(3,.overcast),
            (45,.fog),(48,.fog),(51,.lightRain),(53,.lightRain),(55,.lightRain),(56,.lightRain),
            (57,.lightRain),(61,.lightRain),(63,.moderateRain),(65,.heavyRain),(66,.lightRain),
            (67,.heavyRain),(71,.snow),(73,.snow),(75,.snow),(77,.snow),(80,.lightRain),
            (81,.moderateRain),(82,.heavyRain),(85,.snow),(86,.snow),(95,.thunderstorm),(96,.hail),(99,.hail)]
        for (code, expected) in cases { let kind = try WeatherService.kind(code: code); precondition(kind == expected) }
        let windy = try WeatherService.kind(code: 0, wind: 45)
        let rain = try WeatherService.kind(code: 65, wind: 45)
        precondition(windy == .windy && rain == .heavyRain)
        do { _ = try WeatherService.kind(code: 999); preconditionFailure("Unknown code accepted") }
        catch WeatherServiceError.unknownCode { }
        func modified(_ edit: (inout [String: Any]) -> Void) throws -> Data {
            var object = raw
            edit(&object)
            return try JSONSerialization.data(withJSONObject: object)
        }
        let missingUV = try modified { object in
            var hourly = object["hourly"] as! [String: Any]
            hourly.removeValue(forKey: "uv_index")
            object["hourly"] = hourly
        }
        let noUV = try WeatherService.decode(missingUV)
        precondition(noUV.current.uv == nil && noUV.current.uvText == "—")
        let broken = try modified { object in
            var daily = object["daily"] as! [String: Any]
            daily["temperature_2m_min"] = []
            object["daily"] = daily
        }
        do { _ = try WeatherService.decode(broken); preconditionFailure("Incomplete response accepted") }
        catch WeatherServiceError.invalidData { }
        // Cross midnight: the current point belongs to today, the next point to tomorrow.
        let midnight = try modified { object in
            let hourly = object["hourly"] as! [String: Any]
            let time = (hourly["time"] as! [Double])[23] + 2700
            var current = object["current"] as! [String: Any]
            current["time"] = time
            object["current"] = current
        }
        let midnightData = try WeatherService.decode(midnight)
        precondition(WeatherClock.string(midnightData.hourly[1].metrics!.time, "HH") == "00")
        precondition(midnightData.hourly[1].low == midnightData.daily[1].low)
        // Refresh success saves cache; a failed refresh preserves it and exposes an error.
        let suite = "WeatherIsland.Checks." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let success = WeatherStore(live: true, defaults: defaults, loader: { fixture })
        await success.refresh()
        precondition(success.dataset != nil && !success.cached && success.error == nil && !success.loading)
        let failure = WeatherStore(live: true, defaults: defaults, loader: { throw URLError(.notConnectedToInternet) })
        precondition(failure.dataset != nil && failure.cached)
        await failure.refresh()
        precondition(failure.dataset != nil && failure.error != nil && !failure.loading)
        let offlinePreview = WeatherStore(live: false, defaults: defaults)
        precondition(offlinePreview.dataset == nil)
        let emptySuite = "WeatherIsland.Empty." + UUID().uuidString
        let emptyDefaults = UserDefaults(suiteName: emptySuite)!
        defer { emptyDefaults.removePersistentDomain(forName: emptySuite) }
        let firstFailure = WeatherStore(live: true, defaults: emptyDefaults, loader: { throw URLError(.timedOut) })
        await firstFailure.refresh()
        precondition(firstFailure.dataset == nil && firstFailure.error != nil)
        // Regions preserve their own timezone, request coordinates, and independent cache.
        precondition(data.next24Hours.count == 24)
        func regionalFixture(_ place:WeatherPlace)throws->Data {
            try modified { object in
                object["timezone"]=place.timeZoneIdentifier
                var origin=Calendar(identifier:.gregorian);origin.timeZone=TimeZone(identifier:"Asia/Shanghai")!
                var target=Calendar(identifier:.gregorian);target.timeZone=TimeZone(identifier:place.timeZoneIdentifier)!
                func shift(_ t:Double)->Double { target.date(from:origin.dateComponents([.year,.month,.day,.hour,.minute,.second],from:Date(timeIntervalSince1970:t)))!.timeIntervalSince1970 }
                var c=object["current"] as! [String:Any];c["time"]=shift(c["time"] as! Double);object["current"]=c
                for key in ["hourly","daily"] {var part=object[key] as! [String:Any];for field in ["time","sunrise","sunset"] {if let values=part[field] as? [Double]{part[field]=values.map(shift)}};object[key]=part}
            }
        }
        for place in [WeatherPlace.beijing,.tokyo,.london,.newYork] {
            let payload = try regionalFixture(place)
            let region = try WeatherService.decode(payload, place:place)
            precondition(region.current.place == place && region.timeZoneIdentifier == place.timeZoneIdentifier)
            precondition(region.current.scope.contains(place.title))
            precondition(region.next24Hours.allSatisfy { $0.timeZoneIdentifier == place.timeZoneIdentifier })
            let query=URLComponents(url:WeatherService.endpoint(for:place),resolvingAgainstBaseURL:false)!.queryItems!
            precondition(query.contains(.init(name:"latitude",value:String(place.latitude))))
            precondition(query.contains(.init(name:"timezone",value:"auto")))
            // The same unix instant must use the region's civil date, including midnight boundaries.
            let instant=Date(timeIntervalSince1970:1793403000)
            let expected=DateFormatter();expected.dateFormat="yyyy-MM-dd HH:mm";expected.timeZone=TimeZone(identifier:place.timeZoneIdentifier)
            precondition(WeatherClock.string(instant,"yyyy-MM-dd HH:mm",timeZone:region.timeZoneIdentifier)==expected.string(from:instant))
        }
        let tokyoPayload = try regionalFixture(.tokyo)
        let londonPayload = try regionalFixture(.london)
        let tokyoStore = WeatherStore(live:true,place:.tokyo,defaults:defaults,loader:{try await Task.sleep(for:.milliseconds(40));return tokyoPayload})
        let londonStore = WeatherStore(live:true,place:.london,defaults:defaults,loader:{londonPayload})
        async let tokyoRefresh:Void=tokyoStore.refresh()
        async let londonRefresh:Void=londonStore.refresh()
        _=await(tokyoRefresh,londonRefresh)
        precondition(tokyoStore.dataset?.current.place == .tokyo && londonStore.dataset?.current.place == .london)
        let tokyoCache=WeatherStore(live:true,place:.tokyo,defaults:defaults)
        precondition(tokyoCache.cached && tokyoCache.dataset?.timeZoneIdentifier=="Asia/Tokyo")
        let cancelled=WeatherStore(live:true,place:.newYork,defaults:defaults,loader:{try await Task.sleep(for:.seconds(2));return fixture})
        let cancelledTask=Task{await cancelled.refresh()};cancelledTask.cancel();await cancelledTask.value
        precondition(cancelled.dataset == nil && !cancelled.loading && cancelled.error == nil)
        let legacySuite="WeatherIsland.Legacy."+UUID().uuidString
        let legacy=UserDefaults(suiteName:legacySuite)!;defer{legacy.removePersistentDomain(forName:legacySuite)}
        legacy.set(fixture,forKey:"WeatherIsland.OpenMeteo.Shanghai.v1");legacy.set(Date.now,forKey:"WeatherIsland.OpenMeteo.Shanghai.v1.date")
        precondition(WeatherStore(live:true,place:.london,defaults:legacy).dataset == nil)
        precondition(WeatherStore(live:true,defaults:legacy).cached)
        var cities=CityCollection();cities.add(.beijing);cities.add(.beijing)
        precondition(cities.places.count==2 && cities.selected == .beijing)
        cities.defaultID=WeatherPlace.beijing.id;cities.remove(WeatherPlace.beijing.id)
        precondition(cities.defaultID==WeatherPlace.shanghai.id && cities.selected == .shanghai)
        cities.remove(WeatherPlace.shanghai.id);precondition(cities.places.count==1)
        var approximate=WeatherPlace.beijing;approximate.approximate=true
        precondition(!approximate.title.contains("海淀"))
        var missing=WeatherPlace.beijing;missing.city="";missing.district=""
        precondition(missing.title=="当前位置")
        let app=WeatherApplication(defaults:defaults);app.add(.beijing);app.setDefault(WeatherPlace.beijing.id);app.move(from:IndexSet(integer:1),to:0);app.apply(PaperSceneStyle.all[49]);app.select(.tokyo)
        // select normally targets saved places or the independent current-location entry.
        app.add(.tokyo)
        let restored=WeatherApplication(defaults:defaults)
        precondition(restored.places.first == .beijing && restored.selected == .tokyo && restored.style == PaperSceneStyle.all[49])
        restored.apply(nil);precondition(restored.automaticScene)
        precondition(PaperSceneStyle.all.count==50 && Set(PaperSceneStyle.all.map(\.id)).count==50)
        for family in PaperSceneStyle.Family.allCases {precondition(PaperSceneStyle.all.filter{$0.family==family}.count==5)}
        // Reverse-geocoding must rename a coordinate store without changing identity or refetching.
        var unnamed=WeatherPlace.beijing;unnamed.isCurrentLocation=true;unnamed.city="";unnamed.region="";unnamed.district="";unnamed.country="";unnamed.countryCode=""
        var named=WeatherPlace.beijing;named.isCurrentLocation=true
        precondition(unnamed.cacheID == named.cacheID)
        let coordinateStore=WeatherStore(live:true,place:unnamed,defaults:defaults,loader:{try await Task.sleep(for:.milliseconds(20));return fixture})
        let fixTask=Task{await coordinateStore.refresh()}
        await Task.yield()
        coordinateStore.updateMetadata(named)
        await fixTask.value
        precondition(coordinateStore.dataset?.current.place == named)
        precondition(coordinateStore.dataset?.next24Hours.allSatisfy{$0.place == named} == true)
        let fetchedAt=coordinateStore.dataset!.fetchedAt
        named.district="朝阳区"
        coordinateStore.updateMetadata(named)
        precondition(coordinateStore.dataset?.current.scope == "此刻的\(named.title)" && coordinateStore.dataset?.fetchedAt == fetchedAt)
        var otherFix=named;otherFix.longitude += 1
        coordinateStore.updateMetadata(otherFix)
        precondition(coordinateStore.place == named)
        let locationApp=WeatherApplication(defaults:defaults,live:false)
        locationApp.select(unnamed)
        let initialStore=locationApp.weather(for:unnamed)
        locationApp.resolveLocation(named)
        precondition(locationApp.weather(for:named) === initialStore && locationApp.selected == named)
        locationApp.select(.london)
        locationApp.resolveLocation(named)
        precondition(locationApp.selected == .london) // Late administrative names must not change a manually chosen city.
        precondition(Set(PaperSceneStyle.all.map(\.artDirection)).count == 10)
        var texas=WeatherPlace(city:"Paris",region:"Texas",country:"美国",countryCode:"US",latitude:33.66,longitude:-95.55)
        precondition(PaperSceneStyle.automatic(for:texas) != PaperSceneStyle.all[3])
        texas.city="深圳";texas.countryCode="CN"
        precondition(PaperSceneStyle.automatic(for:texas) == PaperSceneStyle.all[14])
        print("LOCATION PASS: immediate-coordinate cache identity, asynchronous name updates during/after forecast, no refetch or data loss, stale name ignored after manual selection")
        let aqi=try AirQualityService.decode(Data("{\"current\":{\"time\":1793325600,\"us_aqi\":42,\"pm2_5\":null,\"pm10\":-1}}".utf8))
        precondition(aqi.usAQI==42 && aqi.pm25 == nil && aqi.pm10 == nil)
        let dawn=Date(timeIntervalSince1970:1000),dusk=Date(timeIntervalSince1970:4600)
        precondition(DaylightProgress.fraction(at:Date(timeIntervalSince1970:2800),sunrise:dawn,sunset:dusk)==0.5)
        precondition(DaylightProgress.fraction(at:Date(timeIntervalSince1970:9000),sunrise:dawn,sunset:dusk)==1)
        precondition(DaylightProgress.fraction(at:.now,sunrise:nil,sunset:nil)==nil)
        print("GLOBAL PASS: 24 hours, four timezone fixtures, coordinate queries, concurrent regional caches, cancellation, Shanghai-only migration, collection persistence, 50 unique scenes, partial AQI and daylight")
        try await WeatherMapChecks.run()
        if CommandLine.arguments.contains("--live") {
            let widget = try await IslandWidgetClient.fetch(.init(name: "上海", latitude: 31.23, longitude: 121.47, timeZone: "Asia/Shanghai"))
            precondition(widget.days.count == 3 && widget.upcoming(at: .now).count >= 6)
            print("WIDGET LIVE PASS: independent extension request, three days, six future forecast hours and city timezone")
            let response = try await WeatherService.fetch()
            let live = try WeatherService.decode(response)
            precondition(live.hourly.count == 6 && live.daily.count == 7)
            print("LIVE PASS: URLSession → Open-Meteo → Swift decoding; \(live.current.kind.name), \(live.current.temperature)°; \(WeatherClock.string(live.current.metrics!.time, "yyyy-MM-dd HH:mm"))")
        }
        print("PASS: live response decoding, all WMO mappings, optional/malformed fields, midnight rollover, cache, offline errors and Preview isolation")
    }
}
