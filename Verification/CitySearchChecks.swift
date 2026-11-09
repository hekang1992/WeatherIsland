import Foundation

private final class CitySearchProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: @Sendable (URLRequest) -> (Int, Data) = { _ in (200, Data("{}".utf8)) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.respond(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func cityFixture(id: Int = 1850147, name: String = "東京", code: String = "PPLC", latitude: Double = 35.6895, zone: String = "Asia/Tokyo") -> String {
    """
    {"id":\(id),"name":"\(name)","latitude":\(latitude),"longitude":139.6917,"feature_code":"\(code)","country_code":"JP","country":"日本","admin1":"東京都","timezone":"\(zone)","population":8336599}
    """
}

func checkCitySearch() async throws {
    let aliases = [(" 东京 \n", "Tokyo"), ("東京", "Tokyo"), ("纽约", "New York"), ("紐約", "New York"),
                   ("洛杉矶", "Los Angeles"), ("洛杉磯", "Los Angeles"), ("大阪", "Osaka"), ("倫敦", "London")]
    for (query, expected) in aliases { precondition(CityGeocodingService.queryNames(for: query) == [expected]) }
    precondition(CityGeocodingService.queryNames(for: " New   York ") == ["New York"])
    precondition(CityGeocodingService.queryNames(for: "Sydney") == ["Sydney"])
    precondition(CityGeocodingService.queryNames(for: "") == [])
    precondition(CityGeocodingService.queryNames(for: "A") == [])
    precondition(CityGeocodingService.queryNames(for: "杭州").contains("杭州"))
    let url = CityGeocodingService.endpoint(for: "São Paulo & Tokyo")
    let parameters = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
    precondition(parameters.first { $0.name == "name" }?.value == "São Paulo & Tokyo")
    precondition(parameters.first { $0.name == "language" }?.value == "zh")
    let data = Data(("{\"results\":[" + [cityFixture(), cityFixture(id: 2, name: "Mountain", code: "MT"),
        cityFixture(id: 3, latitude: 95), cityFixture(id: 4, zone: "Invalid/Zone"),
        cityFixture(id: 5, name: "東京", code: "ADM1")].joined(separator: ",") + "]}").utf8)
    let cities = try CityGeocodingService.decode(data)
    precondition(cities.count == 2 && cities.first?.place.city == "东京")
    precondition(cities.first?.place.countryCode == "JP" && cities.first?.place.timeZoneIdentifier == "Asia/Tokyo")
    precondition(cities.first?.subtitle == "日本 · 东京都")
    precondition(cities[0].savedPlace(in: [.tokyo]) == .tokyo)
    precondition(cities[0].savedPlace(in: [.newYork]) == cities[0].place)
    precondition(CityGeocodingService.simplified("大阪") == "大阪")
    var shanghai = WeatherPlace.shanghai; shanghai.city = "上海"
    let shanghaiResult = GeocodedCity(id: 1796236, place: shanghai, administrativeArea: "", population: 1)
    precondition(shanghaiResult.savedPlace(in: [.shanghai]) == .shanghai)
    var nearbyDifferentCity = WeatherPlace.tokyo; nearbyDifferentCity.city = "Other City"
    precondition(cities[0].savedPlace(in: [nearbyDifferentCity]) == cities[0].place)
    let noResults = try CityGeocodingService.decode(Data("{}".utf8))
    precondition(noResults.isEmpty)
    do {
        _ = try CityGeocodingService.decode(Data("{\"error\":true,\"reason\":\"invalid query\"}".utf8))
        preconditionFailure("API error must not look like no results")
    } catch CityGeocodingService.SearchError.invalidResponse {}
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CitySearchProtocol.self]
    let session = URLSession(configuration: configuration)
    defer { session.invalidateAndCancel() }
    CitySearchProtocol.respond = { request in
        let name = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "name" }!.value!
        precondition(name == "Tokyo")
        return (200, data)
    }
    let chinese = try await CityGeocodingService.search("东京", session: session)
    let english = try await CityGeocodingService.search("Tokyo", session: session)
    precondition(chinese.map(\.id) == english.map(\.id))
    precondition(chinese.map(\.place) == english.map(\.place))
    CitySearchProtocol.respond = { _ in (200, data) }
    // Both spellings return the same IDs: merge them, retaining distinct places.
    let variants = try await CityGeocodingService.search("苏州", session: session)
    precondition(variants.count == 2)
    CitySearchProtocol.respond = { request in
        let name = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!.first { $0.name == "name" }!.value!
        return name == "苏州" ? (500, Data()) : (200, data)
    }
    let recovered = try await CityGeocodingService.search("苏州", session: session)
    precondition(recovered.count == 2)
    CitySearchProtocol.respond = { _ in (503, Data()) }
    do {
        _ = try await CityGeocodingService.search("New York", session: session)
        preconditionFailure("HTTP failure must be retryable")
    } catch CityGeocodingService.SearchError.http(503) {}
    CitySearchProtocol.respond = { _ in (200, Data("{}".utf8)) }
    let empty = try await CityGeocodingService.search("zzzzunknown", session: session)
    precondition(empty.isEmpty)
    print("CITY SEARCH PASS: simplified/traditional aliases, global queries, coordinates/time zones, administrative filters, merged spellings, HTTP errors, empty results")
}

func checkLiveCitySearch() async throws {
    let cases = [("东京", "JP", "Asia/Tokyo"), ("Tokyo", "JP", "Asia/Tokyo"),
                 ("纽约", "US", "America/New_York"), ("New York", "US", "America/New_York"),
                 ("洛杉矶", "US", "America/Los_Angeles"), ("Los Angeles", "US", "America/Los_Angeles"),
                 ("伦敦", "GB", "Europe/London"), ("大阪", "JP", "Asia/Tokyo"),
                 ("Sydney", "AU", "Australia/Sydney"), ("北京", "CN", "Asia/Shanghai")]
    for (query, country, zone) in cases {
        let matches = try await CityGeocodingService.search(query)
        let first = matches.first!
        precondition(first.place.countryCode == country && first.place.timeZoneIdentifier == zone)
        print("CITY SEARCH LIVE PASS: \(query) → \(first.place.city) · \(first.subtitle), \(first.place.latitude),\(first.place.longitude), \(zone)")
    }
}
