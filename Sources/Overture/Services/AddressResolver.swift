import Foundation

enum SearchProvider: String, Codable, CaseIterable, Identifiable {
    case google
    case duckDuckGo
    case bing
    case brave
    case ecosia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .google: "Google"
        case .duckDuckGo: "DuckDuckGo"
        case .bing: "Bing"
        case .brave: "Brave Search"
        case .ecosia: "Ecosia"
        }
    }

    func searchURL(for query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"

        switch self {
        case .google:
            components.host = "www.google.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .duckDuckGo:
            components.host = "duckduckgo.com"
            components.path = "/"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .bing:
            components.host = "www.bing.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .brave:
            components.host = "search.brave.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        case .ecosia:
            components.host = "www.ecosia.org"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        }

        return components.url
    }
}

enum AddressResolver {
    private static let supportedSchemes: Set<String> = ["http", "https", "file", "data"]

    static func resolve(
        _ rawInput: String,
        searchProvider: SearchProvider,
        httpsFirst: Bool = true
    ) -> URL? {
        let input = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return nil }

        if input == "overture://start" || input == "about:blank" {
            return URL(string: input)
        }

        if let components = URLComponents(string: input),
           let scheme = components.scheme?.lowercased(),
           supportedSchemes.contains(scheme),
           components.url != nil {
            return components.url
        }

        guard looksLikeLocation(input) else {
            return searchProvider.searchURL(for: input)
        }

        let scheme = preferredScheme(for: input, httpsFirst: httpsFirst)
        let escaped = input.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? input
        return URL(string: "\(scheme)://\(escaped)")
            ?? searchProvider.searchURL(for: input)
    }

    private static func looksLikeLocation(_ input: String) -> Bool {
        guard !input.contains(where: { $0.isWhitespace }) else { return false }

        let host = input.split(separator: "/", maxSplits: 1).first.map(String.init) ?? input
        let hostWithoutPort = host.split(separator: ":", maxSplits: 1).first.map(String.init) ?? host

        if hostWithoutPort.caseInsensitiveCompare("localhost") == .orderedSame { return true }
        if isIPv4Address(hostWithoutPort) || hostWithoutPort.contains(":") { return true }
        return hostWithoutPort.contains(".") && !hostWithoutPort.hasPrefix(".") && !hostWithoutPort.hasSuffix(".")
    }

    private static func preferredScheme(for input: String, httpsFirst: Bool) -> String {
        let host = input.split(separator: "/", maxSplits: 1).first.map(String.init) ?? input
        if host.lowercased().hasPrefix("localhost") || isIPv4Address(host.split(separator: ":").first.map(String.init) ?? host) {
            return "http"
        }
        return httpsFirst ? "https" : "http"
    }

    private static func isIPv4Address(_ input: String) -> Bool {
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let number = Int(part) else { return false }
            return (0...255).contains(number)
        }
    }
}
