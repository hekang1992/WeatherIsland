import Foundation

/// A route can exist while per-app network access is still pending. Let URLSession
/// wait for usable connectivity, and retry connection failures while the app is active.
enum WeatherConnection {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func canRetry(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut,
             .dataNotAllowed, .internationalRoamingOff, .callIsActive,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    /// No retry limit: someone may leave the system permission prompt open for a
    /// while. Back off to one attempt per 15 seconds; view lifecycle cancels us.
    @MainActor static func recover(
        sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        attempt: @MainActor () async -> Bool
    ) async {
        let delays: [Duration] = [.seconds(1), .seconds(2), .seconds(4), .seconds(8), .seconds(15)]
        var index = 0
        while !Task.isCancelled {
            guard await attempt(), !Task.isCancelled else { return }
            do { try await sleep(delays[index]) } catch { return }
            index = min(index + 1, delays.count - 1)
        }
    }
}
