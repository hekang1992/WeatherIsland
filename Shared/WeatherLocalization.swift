import Foundation

/// A preference is distinct from the language it currently resolves to.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, chinese = "zh-Hans", english = "en", vietnamese = "vi"
    static let storageKey = "WeatherIsland.Language.v1"
    static let group = "group.com.weather.app.ios"
    var id: String { rawValue }
    var locale: Locale { Locale(identifier: self == .chinese ? "zh_Hans_CN" : self == .vietnamese ? "vi_VN" : "en_US") }
    var title: String {
        switch self {
        case .system: WL("跟随系统")
        case .chinese: "简体中文"
        case .english: "English"
        case .vietnamese: "Tiếng Việt"
        }
    }
    static func resolve(_ preference: AppLanguage, preferredLanguages: [String]) -> AppLanguage {
        guard preference == .system else { return preference }
        for code in preferredLanguages {
            switch code.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first {
            case "zh": return .chinese
            case "en": return .english
            case "vi": return .vietnamese
            default: continue
            }
        }
        return .english
    }
}

/// Shared by the app, extension and the standalone preview/verification tools.
/// There is no mutable process-global locale or Bundle swizzling.
enum WeatherLocalization {
    static var preference: AppLanguage {
        #if os(macOS)
        if let value = ProcessInfo.processInfo.environment["WEATHER_ISLAND_LANGUAGE"], let language = AppLanguage(rawValue: value) { return language }
        #endif
        return AppLanguage(rawValue: UserDefaults(suiteName: AppLanguage.group)?.string(forKey: AppLanguage.storageKey)
            ?? UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? "system") ?? .system
    }
    static var language: AppLanguage { AppLanguage.resolve(preference, preferredLanguages: Locale.preferredLanguages) }
    static var locale: Locale { language.locale }
    static var isChinese: Bool { language == .chinese }
    static func persist(_ preference: AppLanguage, defaults: UserDefaults = .standard) {
        defaults.set(preference.rawValue, forKey: AppLanguage.storageKey)
        UserDefaults(suiteName: AppLanguage.group)?.set(preference.rawValue, forKey: AppLanguage.storageKey)
    }
    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        if let path = Bundle.main.path(forResource: selected.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: "Localizable")
        }
        // swiftc tools do not have an app bundle. Read the same source catalog,
        // never a second hand-maintained translation table.
        #if os(macOS)
        return sourceStrings[key]?.localizations?[selected.rawValue]?.stringUnit?.value ?? key
        #else
        return key
        #endif
    }
    static func format(_ key: String, _ arguments: [String], language: AppLanguage? = nil) -> String {
        let template = text(key, language: language)
        // Substitute in one pass: a city containing "%2$@" is user data.
        let pattern = try! NSRegularExpression(pattern: "%([0-9]+)\\$@")
        let matches = pattern.matches(in: template, range: NSRange(template.startIndex..., in: template))
        var result = template
        for match in matches.reversed() {
            guard let indexRange = Range(match.range(at: 1), in: template),
                  let index = Int(template[indexRange]), arguments.indices.contains(index - 1),
                  let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: arguments[index - 1])
        }
        return result
    }
    static func count(_ key: String, _ value: Int, language: AppLanguage? = nil) -> String {
        let selected = language ?? self.language
        if let path = Bundle.main.path(forResource: selected.rawValue, ofType: "lproj"), let bundle = Bundle(path: path) {
            let template = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
            return String(format: template, locale: selected.locale, value)
        }
        #if os(macOS)
        let plural = sourceStrings[key]?.localizations?[selected.rawValue]?.variations?.plural
        let unit = plural?[selected == .english && value == 1 ? "one" : "other"] ?? plural?["other"]
        return String(format: unit?.stringUnit?.value ?? "%d", locale: selected.locale, value)
        #else
        return String(value)
        #endif
    }
    static func date(_ date: Date, format: String, timeZone: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = TimeZone(identifier: timeZone) ?? .gmt
        // Hour cycle belongs to the device, independently of app language.
        let deviceHours = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "HH"
        let hour12 = deviceHours.contains("a") || deviceHours.contains("h")
        switch format {
        case "HH", "yyyy-MM-dd", "yyyy", "MM", "dd": formatter.dateFormat = format
        case "hour": formatter.dateFormat = hour12 ? "h a" : "HH"
        case "HH:mm": formatter.dateFormat = hour12 ? "h:mm a" : "HH:mm"
        case "HH时", "H时": formatter.dateFormat = hour12 ? "h a" : (isChinese ? "H时" : "HH:mm")
        default:
            if isChinese {
                formatter.dateFormat = format == "yyyy-MM-dd HH:mm" ? format : format.replacingOccurrences(of: "HH:mm", with: hour12 ? "h:mm a" : "HH:mm")
            }
            else {
                let template = format.replacingOccurrences(of: "月", with: " ").replacingOccurrences(of: "日", with: " ")
                    .replacingOccurrences(of: "年", with: " ").replacingOccurrences(of: "时", with: " ")
                formatter.setLocalizedDateFormatFromTemplate(template.replacingOccurrences(of: "HH", with: hour12 ? "ha" : "HH"))
            }
        }
        return formatter.string(from: date)
    }
    #if os(macOS)
    private struct Catalog: Decodable { let strings: [String: Entry] }
    private struct Entry: Decodable { let localizations: [String: Translation]? }
    private struct Translation: Decodable { let stringUnit: Unit?; let variations: Variations? }
    private struct Variations: Decodable { let plural: [String: Translation]? }
    private struct Unit: Decodable { let value: String }
    private static let sourceStrings: [String: Entry] = {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Localizable.xcstrings")
        guard let data = try? Data(contentsOf: url), let catalog = try? JSONDecoder().decode(Catalog.self, from: data) else { return [:] }
        return catalog.strings
    }()
    #endif
}

func WL(_ key: String) -> String { WeatherLocalization.text(key) }
func WLF(_ key: String, _ arguments: String...) -> String { WeatherLocalization.format(key, arguments) }
