#if os(iOS)
import UIKit
import CoreFoundation
import Darwin

/// Standalone simulator check app. It never calls Adjust or a business endpoint.
@main
@MainActor
final class BusinessDeviceInfoChecks: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }

    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = DeviceInfoCheckScene.self
        return configuration
    }

    static func runChecks(window: UIWindow) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            do {
                let report = try (UIApplication.shared.delegate as! BusinessDeviceInfoChecks).verify(window: window)
                let data = try JSONSerialization.data(withJSONObject: report, options: [.sortedKeys])
                try FileManager.default.createDirectory(at: URL.documentsDirectory, withIntermediateDirectories: true)
                try data.write(to: URL.documentsDirectory.appendingPathComponent("device-field-checks.json"))
                print("DEVICE_FIELD_CHECKS " + String(decoding: data, as: UTF8.self))
                exit(0)
            } catch {
                print("DEVICE_FIELD_CHECKS_FAILED " + String(describing: error))
                exit(1)
            }
        }
    }

    private func verify(window: UIWindow) throws -> [String: Any] {
        let collector = BusinessDeviceInfo.shared
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: Bundle.main.url(forResource: "BusinessDeviceFieldSchema", withExtension: "json")!)) as! [String: [String: String]]
        precondition(schema.count == 70)
        let fields = collector.fields(window: window, appLanguage: "vi")
        precondition(fields.count > 20, "Expected available requested fields")
        for (key, value) in fields {
            let rule = schema[key]!
            switch rule["kind"]! {
            case "string":
                let text = value as! String
                precondition(!text.isEmpty && text.unicodeScalars.count <= 128)
                precondition(text.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) })
            case "boolean":
                precondition(CFGetTypeID(value as! NSNumber) == CFBooleanGetTypeID())
            case "integer", "number":
                let number = value as! NSNumber
                precondition(CFGetTypeID(number) != CFBooleanGetTypeID())
                let n = number.doubleValue
                precondition(n.isFinite && n >= Double(rule["min"]!)! && n <= Double(rule["max"]!)!)
                if rule["kind"] == "integer" { precondition(n.rounded() == n) }
            default: preconditionFailure("Unsupported schema kind")
            }
        }
        for (preferred, compatible) in [("a9a83d27d82d", "9e2fa8fa687b"), ("db364a8eea95", "f55043e72d15"), ("ef02cd5586bc", "945f9f6e20f1"), ("fe5bfc5ccba1", "10524369c6f0")] {
            precondition((fields[preferred] as? NSObject) == (fields[compatible] as? NSObject))
        }
        precondition(fields["ab556da00f5c"] as? String == "vi")
        precondition(fields["ef84ad290e77"] as? String == "Apple")
        precondition(fields["91331172ad3b"] as? String == "Apple")
        precondition(fields["9d63bcada728"] as? String == "Apple")
        let excluded = ["9fa263605001", "bd8d64b3b73d", "f867b53cfa99", "f834b033944a", "61b21bc4282f", "29752e1f59f9", "9f9bdf2e1456", "f2fd42e9bc36", "1bb9f2f4b87a", "8c8265c337b1", "1b9323ed5c89", "bbf2cb348cee", "6e9dcf1ee23d", "f02db5f548ca", "c6b64e333439", "fd1f66bbc7e0", "c1e3ebc27abd", "855218e93ffe", "d6bd67311e89", "2daa23bddad0", "555ee827c278", "7d005b8fa426", "aa14088aa580", "fa29032c60e9", "31db73d13a50", "50fe2f590757", "eb4068674bab", "0b9d7e16c871", "e6fc4162fd5a", "9ab1e499ec60", "19f4d0e2b5aa", "1d3275aa3264", "188117ddbee4", "87c9d5eb6389"]
        for key in excluded { precondition(fields[key] == nil, "User-excluded field must be absent") }
        for key in ["fa104bf36fe5", "7c24de523ec0", "2bea3b186fa5", "06c229649aad", "29fb9935e12d"] {
            precondition(fields[key] == nil, "Unavailable values must not be fabricated")
        }
        let noWindow = collector.fields(window: nil, appLanguage: "vi")
        for key in ["a9a83d27d82d", "db364a8eea95", "9e2fa8fa687b", "f55043e72d15"] { precondition(noWindow[key] == nil) }
        let encoded = collector.base64(window: window, appLanguage: "vi")!
        let data = Data(base64Encoded: encoded)!
        let envelope = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(data.count <= 8192 && encoded.count <= 10924 && !encoded.contains("\n"))
        precondition(Set(envelope.keys) == ["version", "fields"] && envelope["version"] as? Int == 1)
        let decoded = envelope["fields"] as! [String: Any]
        precondition(decoded.count <= 96 && decoded["ab556da00f5c"] as? String == "vi")
        precondition(!(decoded.values.contains { $0 is NSNull }))
        for key in excluded { precondition(decoded[key] == nil, "Excluded field must also be absent after Base64 decoding") }
        return ["passed": true, "schemaFields": schema.count, "runtimeFieldCount": fields.count,
                "runtimeFieldNames": fields.keys.sorted(), "base64FullObject": true,
                "schemaTypesAndRanges": true, "compatiblePairs": true,
                "unknownFieldsOmitted": true, "noWindowOmitted": true,
                "userExcludedFieldsOmitted": excluded.count, "containsRawValues": false]
    }
}
@MainActor
final class DeviceInfoCheckScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        BusinessDeviceInfoChecks.runChecks(window: window)
    }
}
#endif
