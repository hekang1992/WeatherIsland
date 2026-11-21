import Foundation

/// H5 wire format. Keep validation independent of UIKit and SDK lifecycle.
enum BusinessBridgePayload {
    static func callbackName(_ value: Any?, handler: String) -> String? {
        let prefix: String
        switch handler {
        case "getAdjustId": prefix = "onNativeAdjustId"
        case "getDeviceInfo": prefix = "onNativeDeviceInfo"
        default: return nil
        }
        guard let name = value as? String, name.count <= 80 else { return nil }
        if name == prefix { return name }
        guard name.hasPrefix(prefix + "_") else { return nil }
        let suffix = name.dropFirst(prefix.count + 1)
        return !suffix.isEmpty && suffix.utf8.allSatisfy { (48...57).contains($0) } ? name : nil
    }

    static func adjustID(_ value: String?) -> String? {
        guard let value, value.utf8.count == 32,
              value.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else { return nil }
        return value.lowercased()
    }

    /// Encode the complete {version, fields} object once, without an outer nativeDeviceInfo wrapper.
    static func deviceInfoBase64(fields: [String: Any]) -> String? {
        guard !fields.isEmpty, fields.count <= 96,
              fields.keys.allSatisfy({ key in
                  key.utf8.count == 12 && key.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
              }), JSONSerialization.isValidJSONObject(fields) else { return nil }
        for value in fields.values {
            if value is NSNull { return nil }
            if let text = value as? String {
                guard !text.isEmpty, text.unicodeScalars.count <= 128,
                      text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
            } else if !(value is NSNumber) { return nil }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: ["version": 1, "fields": fields], options: [.sortedKeys]),
              data.count <= 8192 else { return nil }
        return data.base64EncodedString()
    }
}
