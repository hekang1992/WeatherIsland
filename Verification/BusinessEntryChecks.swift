import Foundation

private final class ConfigurationProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        precondition(request.url == BusinessEntry.configurationURL)
        precondition(request.cachePolicy == .reloadIgnoringLocalCacheData)
        precondition(request.timeoutInterval == 10)
        precondition(request.value(forHTTPHeaderField: "Accept") == "application/json")
        switch request.value(forHTTPHeaderField: "Test-Scenario") {
        case "offline":
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case "timeout":
            client?.urlProtocol(self, didFailWithError: URLError(.timedOut))
        default:
            let scenario = request.value(forHTTPHeaderField: "Test-Scenario") ?? "web"
            let status = scenario == "server-error" ? 503 : 200
            let json = scenario == "native" ? #"{"mvbx":{"plkr":""}}"# : #"{"mvbx":{"plkr":"https://example.com/entry"}}"#
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

@main struct BusinessEntryChecks {
    static func main() async {
        let response = HTTPURLResponse(url: BusinessEntry.configurationURL, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
        let values: [(String, String?)] = [
            (#"{"mvbx":{"plkr":""}}"#, nil),
            (#"{"mvbx":{"plkr":" \n\t "}}"#, nil),
            (#"{"mvbx":{"plkr":"https://example.com/path?q=1"}}"#, "https://example.com/path?q=1"),
            (#"{"mvbx":{"plkr":"  http://example.com/path  "}}"#, "http://example.com/path"),
            (#"{"mvbx":{"plkr":null}}"#, nil),
            (#"{"mvbx":{}}"#, nil),
            (#"{}"#, nil),
            (#"{"mvbx":{"plkr":123}}"#, nil),
            (#"{"mvbx":{"plkr":"not a URL"}}"#, nil),
            (#"{"mvbx":{"plkr":"/relative/path"}}"#, nil),
            (#"{"mvbx":{"plkr":"javascript:alert(1)"}}"#, nil),
            (#"{"mvbx":{"plkr":"file:///tmp/test.html"}}"#, nil),
            (#"{"mvbx":{"plkr":"https:///"}}"#, nil),
            ("invalid JSON", nil)
        ]
        for (json, expected) in values {
            precondition(BusinessEntry.destination(data: Data(json.utf8), response: response)?.absoluteString == expected,
                         "Unexpected destination for \(json)")
        }
        for scenario in ["web", "native", "server-error", "offline", "timeout"] {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [ConfigurationProtocol.self]
            configuration.httpAdditionalHeaders = ["Test-Scenario": scenario]
            let session = URLSession(configuration: configuration)
            let url = await BusinessEntry.fetchDestination(session: session)
            precondition(url?.absoluteString == (scenario == "web" ? "https://example.com/entry" : nil),
                         "Unexpected result for \(scenario)")
            session.invalidateAndCancel()
        }
        print("Business entry checks passed: JSON routing, request settings, HTTP failure, offline and timeout fallback.")
    }
}
