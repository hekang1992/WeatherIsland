import Foundation
import CoreFoundation

@main
struct BusinessBridgeChecks {
    static func main() throws {
        for (handler, prefix) in [("getAdjustId", "onNativeAdjustId"), ("getDeviceInfo", "onNativeDeviceInfo")] {
            precondition(BusinessBridgePayload.callbackName(prefix + "_123", handler: handler) == prefix + "_123")
            precondition(BusinessBridgePayload.callbackName(prefix, handler: handler) == prefix)
            for bad in [prefix + "_", prefix + "_1();alert(1)", prefix + "_１２", "__proto__", "constructor", "window." + prefix] {
                precondition(BusinessBridgePayload.callbackName(bad, handler: handler) == nil)
            }
        }
        precondition(BusinessBridgePayload.callbackName("onNativeDeviceInfo_1", handler: "getAdjustId") == nil)
        precondition(BusinessBridgePayload.adjustID("ABCDEF0123456789ABCDEF0123456789") == "abcdef0123456789abcdef0123456789")
        for invalid in ["", "invalid", String(repeating: "g", count: 32), String(repeating: "0", count: 31)] {
            precondition(BusinessBridgePayload.adjustID(invalid) == nil)
        }
        let base64 = BusinessBridgePayload.deviceInfoBase64(fields: ["ef02cd5586bc": 0, "fe5bfc5ccba1": false, "336a72a9ba4a": "vi_VN"] )!
        let data = Data(base64Encoded: base64)!
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(object.count == 2 && object["version"] as? Int == 1 && object["nativeDeviceInfo"] == nil)
        let fields = object["fields"] as! [String: Any]
        precondition(fields["ef02cd5586bc"] as? Int == 0)
        let bool = fields["fe5bfc5ccba1"] as! NSNumber
        precondition(CFGetTypeID(bool) == CFBooleanGetTypeID() && bool.boolValue == false)
        precondition(fields["missingValue"] == nil)
        precondition(!base64.contains("\n"))
        for invalid: [String: Any] in [[:], ["invalidKey": 1], ["fe5bfc5ccba1": NSNull()], ["336a72a9ba4a": ""], ["336a72a9ba4a": "line\nfeed"], ["336a72a9ba4a": String(repeating: "a", count: 129)], ["ef02cd5586bc": Double.nan], ["ef02cd5586bc": [1, 2]]] {
            precondition(BusinessBridgePayload.deviceInfoBase64(fields: invalid) == nil)
        }
        var oversized: [String: Any] = [:]
        for i in 0..<96 { oversized[String(format: "%012x", i)] = String(repeating: "a", count: 128) }
        precondition(BusinessBridgePayload.deviceInfoBase64(fields: oversized) == nil)
        for i in 0..<97 { oversized[String(format: "%012x", i)] = 1 }
        precondition(BusinessBridgePayload.deviceInfoBase64(fields: oversized) == nil)
        print("Business bridge checks passed: dynamic callbacks, ADID, Base64 envelope, JSON types and limits")
    }
}
