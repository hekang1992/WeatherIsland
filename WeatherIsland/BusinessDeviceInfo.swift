#if os(iOS)
import Foundation
import UIKit
import Network
import Darwin

/// Only public, immediately available values are returned. Unknown values are omitted.
@MainActor
final class BusinessDeviceInfo {
    static let shared = BusinessDeviceInfo()
    private let monitor = NWPathMonitor()
    private var networkType: String?
    private var interfaceNames: [String] = []

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
                self?.networkType = type
                self?.interfaceNames = names
            }
        }
        monitor.start(queue: DispatchQueue(label: "WeatherIsland.BusinessNetwork"))
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func base64(window: UIWindow?) -> String? {
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
            }
            if scale.isFinite && scale > 0 {
                fields["f2fd42e9bc36"] = Double(scale)
                fields["1bb9f2f4b87a"] = Double(scale * UIFontMetrics.default.scaledValue(for: 17) / 17)
            }
        }
        let battery = device.batteryLevel
        if battery.isFinite && battery >= 0 && battery <= 1 {
            fields["ef02cd5586bc"] = Int((battery * 100).rounded())
        }
        switch device.batteryState {
        case .charging, .full: fields["fe5bfc5ccba1"] = true
        case .unplugged: fields["fe5bfc5ccba1"] = false
        default: break
        }
        let total = ProcessInfo.processInfo.physicalMemory
        if total <= 9_007_199_254_740_991 {
            fields["35dac7a89792"] = total
            if let free = freeMemory(), free <= total { fields["6b2ed867abe2"] = free }
        }
        text("ef84ad290e77", "Apple")
        switch device.userInterfaceIdiom {
        case .phone: text("56e967761ee7", "phone")
        case .pad: text("56e967761ee7", "tablet")
        default: break
        }
        text("e6b6e67871d1", device.systemVersion)
        text("336a72a9ba4a", Locale.current.identifier)
        // hw.machine is the actual hardware identifier (or simulator architecture).
        text("b14e873df31b", sysctlString("hw.machine"))
        text("bd8d64b3b73d", sysctlString("hw.model"))
        #if arch(arm64)
        let abi = "arm64"
        #elseif arch(x86_64)
        let abi = "x86_64"
        #else
        let abi: String? = nil
        #endif
        text("61b21bc4282f", abi)
        text("29752e1f59f9", abi)
        let cpu = ProcessInfo.processInfo.processorCount
        if (1...256).contains(cpu) { fields["9f9bdf2e1456"] = cpu }
        let info = Bundle.main.infoDictionary
        text("a4a366f265b8", info?["CFBundleShortVersionString"] as? String)
        text("3f3bf72d1ebc", info?["CFBundleVersion"] as? String)
        text("84b4bbeda526", info?["CFBundleShortVersionString"] as? String)
        if let build = info?["CFBundleVersion"] as? String, !build.isEmpty,
           build.utf8.allSatisfy({ (48...57).contains($0) }), let code = Int32(build), code >= 0 {
            fields["3cd527c516c2"] = code
        }
        text("8a537473299e", networkType)
        if networkType != "offline" { text("541354e5225c", ipAddress()) }
        // Disk capacity, Wi-Fi identifiers, carrier details, physical DPI and private IDs
        // are omitted; this integration does not invent values or request extra permissions.
        return BusinessBridgePayload.deviceInfoBase64(fields: fields)
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
                // Scoped/link-local IPv6 cannot be submitted as an unscoped IP literal.
                let value = String(decoding: host.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self)
                if !value.contains("%") { return value }
            }
        }
        return nil
    }
}
#endif
