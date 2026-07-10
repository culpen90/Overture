import XCTest
@testable import Overture

@MainActor
final class BrowserPreferencesTests: XCTestCase {
    func testDefaultsFavorPrivateAndSafeBrowsing() {
        withDefaults { defaults in
            let preferences = BrowserPreferences(defaults: defaults)

            XCTAssertEqual(preferences.appearance, .system)
            XCTAssertEqual(preferences.accent, .overture)
            XCTAssertEqual(preferences.searchProvider, .duckDuckGo)
            XCTAssertTrue(preferences.httpsFirst)
            XCTAssertTrue(preferences.trackerBlockingEnabled)
            XCTAssertTrue(preferences.adBlockingEnabled)
            XCTAssertTrue(preferences.restorePreviousSession)
            XCTAssertTrue(preferences.sidebarVisible)
            XCTAssertEqual(preferences.tabLayout, .horizontal)
            XCTAssertTrue(preferences.askWhereToSaveDownloads)
            XCTAssertEqual(preferences.pageZoom, 1, accuracy: 0.001)
            XCTAssertTrue(preferences.saveBrowsingHistory)
            XCTAssertFalse(preferences.clearHistoryOnQuit)
            XCTAssertFalse(preferences.alwaysUsePrivateBrowsing)
            XCTAssertFalse(preferences.downloadLocation.isEmpty)
        }
    }

    func testChangesPersistAcrossInstances() {
        withDefaults { defaults in
            let preferences = BrowserPreferences(defaults: defaults)
            preferences.appearance = .dark
            preferences.accent = .teal
            preferences.searchProvider = .brave
            preferences.httpsFirst = false
            preferences.trackerBlockingEnabled = false
            preferences.adBlockingEnabled = false
            preferences.restorePreviousSession = false
            preferences.sidebarVisible = false
            preferences.tabLayout = .vertical
            preferences.downloadLocation = "/tmp/Overture Downloads"
            preferences.askWhereToSaveDownloads = true
            preferences.pageZoom = 1.35
            preferences.saveBrowsingHistory = false
            preferences.clearHistoryOnQuit = true
            preferences.alwaysUsePrivateBrowsing = true

            let restored = BrowserPreferences(defaults: defaults)
            XCTAssertEqual(restored.appearance, .dark)
            XCTAssertEqual(restored.accent, .teal)
            XCTAssertEqual(restored.searchProvider, .brave)
            XCTAssertFalse(restored.httpsFirst)
            XCTAssertFalse(restored.trackerBlockingEnabled)
            XCTAssertFalse(restored.adBlockingEnabled)
            XCTAssertFalse(restored.restorePreviousSession)
            XCTAssertFalse(restored.sidebarVisible)
            XCTAssertEqual(restored.tabLayout, .vertical)
            XCTAssertEqual(restored.downloadLocation, "/tmp/Overture Downloads")
            XCTAssertTrue(restored.askWhereToSaveDownloads)
            XCTAssertEqual(restored.pageZoom, 1.35, accuracy: 0.001)
            XCTAssertFalse(restored.saveBrowsingHistory)
            XCTAssertTrue(restored.clearHistoryOnQuit)
            XCTAssertTrue(restored.alwaysUsePrivateBrowsing)
        }
    }

    func testPageZoomIsClampedBeforePersistence() {
        withDefaults { defaults in
            let preferences = BrowserPreferences(defaults: defaults)
            preferences.pageZoom = 8
            XCTAssertEqual(preferences.pageZoom, 2, accuracy: 0.001)

            let restored = BrowserPreferences(defaults: defaults)
            XCTAssertEqual(restored.pageZoom, 2, accuracy: 0.001)

            preferences.pageZoom = .nan
            XCTAssertEqual(preferences.pageZoom, 1, accuracy: 0.001)
        }
    }

    func testResetRestoresAllDefaults() {
        withDefaults { defaults in
            let preferences = BrowserPreferences(defaults: defaults)
            preferences.appearance = .dark
            preferences.accent = .orange
            preferences.searchProvider = .google
            preferences.httpsFirst = false
            preferences.pageZoom = 1.8
            preferences.alwaysUsePrivateBrowsing = true

            preferences.resetToDefaults()

            XCTAssertEqual(preferences.appearance, .system)
            XCTAssertEqual(preferences.accent, .overture)
            XCTAssertEqual(preferences.searchProvider, .duckDuckGo)
            XCTAssertTrue(preferences.httpsFirst)
            XCTAssertEqual(preferences.pageZoom, 1, accuracy: 0.001)
            XCTAssertFalse(preferences.alwaysUsePrivateBrowsing)
        }
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "BrowserPreferencesTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}
