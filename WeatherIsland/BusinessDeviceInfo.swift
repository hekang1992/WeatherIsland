#if os(iOS)
import Foundation
import UIKit
import Network
import NetworkExtension
import CoreTelephony
import CFNetwork
import Darwin

/// Only public, available values are returned. Unknown values are omitted.
@MainActor
final class BusinessDeviceInfo {
    static let shared = BusinessDeviceInfo()
    private let monitor = NWPathMonitor()
    private let telephony = CTTelephonyNetworkInfo()
    private var networkType: String?
    private var interfaceNames: [String] = []
    private var networkRevision = 0
    private var wifi: (ssid: String, bssid: String, capturedAt: Date)?
    private var wifiRequestPending = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let type: String
            if path.status != .satisfied { type = "offline" }
            else if path.usesInterfaceType(.wifi) { type = "wifi" }
            else if path.usesInterfaceType(.cellular) { type = "cellular" }
            else if path.usesInterfaceType(.wiredEthernet) { type = "ethernet" }
            else { type = "other" }
            let names = path.availableInterfaces.filter { path.usesInterfaceType($0.type) }.map(\.name)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.networkRevision += 1
                self.networkType = type
                self.interfaceNames = names
                self.wifi = nil
                self.wifiRequestPending = false
                self.refreshWifi()
            }
        }
        monitor.start(queue: DispatchQueue(label: "WeatherIsland.BusinessNetwork"))
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func base64(window: UIWindow?, appLanguage: String? = nil) -> String? {
        BusinessBridgePayload.deviceInfoBase64(fields: fields(window: window, appLanguage: appLanguage))
    }

    func fields(window: UIWindow?, appLanguage: String? = nil) -> [String: Any] {
        var fields: [String: Any] = [:]
        func text(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty, value.unicodeScalars.count <= 128,
                  value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return }
            fields[key] = value
        }
        let device = UIDevice.current
        if let window {
            let screen = window.screen
            let scale = screen.nativeScale
            let width = (window.bounds.width * scale).rounded()
            let height = (window.bounds.height * scale).rounded()
            if width.isFinite, height.isFinite, (1...32768).contains(width), (1...32768).contains(height) {
                fields["a9a83d27d82d"] = Int(width)
                fields["db364a8eea95"] = Int(height)
                fields["9e2fa8fa687b"] = Int(width)
                fields["f55043e72d15"] = Int(height)
            }
        }
        let battery = device.batteryLevel
        if battery.isFinite && battery >= 0 && battery <= 1 {
            fields["ef02cd5586bc"] = Int((battery * 100).rounded())
            fields["945f9f6e20f1"] = fields["ef02cd5586bc"]
        }
        switch device.batteryState {
        case .charging, .full: fields["fe5bfc5ccba1"] = true
        case .unplugged: fields["fe5bfc5ccba1"] = false
        default: break
        }
        fields["10524369c6f0"] = fields["fe5bfc5ccba1"]
        let total = ProcessInfo.processInfo.physicalMemory
        if total <= 9_007_199_254_740_991 {
            fields["35dac7a89792"] = total
            if let free = freeMemory(), free <= total { fields["6b2ed867abe2"] = free }
        }
        text("ef84ad290e77", "Apple")
        text("91331172ad3b", "Apple")
        text("9d63bcada728", "Apple")
        switch device.userInterfaceIdiom {
        case .phone: text("56e967761ee7", "phone")
        case .pad: text("56e967761ee7", "tablet")
        default: break
        }
        text("e6b6e67871d1", device.systemVersion)
        text("edece32fe66e", device.systemVersion)
        text("4bc782cb67ac", Locale.preferredLanguages.first)
        text("ab556da00f5c", appLanguage ?? Bundle.main.preferredLocalizations.first)
        text("336a72a9ba4a", Locale.current.identifier)
        // hw.machine is the native product/platform identifier, not a marketing model name.
        let product = sysctlString("hw.machine")
        text("b14e873df31b", product)
        let info = Bundle.main.infoDictionary
        text("a4a366f265b8", info?["CFBundleShortVersionString"] as? String)
        text("3f3bf72d1ebc", info?["CFBundleVersion"] as? String)
        text("84b4bbeda526", info?["CFBundleShortVersionString"] as? String)
        text("79aca3df21af", info?["DTSDKName"] as? String)
        if let build = info?["CFBundleVersion"] as? String, !build.isEmpty,
           build.utf8.allSatisfy({ (48...57).contains($0) }), let code = Int32(build), code >= 0 {
            fields["3cd527c516c2"] = code
        }
        text("8a537473299e", currentNetworkType())
        if networkType != "offline" { text("541354e5225c", ipAddress()) }
        if networkType == "wifi", let wifi, abs(wifi.capturedAt.timeIntervalSinceNow) < 5 {
            text("ee5f1c76d284", wifi.ssid)
            text("37a24e5ace39", wifi.bssid)
        }
        refreshWifi()
        #if targetEnvironment(simulator)
        fields["293a30ce3c08"] = true
        #else
        fields["293a30ce3c08"] = false
        #endif
        fields["3dcf8ff53d99"] = proxyEnabled()
        // See Verification/BusinessDeviceFields.md for all 70 mappings and omitted values.
        return fields
    }

    private func currentNetworkType() -> String? {
        guard networkType == "cellular" else { return networkType }
        guard let service = telephony.dataServiceIdentifier,
              let radio = telephony.serviceCurrentRadioAccessTechnology?[service] else { return "cellular" }
        switch radio {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA: return "5g"
        case CTRadioAccessTechnologyLTE: return "4g"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD: return "3g"
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x: return "2g"
        default: return "cellular"
        }
    }

    private func refreshWifi() {
        guard networkType == "wifi", !wifiRequestPending else { return }
        wifiRequestPending = true
        let revision = networkRevision
        NEHotspotNetwork.fetchCurrent { [weak self] network in
            // This API completes on the main queue; obtain Sendable values before hopping.
            let ssid = network?.ssid
            let bssid = network?.bssid
            Task { @MainActor [weak self] in
                guard let self, self.networkRevision == revision else { return }
                self.wifiRequestPending = false
                guard self.networkType == "wifi", let ssid, !ssid.isEmpty, let bssid,
                      bssid != "00:00:00:00:00:00", bssid != "02:00:00:00:00:00" else {
                    self.wifi = nil
                    return
                }
                self.wifi = (ssid, bssid, Date())
            }
        }
    }

    private func proxyEnabled() -> Bool? {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return nil }
        func enabled(_ config: [String: Any]) -> Bool {
            ["HTTPEnable", "HTTPSEnable", "SOCKSEnable", "ProxyAutoConfigEnable", "ProxyAutoDiscoveryEnable"]
                .contains { (config[$0] as? NSNumber)?.boolValue == true }
        }
        if enabled(settings) { return true }
        if let scoped = settings["__SCOPED__"] as? [String: [String: Any]],
           interfaceNames.contains(where: { name in scoped[name].map(enabled) == true }) { return true }
        return false
    }

    private func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1, size <= 256 else { return nil }
        var data = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &data, &size, nil, 0) == 0 else { return nil }
        return String(decoding: data.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private func freeMemory() -> UInt64? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        return UInt64(statistics.free_count) * UInt64(pageSize)
    }

    private func ipAddress() -> String? {
        guard !interfaceNames.isEmpty else { return nil }
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let pointer = current {
            let item = pointer.pointee
            defer { current = item.ifa_next }
            guard let address = item.ifa_addr,
                  interfaceNames.contains(String(cString: item.ifa_name)),
                  item.ifa_flags & UInt32(IFF_UP) != 0, item.ifa_flags & UInt32(IFF_LOOPBACK) == 0,
                  Int32(address.pointee.sa_family) == AF_INET || Int32(address.pointee.sa_family) == AF_INET6 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let value = String(decoding: host.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                if !value.contains("%") { return value }
            }
        }
        return nil
    }
}
#endif
