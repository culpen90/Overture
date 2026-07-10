import Combine
import Foundation

enum BrowserAppearance: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum BrowserAccent: String, Codable, CaseIterable, Identifiable {
    case overture
    case violet
    case blue
    case teal
    case green
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overture: "Overture"
        case .violet: "Violet"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .orange: "Orange"
        }
    }
}

enum BrowserTabLayout: String, Codable, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .horizontal: "Horizontal"
        case .vertical: "Vertical"
        }
    }
}

/// The single source of truth for user-configurable browser behavior.
///
/// The defaults store is injectable so tests and alternate profiles never need to
/// mutate `UserDefaults.standard`. WebKit-only state such as cookies and website
/// data intentionally does not live here.
@MainActor
final class BrowserPreferences: ObservableObject {
    private enum Key {
        static let appearance = "overture.preferences.appearance"
        static let accent = "overture.preferences.accent"
        static let searchProvider = "overture.preferences.searchProvider"
        static let httpsFirst = "overture.preferences.httpsFirst"
        static let trackerBlockingEnabled = "overture.preferences.trackerBlockingEnabled"
        static let adBlockingEnabled = "overture.preferences.adBlockingEnabled"
        static let restorePreviousSession = "overture.preferences.restorePreviousSession"
        static let sidebarVisible = "overture.preferences.sidebarVisible"
        static let tabLayout = "overture.preferences.tabLayout"
        static let downloadLocation = "overture.preferences.downloadLocation"
        static let askWhereToSaveDownloads = "overture.preferences.askWhereToSaveDownloads"
        static let pageZoom = "overture.preferences.pageZoom"
        static let saveBrowsingHistory = "overture.preferences.saveBrowsingHistory"
        static let clearHistoryOnQuit = "overture.preferences.clearHistoryOnQuit"
        static let alwaysUsePrivateBrowsing = "overture.preferences.alwaysUsePrivateBrowsing"
    }

    private let defaults: UserDefaults

    @Published var appearance: BrowserAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }

    @Published var accent: BrowserAccent {
        didSet { defaults.set(accent.rawValue, forKey: Key.accent) }
    }

    @Published var searchProvider: SearchProvider {
        didSet { defaults.set(searchProvider.rawValue, forKey: Key.searchProvider) }
    }

    @Published var httpsFirst: Bool {
        didSet { defaults.set(httpsFirst, forKey: Key.httpsFirst) }
    }

    @Published var trackerBlockingEnabled: Bool {
        didSet { defaults.set(trackerBlockingEnabled, forKey: Key.trackerBlockingEnabled) }
    }

    @Published var adBlockingEnabled: Bool {
        didSet { defaults.set(adBlockingEnabled, forKey: Key.adBlockingEnabled) }
    }

    @Published var restorePreviousSession: Bool {
        didSet { defaults.set(restorePreviousSession, forKey: Key.restorePreviousSession) }
    }

    @Published var sidebarVisible: Bool {
        didSet { defaults.set(sidebarVisible, forKey: Key.sidebarVisible) }
    }

    @Published var tabLayout: BrowserTabLayout {
        didSet { defaults.set(tabLayout.rawValue, forKey: Key.tabLayout) }
    }

    @Published var downloadLocation: String {
        didSet { defaults.set(downloadLocation, forKey: Key.downloadLocation) }
    }

    @Published var askWhereToSaveDownloads: Bool {
        didSet { defaults.set(askWhereToSaveDownloads, forKey: Key.askWhereToSaveDownloads) }
    }

    @Published var pageZoom: Double {
        didSet {
            let normalizedValue = Self.normalizedZoom(pageZoom)
            guard normalizedValue == pageZoom else {
                pageZoom = normalizedValue
                return
            }
            defaults.set(pageZoom, forKey: Key.pageZoom)
        }
    }

    @Published var saveBrowsingHistory: Bool {
        didSet { defaults.set(saveBrowsingHistory, forKey: Key.saveBrowsingHistory) }
    }

    @Published var clearHistoryOnQuit: Bool {
        didSet { defaults.set(clearHistoryOnQuit, forKey: Key.clearHistoryOnQuit) }
    }

    @Published var alwaysUsePrivateBrowsing: Bool {
        didSet { defaults.set(alwaysUsePrivateBrowsing, forKey: Key.alwaysUsePrivateBrowsing) }
    }

    var downloadDirectoryURL: URL {
        URL(fileURLWithPath: downloadLocation, isDirectory: true)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = BrowserAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        accent = BrowserAccent(rawValue: defaults.string(forKey: Key.accent) ?? "") ?? .overture
        searchProvider = SearchProvider(rawValue: defaults.string(forKey: Key.searchProvider) ?? "") ?? .duckDuckGo
        httpsFirst = Self.bool(forKey: Key.httpsFirst, in: defaults, fallback: true)
        trackerBlockingEnabled = Self.bool(forKey: Key.trackerBlockingEnabled, in: defaults, fallback: true)
        adBlockingEnabled = Self.bool(forKey: Key.adBlockingEnabled, in: defaults, fallback: true)
        restorePreviousSession = Self.bool(forKey: Key.restorePreviousSession, in: defaults, fallback: true)
        sidebarVisible = Self.bool(forKey: Key.sidebarVisible, in: defaults, fallback: true)
        tabLayout = BrowserTabLayout(rawValue: defaults.string(forKey: Key.tabLayout) ?? "") ?? .horizontal
        downloadLocation = defaults.string(forKey: Key.downloadLocation) ?? Self.defaultDownloadLocation
        askWhereToSaveDownloads = Self.bool(forKey: Key.askWhereToSaveDownloads, in: defaults, fallback: true)
        pageZoom = Self.normalizedZoom(
            defaults.object(forKey: Key.pageZoom) == nil ? 1 : defaults.double(forKey: Key.pageZoom)
        )
        saveBrowsingHistory = Self.bool(forKey: Key.saveBrowsingHistory, in: defaults, fallback: true)
        clearHistoryOnQuit = Self.bool(forKey: Key.clearHistoryOnQuit, in: defaults, fallback: false)
        alwaysUsePrivateBrowsing = Self.bool(forKey: Key.alwaysUsePrivateBrowsing, in: defaults, fallback: false)
    }

    func resetToDefaults() {
        appearance = .system
        accent = .overture
        searchProvider = .duckDuckGo
        httpsFirst = true
        trackerBlockingEnabled = true
        adBlockingEnabled = true
        restorePreviousSession = true
        sidebarVisible = true
        tabLayout = .horizontal
        downloadLocation = Self.defaultDownloadLocation
        askWhereToSaveDownloads = true
        pageZoom = 1
        saveBrowsingHistory = true
        clearHistoryOnQuit = false
        alwaysUsePrivateBrowsing = false
    }

    private static var defaultDownloadLocation: String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads").path
    }

    private static func bool(forKey key: String, in defaults: UserDefaults, fallback: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    private static func normalizedZoom(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, 0.5), 2)
    }
}
