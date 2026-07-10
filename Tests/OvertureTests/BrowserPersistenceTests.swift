import Foundation
import XCTest
@testable import Overture

final class BrowserPersistenceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OverturePersistenceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testDefaultProfileIsDeterministicAndImmediatelyUsable() async throws {
        XCTAssertEqual(BrowserProfile.defaultProfile, BrowserProfile.defaultProfile)

        let persistence = BrowserPersistence(directoryURL: temporaryDirectory)
        let profile = try await persistence.load()

        XCTAssertEqual(profile, .defaultProfile)
        XCTAssertEqual(profile.schemaVersion, BrowserProfile.currentSchemaVersion)
        XCTAssertEqual(profile.workspaces.count, 1)
        XCTAssertEqual(profile.session.tabs.count, 1)
        XCTAssertEqual(profile.session.tabs.first?.url.absoluteString, "overture://start")
        XCTAssertEqual(profile.workspaces.first?.selectedTabID, profile.session.activeTabID)
        let exists = await persistence.profileExists()
        XCTAssertFalse(exists, "Loading a missing profile should not write behind the caller's back")
    }

    func testRoundTripsCompleteProfileThroughAtomicJSONFile() async throws {
        let profile = makeCompleteProfile()
        let persistence = BrowserPersistence(
            directoryURL: temporaryDirectory.appendingPathComponent("nested", isDirectory: true)
        )

        try await persistence.save(profile)
        let restored = try await persistence.load()

        XCTAssertEqual(restored, profile.persistableCopy())
        XCTAssertTrue(FileManager.default.fileExists(atPath: persistence.fileURL.path))
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: persistence.directoryURL.path),
            [BrowserPersistence.defaultFileName]
        )
    }

    func testCorruptedJSONThrowsWithoutReplacingTheFile() async throws {
        let persistence = BrowserPersistence(directoryURL: temporaryDirectory)
        let corruptData = Data("{ definitely-not-json".utf8)
        try corruptData.write(to: persistence.fileURL)

        do {
            _ = try await persistence.load()
            XCTFail("Expected corrupted data to be rejected")
        } catch let error as BrowserPersistenceError {
            guard case .corruptedProfile = error else {
                return XCTFail("Unexpected persistence error: \(error)")
            }
        }

        XCTAssertEqual(try Data(contentsOf: persistence.fileURL), corruptData)
    }

    func testFutureSchemaVersionIsRejected() async throws {
        let persistence = BrowserPersistence(directoryURL: temporaryDirectory)
        try Data("{\"schemaVersion\":999}".utf8).write(to: persistence.fileURL)

        do {
            _ = try await persistence.load()
            XCTFail("Expected a future schema to be rejected")
        } catch let error as BrowserPersistenceError {
            XCTAssertEqual(
                error,
                .unsupportedSchemaVersion(
                    found: 999,
                    supported: BrowserProfile.currentSchemaVersion
                )
            )
        }
    }

    func testSaveExcludesPrivateTabsAndRepairsTheirReferences() async throws {
        let workspaceID = UUID()
        let publicTab = BrowserTabSnapshot(
            workspaceID: workspaceID,
            url: URL(string: "https://example.com")!,
            title: "Public"
        )
        let privateTab = BrowserTabSnapshot(
            workspaceID: workspaceID,
            url: URL(string: "https://private.example")!,
            title: "Private",
            isPrivate: true
        )
        let island = TabIslandRecord(
            workspaceID: workspaceID,
            name: "Mixed",
            tabIDs: [publicTab.id, privateTab.id]
        )
        let split = SplitSessionSnapshot(
            workspaceID: workspaceID,
            tabIDs: [publicTab.id, privateTab.id],
            focusedTabID: privateTab.id
        )
        let workspace = WorkspaceRecord(
            id: workspaceID,
            name: "Personal",
            tabIDs: [publicTab.id, privateTab.id],
            islandIDs: [island.id],
            splitSessionIDs: [split.id],
            selectedTabID: privateTab.id
        )
        let profile = BrowserProfile(
            workspaces: [workspace],
            tabIslands: [island],
            session: BrowserSessionSnapshot(
                tabs: [publicTab, privateTab],
                activeTabID: privateTab.id,
                activeWorkspaceID: workspaceID,
                recentlyClosedTabs: [privateTab],
                splitSessions: [split]
            )
        )
        let persistence = BrowserPersistence(directoryURL: temporaryDirectory)

        try await persistence.save(profile)
        let restored = try await persistence.load()

        XCTAssertEqual(restored.session.tabs.map(\.id), [publicTab.id])
        XCTAssertEqual(restored.session.activeTabID, publicTab.id)
        XCTAssertTrue(restored.session.recentlyClosedTabs.isEmpty)
        XCTAssertTrue(restored.session.splitSessions.isEmpty)
        XCTAssertEqual(restored.workspaces.first?.tabIDs, [publicTab.id])
        XCTAssertEqual(restored.workspaces.first?.selectedTabID, publicTab.id)
        XCTAssertEqual(restored.tabIslands.first?.tabIDs, [publicTab.id])
    }

    func testResetRemovesSavedProfile() async throws {
        let persistence = BrowserPersistence(directoryURL: temporaryDirectory)
        try await persistence.save(.defaultProfile)
        try await persistence.reset()

        let exists = await persistence.profileExists()
        XCTAssertFalse(exists)
        let restored = try await persistence.load()
        XCTAssertEqual(restored, .defaultProfile)
    }

    private func makeCompleteProfile() -> BrowserProfile {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let workspaceID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let tabID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        let secondTabID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        let islandID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        let splitID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        let firstTab = BrowserTabSnapshot(
            id: tabID,
            workspaceID: workspaceID,
            islandID: islandID,
            url: URL(string: "https://example.com")!,
            title: "Example",
            faviconURL: URL(string: "https://example.com/favicon.ico"),
            isPinned: true,
            zoomScale: 1.25,
            lastViewedAt: date
        )
        let secondTab = BrowserTabSnapshot(
            id: secondTabID,
            workspaceID: workspaceID,
            islandID: islandID,
            url: URL(string: "https://example.org")!,
            title: "Reference",
            sortIndex: 1,
            lastViewedAt: date
        )
        let island = TabIslandRecord(
            id: islandID,
            workspaceID: workspaceID,
            name: "Research",
            colorHex: "#123456",
            tabIDs: [tabID, secondTabID],
            isCollapsed: true,
            createdAt: date,
            modifiedAt: date
        )
        let split = SplitSessionSnapshot(
            id: splitID,
            workspaceID: workspaceID,
            tabIDs: [tabID, secondTabID],
            focusedTabID: secondTabID,
            createdAt: date,
            modifiedAt: date
        )
        let workspace = WorkspaceRecord(
            id: workspaceID,
            name: "Research",
            tabIDs: [tabID, secondTabID],
            islandIDs: [islandID],
            splitSessionIDs: [splitID],
            selectedTabID: secondTabID,
            createdAt: date,
            modifiedAt: date
        )

        return BrowserProfile(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            createdAt: date,
            updatedAt: date,
            workspaces: [workspace],
            tabIslands: [island],
            bookmarks: [BookmarkRecord(
                title: "Swift",
                url: URL(string: "https://swift.org")!,
                folderName: "Development",
                tags: ["language"],
                createdAt: date,
                modifiedAt: date
            )],
            history: [HistoryRecord(
                title: "Example",
                url: URL(string: "https://example.com")!,
                visitCount: 3,
                firstVisitedAt: date,
                lastVisitedAt: date
            )],
            speedDials: [SpeedDialRecord(
                title: "Reference",
                url: URL(string: "https://example.org")!,
                sortIndex: 2,
                createdAt: date,
                modifiedAt: date
            )],
            downloads: [DownloadRecord(
                sourceURL: URL(string: "https://example.com/archive.zip")!,
                destinationURL: URL(fileURLWithPath: "/tmp/archive.zip"),
                suggestedFilename: "archive.zip",
                mimeType: "application/zip",
                state: .completed,
                bytesReceived: 42,
                totalBytesExpected: 42,
                progress: 1,
                startedAt: date,
                updatedAt: date,
                completedAt: date
            )],
            pinboardNotes: [PinboardNoteRecord(
                title: "Read later",
                body: "Compare both references",
                linkedURL: URL(string: "https://example.com"),
                positionX: 12,
                positionY: 34,
                createdAt: date,
                modifiedAt: date
            )],
            session: BrowserSessionSnapshot(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                tabs: [firstTab, secondTab],
                activeTabID: secondTabID,
                activeWorkspaceID: workspaceID,
                splitSessions: [split],
                savedAt: date
            )
        )
    }
}
