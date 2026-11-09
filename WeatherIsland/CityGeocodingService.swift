import Foundation

/// Global administrative places, independent of MapKit address autocomplete coverage.
struct GeocodedCity: Identifiable, Sendable {
    let id: Int
    let place: WeatherPlace
    let administrativeArea: String
    let population: Int
    /// Preserve existing shortcut identities when the same city is found in another language.
    func savedPlace(in places: [WeatherPlace]) -> WeatherPlace {
        func canonical(_ city: String) -> String {
            let simplified = CityGeocodingService.simplified(city)
            let text = simplified.hasSuffix("市") ? String(simplified.dropLast()) : simplified
            return CityGeocodingService.queryNames(for: text).first ?? text
        }
        let name = canonical(place.city)
        return places.first { saved in
            if saved.id == place.id { return true }
            let savedName = canonical(saved.city)
            return saved.countryCode == place.countryCode && saved.district.isEmpty && place.district.isEmpty
                && name.caseInsensitiveCompare(savedName) == .orderedSame
                && abs(saved.latitude - place.latitude) < 0.05 && abs(saved.longitude - place.longitude) < 0.05
        } ?? place
    }
    var subtitle: String {
        var seen = Set<String>()
        return [place.country, place.region, administrativeArea].filter {
            !$0.isEmpty && $0 != place.city && seen.insert($0).inserted
        }.joined(separator: " · ")
    }
}

enum CityGeocodingService {
    enum SearchError: Error { case invalidResponse, http(Int) }

    /// GeoNames' alternate-name index has gaps for simplified Chinese. Translate
    /// common aliases to indexed names; all other names still use the global API.
    private static let aliases: [String: String] = [
        "东京": "Tokyo", "东京都": "Tokyo", "纽约": "New York", "纽约市": "New York",
        "洛杉矶": "Los Angeles", "伦敦": "London", "巴黎": "Paris", "大阪": "Osaka",
        "京都": "Kyoto", "横滨": "Yokohama", "名古屋": "Nagoya", "札幌": "Sapporo",
        "福冈": "Fukuoka", "首尔": "Seoul", "釜山": "Busan", "新加坡": "Singapore",
        "曼谷": "Bangkok", "吉隆坡": "Kuala Lumpur", "雅加达": "Jakarta", "河内": "Hanoi",
        "胡志明市": "Ho Chi Minh City", "马尼拉": "Manila", "迪拜": "Dubai",
        "悉尼": "Sydney", "墨尔本": "Melbourne", "奥克兰": "Auckland",
        "旧金山": "San Francisco", "三藩市": "San Francisco", "西雅图": "Seattle",
        "芝加哥": "Chicago", "波士顿": "Boston", "华盛顿": "Washington",
        "拉斯维加斯": "Las Vegas", "温哥华": "Vancouver", "多伦多": "Toronto",
        "蒙特利尔": "Montreal", "柏林": "Berlin", "慕尼黑": "Munich",
        "罗马": "Rome", "米兰": "Milan", "马德里": "Madrid", "巴塞罗那": "Barcelona",
        "阿姆斯特丹": "Amsterdam", "苏黎世": "Zurich", "维也纳": "Vienna",
        "莫斯科": "Moscow", "伊斯坦布尔": "Istanbul", "新德里": "New Delhi",
        "孟买": "Mumbai", "开罗": "Cairo", "开普敦": "Cape Town", "圣保罗": "Sao Paulo"
    ]

    static func simplified(_ value: String) -> String {
        // ICU maps the Japanese proper name 大阪 to 大坂; retain its current spelling.
        (value.applyingTransform(.init("Hant-Hans"), reverse: false) ?? value)
            .replacingOccurrences(of: "大坂", with: "大阪")
    }

    static func queryNames(for query: String) -> [String] {
        let text = query.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard text.count >= 2 else { return [] }
        if let alias = aliases[simplified(text)] { return [alias] }
        let traditional = text.applyingTransform(.init("Hans-Hant"), reverse: false) ?? text
        return traditional == text ? [text] : [text, traditional]
    }

    static func endpoint(for name: String) -> URL {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            .init(name: "name", value: name), .init(name: "count", value: "20"),
            .init(name: "language", value: "zh"), .init(name: "format", value: "json")
        ]
        return components.url!
    }

    static func search(_ query: String, session: URLSession = .shared) async throws -> [GeocodedCity] {
        let names = queryNames(for: query)
        guard !names.isEmpty else { return [] }
        return try await withThrowingTaskGroup(of: [GeocodedCity].self) { group in
            for name in names {
                group.addTask {
                    var request = URLRequest(url: endpoint(for: name))
                    request.timeoutInterval = 12
                    let (data, response) = try await session.data(for: request)
                    try Task.checkCancellation()
                    guard let http = response as? HTTPURLResponse else { throw SearchError.invalidResponse }
                    guard (200..<300).contains(http.statusCode) else { throw SearchError.http(http.statusCode) }
                    return try decode(data)
                }
            }
            var cities: [GeocodedCity] = []
            var failure: Error?
            // A successful alternate spelling can still be used if another fails.
            while let result = await group.nextResult() {
                switch result {
                case .success(let matches): cities += matches
                case .failure(let error): failure = error
                }
            }
            try Task.checkCancellation()
            if cities.isEmpty, let failure { throw failure }
            var seen = Set<Int>()
            return cities.sorted {
                $0.population == $1.population ? $0.id < $1.id : $0.population > $1.population
            }.filter { seen.insert($0.id).inserted }.prefix(20).map { $0 }
        }
    }

    static func decode(_ data: Data) throws -> [GeocodedCity] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.error != true else { throw SearchError.invalidResponse }
        return (response.results ?? []).compactMap { item in
            // Exclude POIs, mountains and country centroids from weather cities.
            guard item.feature_code.hasPrefix("PPL") || ["ADM1", "ADM2", "ADM3", "ADM4"].contains(item.feature_code),
                  let zone = item.timezone, TimeZone(identifier: zone) != nil,
                  let code = item.country_code, !code.isEmpty,
                  !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let place = WeatherPlace(city: simplified(item.name), region: simplified(item.admin1 ?? ""),
                                     country: simplified(item.country ?? Locale(identifier: "zh_CN").localizedString(forRegionCode: code) ?? code),
                                     countryCode: code.uppercased(), latitude: item.latitude, longitude: item.longitude,
                                     timeZoneIdentifier: zone)
            guard place.valid else { return nil }
            return GeocodedCity(id: item.id, place: place, administrativeArea: simplified(item.admin2 ?? ""), population: item.population ?? 0)
        }
    }

    private struct Response: Decodable { let results: [Place]?; let error: Bool? }
    private struct Place: Decodable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let feature_code: String
        let country_code: String?
        let country: String?
        let admin1: String?
        let admin2: String?
        let timezone: String?
        let population: Int?
    }
}
