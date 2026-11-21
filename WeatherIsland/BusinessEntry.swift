import Foundation

enum BusinessEntry {
    static let configurationURL = URL(string: "https://www.weathervgr.click/config/business-entry.json")!

    private struct Configuration: Decodable {
        struct Entry: Decodable { let plkr: String? }
        let mvbx: Entry?
    }

    static func destination(data: Data, response: URLResponse) -> URL? {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let configuration = try? JSONDecoder().decode(Configuration.self, from: data),
              let value = configuration.mvbx?.plkr?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty else { return nil }
        return components.url
    }

    static func fetchDestination(session: URLSession? = nil) async -> URL? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 12
        let client = session ?? URLSession(configuration: configuration)
        defer { if session == nil { client.invalidateAndCancel() } }
        var request = URLRequest(url: configurationURL, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await client.data(for: request)
            return destination(data: data, response: response)
        } catch {
            return nil
        }
    }
}

#if os(iOS)
import SwiftUI
import WebKit

@MainActor
enum BusinessH5Bridge {
    typealias Completion = @Sendable (String?) -> Void

    static var adjustIdProvider: (@escaping Completion) -> Void = { completion in
        completion(nil)
    }
}

struct BusinessTabsView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(entryURL: url) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        for name in ["getAdjustId", "getDeviceInfo"] {
            configuration.userContentController.add(context.coordinator, name: name)
        }
        // 提前准备电池状态和网络缓存，设备回包不等待异步网络查询。
        _ = BusinessDeviceInfo.shared

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = false
        context.coordinator.webView = view
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        for name in ["getAdjustId", "getDeviceInfo"] {
            uiView.configuration.userContentController.removeScriptMessageHandler(forName: name)
        }
        coordinator.invalidateRequests()
        coordinator.webView = nil
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        uiView.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        private let entryURL: URL
        private var navigationRevision = 0
        private var pending: [String: UUID] = [:]

        init(entryURL: URL) {
            self.entryURL = entryURL
            super.init()
        }

        private func acceptsOrigin(scheme: String?, host: String?, port: Int?) -> Bool {
            guard let scheme = scheme?.lowercased(), ["https", "http"].contains(scheme),
                  scheme == entryURL.scheme?.lowercased(),
                  let host, host.lowercased() == entryURL.host?.lowercased() else { return false }
            let defaultPort = scheme == "https" ? 443 : 80
            let actualPort = port.flatMap { $0 == 0 ? nil : $0 } ?? defaultPort
            return actualPort == (entryURL.port ?? defaultPort)
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            let origin = message.frameInfo.securityOrigin
            guard message.frameInfo.isMainFrame, let view = webView,
                  message.webView === view,
                  acceptsOrigin(scheme: origin.protocol, host: origin.host, port: origin.port),
                  let body = message.body as? [String: Any],
                  let callback = BusinessBridgePayload.callbackName(body["callback"], handler: message.name),
                  pending[callback] == nil, pending.count < 64 else { return }

            let request = UUID()
            let revision = navigationRevision
            pending[callback] = request
            if message.name == "getDeviceInfo" {
                let payload = BusinessDeviceInfo.shared.base64(window: view.window)
                reply(callback: callback, request: request, revision: revision, payload: payload)
            } else {
                BusinessH5Bridge.adjustIdProvider { [weak self] value in
                    let id = BusinessBridgePayload.adjustID(value)
                    Task { @MainActor [weak self] in
                        self?.reply(callback: callback, request: request, revision: revision,
                                    payload: id.map { ["adjustid": $0] })
                    }
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    guard let self, self.pending[callback] == request else { return }
                    self.pending.removeValue(forKey: callback)
                }
            }
        }

        private func reply(callback: String, request: UUID, revision: Int, payload: Any?) {
            guard pending[callback] == request else { return }
            pending.removeValue(forKey: callback)
            guard navigationRevision == revision, let view = webView, let payload,
                  acceptsOrigin(scheme: view.url?.scheme, host: view.url?.host, port: view.url?.port) else { return }
            view.callAsyncJavaScript(
                """
                if (typeof window[callbackName] === "function") {
                    window[callbackName](payload);
                }
                """,
                arguments: ["callbackName": callback, "payload": payload],
                in: nil, in: .page, completionHandler: nil
            )
        }

        func invalidateRequests() {
            navigationRevision += 1
            pending.removeAll()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            invalidateRequests()
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            invalidateRequests()
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.prompt)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let scheme = navigationAction.request.url?.scheme?.lowercased(),
               ["https", "http"].contains(scheme) {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
#endif
