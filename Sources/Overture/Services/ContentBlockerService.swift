import Foundation
import WebKit

/// Compiles and installs Overture's built-in WebKit content rules.
///
/// The rules are intentionally conservative. They block well-known advertising,
/// analytics, and tracking endpoints while leaving first-party page resources alone.
@MainActor
final class ContentBlockerService {
    static let shared = ContentBlockerService()

    enum ServiceError: LocalizedError {
        case ruleListStoreUnavailable
        case compilationReturnedNoRuleList

        var errorDescription: String? {
            switch self {
            case .ruleListStoreUnavailable:
                "WebKit's content-rule store is unavailable."
            case .compilationReturnedNoRuleList:
                "WebKit compiled the content rules without returning a rule list."
            }
        }
    }

    private static let blockedDomainPatterns = [
        "doubleclick\\.net",
        "googlesyndication\\.com",
        "googleadservices\\.com",
        "google-analytics\\.com",
        "googletagmanager\\.com",
        "adnxs\\.com",
        "criteo\\.com",
        "criteo\\.net",
        "taboola\\.com",
        "outbrain\\.com",
        "connect\\.facebook\\.net",
        "analytics\\.twitter\\.com",
        "bat\\.bing\\.com",
        "script\\.hotjar\\.com",
        "static\\.hotjar\\.com",
        "cdn\\.segment\\.com",
        "api\\.segment\\.io",
        "cdn\\.mxpnl\\.com"
    ]

    /// WebKit content rules intentionally support a restricted regular-expression
    /// grammar. Each domain/path gets its own rule so the source contains no regex
    /// alternation, which WebKit rejects at runtime even though the JSON is valid.
    static let encodedRuleList: String = {
        let domainRules = blockedDomainPatterns.map { domain in
            let pattern = "^https?://([^/]+\\.)?\(domain)/"
            let JSONPattern = pattern.replacingOccurrences(of: "\\", with: "\\\\")
            return #"{"trigger":{"url-filter":"\#(JSONPattern)"},"action":{"type":"block"}}"#
        }
        let pathRules = ["beacon", "pixel", "track", "tracking"].map { component in
            #"{"trigger":{"url-filter":"^https?://[^/]+/\#(component).*","resource-type":["image","script","raw"]},"action":{"type":"block"}}"#
        }
        let cosmeticRule = #"{"trigger":{"url-filter":".*"},"action":{"type":"css-display-none","selector":".adsbygoogle, [data-ad-slot], [id^='google_ads_'], [id^='div-gpt-ad-'], .ad-banner"}}"#
        return "[" + (domainRules + pathRules + [cosmeticRule]).joined(separator: ",") + "]"
    }()

    let identifier: String

    private let store: WKContentRuleListStore?
    private var cachedRuleList: WKContentRuleList?

    init(
        identifier: String = "com.overture.browser.content-blocker.v1",
        store: WKContentRuleListStore? = nil
    ) {
        self.identifier = identifier
        self.store = store ?? WKContentRuleListStore.default()
    }

    /// Returns a persisted compiled rule list, compiling the bundled source when needed.
    func ruleList(forceRecompile: Bool = false) async throws -> WKContentRuleList {
        guard let store else {
            throw ServiceError.ruleListStoreUnavailable
        }

        if !forceRecompile, let cachedRuleList {
            return cachedRuleList
        }

        if !forceRecompile {
            do {
                if let storedRuleList = try await store.contentRuleList(forIdentifier: identifier) {
                    cachedRuleList = storedRuleList
                    return storedRuleList
                }
            } catch {
                // A missing or stale persisted list is repaired by compiling the source below.
            }
        } else {
            cachedRuleList = nil
            try? await store.removeContentRuleList(forIdentifier: identifier)
        }

        guard let compiledRuleList = try await store.compileContentRuleList(
            forIdentifier: identifier,
            encodedContentRuleList: Self.encodedRuleList
        ) else {
            throw ServiceError.compilationReturnedNoRuleList
        }

        cachedRuleList = compiledRuleList
        return compiledRuleList
    }

    /// Idempotently installs the built-in rules into a web view's user-content controller.
    func install(in userContentController: WKUserContentController) async throws {
        let ruleList = try await ruleList()
        userContentController.remove(ruleList)
        userContentController.add(ruleList)
    }

    /// Removes the built-in rules from one web view without deleting the compiled cache.
    func remove(from userContentController: WKUserContentController) async {
        if let cachedRuleList {
            userContentController.remove(cachedRuleList)
            return
        }

        guard let store else { return }
        guard let storedRuleList = try? await store.contentRuleList(forIdentifier: identifier) else {
            return
        }
        cachedRuleList = storedRuleList
        userContentController.remove(storedRuleList)
    }
}
