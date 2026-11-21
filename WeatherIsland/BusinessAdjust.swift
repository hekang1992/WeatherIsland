#if os(iOS)
import AdjustSdk

@MainActor
enum BusinessAdjust {
    private static var started = false
    static let appToken = "4g040hdbpx4w"

    static func start() {
        guard !started else { return }
        #if DEBUG
        let environment = ADJEnvironmentSandbox
        #else
        let environment = ADJEnvironmentProduction
        #endif
        guard let config = ADJConfig(appToken: appToken, environment: environment, suppressLogLevel: true) else { return }
        config.logLevel = .suppress
        Adjust.initSdk(config)
        started = true
        BusinessH5Bridge.adjustIdProvider = { completion in
            Adjust.adid(withTimeout: 5_000) { value in
                completion(BusinessBridgePayload.adjustID(value))
            }
        }
    }
}
#endif
