import Foundation
import XCTest
@testable import Overture

@MainActor
final class BrowserStoreTests: XCTestCase {
    func testStartHydratesDefaultProfileWithASelectedStableTab() async throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }

        await fixture.store.start()

        XCTAssertEqual(fixture.store.workspaces.count, 1)
        XCTAssertEqual(fixture.store.tabs.count, 1)
        XCTAssertEqual(fixture.store.selectedTabID, fixture.store.tabs.first?.id)
        XCTAssertEqual(fixture.store.selectedTab?.webView, fixture.store.tabs.first?.webView)
        XCTAssertEqual(fixture.store.currentWorkspaceTabs.map(\.id), fixture.store.tabs.map(\.id))
        XCTAssertFalse(fixture.store.isLoading)
        XCTAssertNil(fixture.store.persistenceError)
    }

    func testTabsIslandsAndSplitStateStayConsistent() async throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        await fixture.store.start()

        let first = try XCTUnwrap(fixture.store.selectedTab)
        let second = fixture.store.newTab(select: true)
        let island = try XCTUnwrap(
            fixture.store.createTabIsland(name: "Research", tabIDs: [first.id, second.id])
        )

        XCTAssertEqual(Set(island.tabIDs), Set([first.id, second.id]))
        XCTAssertEqual(first.groupID, island.id)
        XCTAssertEqual(second.groupID, island.id)
        XCTAssertTrue(fixture.store.enterSplit(with: [first.id, second.id], layout: .twoColumns))
        XCTAssertEqual(fixture.store.splitTabIDs, [first.id, second.id])
        XCTAssertEqual(fixture.store.focusedSplitTabID, first.id)

        fixture.store.swapSplitTabs(first.id, second.id)
        fixture.store.focusSplitTab(second.id)
        fixture.store.setTabIslandCollapsed(true, id: island.id)

        XCTAssertEqual(fixture.store.splitTabIDs, [second.id, first.id])
        XCTAssertEqual(fixture.store.selectedTabID, second.id)
        XCTAssertEqual(fixture.store.tabIslands.first(where: { $0.id == island.id })?.isCollapsed, true)

        let outsideSplit = fixture.store.newTab(isPrivate: true)
        XCTAssertEqual(fixture.store.selectedTabID, outsideSplit.id)
        XCTAssertFalse(fixture.store.isSplitViewActive)
        XCTAssertTrue(fixture.store.splitTabIDs.isEmpty)
        await fixture.store.flushPersistence()
    }

    func testPrivateTabsNeverEnterHistoryRecentlyClosedOrPersistedSession() async throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        await fixture.store.start()

        let privateTab = fixture.store.newTab(isPrivate: true)
        fixture.store.handleTabEvent(
            .history(BrowserTabController.HistoryVisit(
                url: URL(string: "https://private.example")!,
                title: "Private"
            )),
            from: privateTab.id
        )
        fixture.store.closeTab(id: privateTab.id)
        await fixture.store.flushPersistence()

        XCTAssertTrue(fixture.store.history.isEmpty)
        XCTAssertTrue(fixture.store.recentlyClosedTabs.allSatisfy { !$0.isPrivate })

        let saved = try await fixture.persistence.load()
        XCTAssertFalse(saved.session.tabs.contains { $0.id == privateTab.id || $0.isPrivate })
        XCTAssertFalse(saved.session.recentlyClosedTabs.contains { $0.id == privateTab.id })
        XCTAssertTrue(saved.history.isEmpty)
    }

    func testLibraryCRUDPersistsOnExplicitFlush() async throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        await fixture.store.start()

        let bookmark = fixture.store.addBookmark(
            url: URL(string: "https://swift.org")!,
            title: "Swift"
        )
        let speedDial = fixture.store.addSpeedDial(
            url: URL(string: "https://example.com")!,
            title: "Example"
        )
        let note = fixture.store.addPinboardNote(
            title: "Read",
            body: "Review the language guide",
            linkedURL: bookmark.url
        )
        fixture.store.recordHistory(
            BrowserTabController.HistoryVisit(url: bookmark.url, title: bookmark.title)
        )
        await fixture.store.flushPersistence()

        let saved = try await fixture.persistence.load()
        XCTAssertEqual(saved.bookmarks.map(\.id), [bookmark.id])
        XCTAssertEqual(saved.speedDials.map(\.id), [speedDial.id])
        XCTAssertEqual(saved.pinboardNotes.map(\.id), [note.id])
        XCTAssertEqual(saved.history.first?.url, bookmark.url)
    }

    func testDownloadEventsUpdateOneTypedRecord() async throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        await fixture.store.start()
        let tabID = try XCTUnwrap(fixture.store.selectedTabID)
        let downloadID = UUID()
        let sourceURL = URL(string: "https://example.com/archive.zip")!
        let destinationURL = fixture.directory.appendingPathComponent("archive.zip")
        let item = BrowserTabController.DownloadItem(
            id: downloadID,
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            filename: "archive.zip",
            startedAt: Date()
        )

        fixture.store.handleTabEvent(.download(.started(item)), from: tabID)
        fixture.store.handleTabEvent(
            .download(.progress(id: downloadID, fractionCompleted: 0.5)),
            from: tabID
        )
        fixture.store.handleTabEvent(
            .download(.finished(id: downloadID, destinationURL: destinationURL)),
            from: tabID
        )

        let record = try XCTUnwrap(fixture.store.downloads.first)
        XCTAssertEqual(record.id, downloadID)
        XCTAssertEqual(record.sourceURL, sourceURL)
        XCTAssertEqual(record.state, .completed)
        XCTAssertEqual(record.progress, 1)
        XCTAssertEqual(record.destinationURL, destinationURL)
        await fixture.store.flushPersistence()
    }

    func testSessionRoundTripRestoresWorkspaceSelectionAndSplit() async throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        await fixture.store.start()

        let first = try XCTUnwrap(fixture.store.selectedTab)
        let second = fixture.store.newTab()
        XCTAssertTrue(fixture.store.enterSplit(with: [first.id, second.id], layout: .twoRows))
        fixture.store.focusSplitTab(second.id)
        await fixture.store.flushPersistence()

        let defaults = UserDefaults(suiteName: fixture.suiteName)!
        let preferences = BrowserPreferences(defaults: defaults)
        preferences.trackerBlockingEnabled = false
        preferences.adBlockingEnabled = false
        let restored = BrowserStore(
            persistence: fixture.persistence,
            preferences: preferences,
            persistenceDebounce: .seconds(60)
        )
        await restored.start()

        XCTAssertEqual(Set(restored.tabs.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(restored.selectedTabID, second.id)
        XCTAssertEqual(restored.splitTabIDs, [first.id, second.id])
        XCTAssertEqual(restored.splitLayout, .twoRows)
        XCTAssertEqual(restored.focusedSplitTabID, second.id)
    }

    private func makeFixture() -> Fixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OvertureStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let persistence = BrowserPersistence(directoryURL: directory)
        let suiteName = "OvertureStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let preferences = BrowserPreferences(defaults: defaults)
        preferences.trackerBlockingEnabled = false
        preferences.adBlockingEnabled = false
        let store = BrowserStore(
            persistence: persistence,
            preferences: preferences,
            persistenceDebounce: .seconds(60)
        )
        return Fixture(
            directory: directory,
            suiteName: suiteName,
            persistence: persistence,
            store: store
        )
    }
}

@MainActor
private struct Fixture {
    let directory: URL
    let suiteName: String
    let persistence: BrowserPersistence
    let store: BrowserStore

    func cleanup() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}
