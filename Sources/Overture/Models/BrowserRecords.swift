import Foundation

struct WorkspaceRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var tabIDs: [UUID]
    var islandIDs: [UUID]
    var splitSessionIDs: [UUID]
    var selectedTabID: UUID?
    var isVisible: Bool
    var sortIndex: Int
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "square.grid.2x2",
        colorHex: String = "#7C5CFC",
        tabIDs: [UUID] = [],
        islandIDs: [UUID] = [],
        splitSessionIDs: [UUID] = [],
        selectedTabID: UUID? = nil,
        isVisible: Bool = true,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.tabIDs = tabIDs
        self.islandIDs = islandIDs
        self.splitSessionIDs = splitSessionIDs
        self.selectedTabID = selectedTabID
        self.isVisible = isVisible
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct BrowserTabSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var workspaceID: UUID
    var islandID: UUID?
    var url: URL
    var title: String
    var faviconURL: URL?
    var isPinned: Bool
    var isMuted: Bool
    var isPlayingAudio: Bool
    var isPrivate: Bool
    var isDiscarded: Bool
    var zoomScale: Double
    var sortIndex: Int
    var lastViewedAt: Date

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        islandID: UUID? = nil,
        url: URL = URL(string: "overture://start")!,
        title: String = "Start Page",
        faviconURL: URL? = nil,
        isPinned: Bool = false,
        isMuted: Bool = false,
        isPlayingAudio: Bool = false,
        isPrivate: Bool = false,
        isDiscarded: Bool = false,
        zoomScale: Double = 1,
        sortIndex: Int = 0,
        lastViewedAt: Date = Date()
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.islandID = islandID
        self.url = url
        self.title = title
        self.faviconURL = faviconURL
        self.isPinned = isPinned
        self.isMuted = isMuted
        self.isPlayingAudio = isPlayingAudio
        self.isPrivate = isPrivate
        self.isDiscarded = isDiscarded
        self.zoomScale = zoomScale
        self.sortIndex = sortIndex
        self.lastViewedAt = lastViewedAt
    }
}

struct TabIslandRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var workspaceID: UUID
    var name: String
    var colorHex: String
    var tabIDs: [UUID]
    var isCollapsed: Bool
    var sortIndex: Int
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        name: String,
        colorHex: String = "#2CC9B7",
        tabIDs: [UUID] = [],
        isCollapsed: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.name = name
        self.colorHex = colorHex
        self.tabIDs = tabIDs
        self.isCollapsed = isCollapsed
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct BookmarkRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var url: URL
    var folderName: String?
    var tags: [String]
    var sortIndex: Int
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        folderName: String? = nil,
        tags: [String] = [],
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.folderName = folderName
        self.tags = tags
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct HistoryRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var url: URL
    var visitCount: Int
    var firstVisitedAt: Date
    var lastVisitedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        visitCount: Int = 1,
        firstVisitedAt: Date = Date(),
        lastVisitedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.visitCount = visitCount
        self.firstVisitedAt = firstVisitedAt
        self.lastVisitedAt = lastVisitedAt
    }
}

struct SpeedDialRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var url: URL
    var thumbnailURL: URL?
    var colorHex: String
    var sortIndex: Int
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        thumbnailURL: URL? = nil,
        colorHex: String = "#3B3A50",
        sortIndex: Int = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

enum DownloadState: String, Codable, CaseIterable, Hashable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

struct DownloadRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var sourceURL: URL
    var destinationURL: URL?
    var suggestedFilename: String
    var mimeType: String?
    var state: DownloadState
    var bytesReceived: Int64
    var totalBytesExpected: Int64?
    var progress: Double
    var errorDescription: String?
    var startedAt: Date
    var updatedAt: Date
    var completedAt: Date?

    var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        destinationURL: URL? = nil,
        suggestedFilename: String,
        mimeType: String? = nil,
        state: DownloadState = .queued,
        bytesReceived: Int64 = 0,
        totalBytesExpected: Int64? = nil,
        progress: Double = 0,
        errorDescription: String? = nil,
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.suggestedFilename = suggestedFilename
        self.mimeType = mimeType
        self.state = state
        self.bytesReceived = bytesReceived
        self.totalBytesExpected = totalBytesExpected
        self.progress = progress
        self.errorDescription = errorDescription
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

struct PinboardNoteRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var body: String
    var linkedURL: URL?
    var imageURL: URL?
    var colorHex: String
    var positionX: Double
    var positionY: Double
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        body: String,
        linkedURL: URL? = nil,
        imageURL: URL? = nil,
        colorHex: String = "#FFE08A",
        positionX: Double = 0,
        positionY: Double = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.linkedURL = linkedURL
        self.imageURL = imageURL
        self.colorHex = colorHex
        self.positionX = positionX
        self.positionY = positionY
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

enum SplitLayout: String, Codable, CaseIterable, Hashable, Sendable {
    case twoColumns
    case twoRows
    case threeColumns
    case mainLeft
    case mainRight
    case fourGrid

    var paneCount: Int {
        switch self {
        case .twoColumns, .twoRows:
            2
        case .threeColumns, .mainLeft, .mainRight:
            3
        case .fourGrid:
            4
        }
    }
}

struct SplitSessionSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var workspaceID: UUID
    var tabIDs: [UUID]
    var layout: SplitLayout
    var focusedTabID: UUID?
    var dividerFractions: [Double]
    var createdAt: Date
    var modifiedAt: Date

    init(
        id: UUID = UUID(),
        workspaceID: UUID,
        tabIDs: [UUID],
        layout: SplitLayout = .twoColumns,
        focusedTabID: UUID? = nil,
        dividerFractions: [Double] = [0.5],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.workspaceID = workspaceID
        self.tabIDs = tabIDs
        self.layout = layout
        self.focusedTabID = focusedTabID
        self.dividerFractions = dividerFractions
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

struct BrowserSessionSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var tabs: [BrowserTabSnapshot]
    var activeTabID: UUID?
    var activeWorkspaceID: UUID?
    var recentlyClosedTabs: [BrowserTabSnapshot]
    var splitSessions: [SplitSessionSnapshot]
    var savedAt: Date

    init(
        id: UUID = UUID(),
        tabs: [BrowserTabSnapshot] = [],
        activeTabID: UUID? = nil,
        activeWorkspaceID: UUID? = nil,
        recentlyClosedTabs: [BrowserTabSnapshot] = [],
        splitSessions: [SplitSessionSnapshot] = [],
        savedAt: Date = Date()
    ) {
        self.id = id
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.activeWorkspaceID = activeWorkspaceID
        self.recentlyClosedTabs = recentlyClosedTabs
        self.splitSessions = splitSessions
        self.savedAt = savedAt
    }

    /// Returns the restorable portion of a session. Private tabs are never part
    /// of the result, including recently closed tabs and split-view references.
    func persistableCopy() -> BrowserSessionSnapshot {
        let persistentTabs = tabs.filter { !$0.isPrivate }
        let persistentTabIDs = Set(persistentTabs.map(\.id))
        let persistentClosedTabs = recentlyClosedTabs.filter { !$0.isPrivate }

        let persistentSplits = splitSessions.compactMap { split -> SplitSessionSnapshot? in
            var seen = Set<UUID>()
            var copy = split
            copy.tabIDs = split.tabIDs.filter {
                persistentTabIDs.contains($0) && seen.insert($0).inserted
            }

            guard copy.tabIDs.count >= 2 else { return nil }
            if let focusedTabID = copy.focusedTabID,
               !copy.tabIDs.contains(focusedTabID) {
                copy.focusedTabID = copy.tabIDs.first
            }
            return copy
        }

        let selectedTabID = activeTabID.flatMap {
            persistentTabIDs.contains($0) ? $0 : nil
        } ?? persistentTabs.first?.id

        let selectedWorkspaceID: UUID?
        if let activeWorkspaceID,
           persistentTabs.isEmpty || persistentTabs.contains(where: { $0.workspaceID == activeWorkspaceID }) {
            selectedWorkspaceID = activeWorkspaceID
        } else {
            selectedWorkspaceID = persistentTabs.first?.workspaceID
        }

        return BrowserSessionSnapshot(
            id: id,
            tabs: persistentTabs,
            activeTabID: selectedTabID,
            activeWorkspaceID: selectedWorkspaceID,
            recentlyClosedTabs: persistentClosedTabs,
            splitSessions: persistentSplits,
            savedAt: savedAt
        )
    }
}

struct BrowserProfile: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var workspaces: [WorkspaceRecord]
    var tabIslands: [TabIslandRecord]
    var bookmarks: [BookmarkRecord]
    var history: [HistoryRecord]
    var speedDials: [SpeedDialRecord]
    var downloads: [DownloadRecord]
    var pinboardNotes: [PinboardNoteRecord]
    var session: BrowserSessionSnapshot

    init(
        schemaVersion: Int = BrowserProfile.currentSchemaVersion,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        workspaces: [WorkspaceRecord] = [],
        tabIslands: [TabIslandRecord] = [],
        bookmarks: [BookmarkRecord] = [],
        history: [HistoryRecord] = [],
        speedDials: [SpeedDialRecord] = [],
        downloads: [DownloadRecord] = [],
        pinboardNotes: [PinboardNoteRecord] = [],
        session: BrowserSessionSnapshot = BrowserSessionSnapshot()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.workspaces = workspaces
        self.tabIslands = tabIslands
        self.bookmarks = bookmarks
        self.history = history
        self.speedDials = speedDials
        self.downloads = downloads
        self.pinboardNotes = pinboardNotes
        self.session = session
    }

    /// Stable identifiers and timestamps keep first-launch behavior and tests
    /// reproducible. Callers may replace them after creating a user profile.
    static var defaultProfile: BrowserProfile {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let workspaceID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        let baseline = Date(timeIntervalSince1970: 0)

        let tab = BrowserTabSnapshot(
            id: tabID,
            workspaceID: workspaceID,
            url: URL(string: "overture://start")!,
            title: "Start Page",
            lastViewedAt: baseline
        )
        let workspace = WorkspaceRecord(
            id: workspaceID,
            name: "Personal",
            symbolName: "house",
            tabIDs: [tabID],
            selectedTabID: tabID,
            createdAt: baseline,
            modifiedAt: baseline
        )
        let session = BrowserSessionSnapshot(
            id: sessionID,
            tabs: [tab],
            activeTabID: tabID,
            activeWorkspaceID: workspaceID,
            savedAt: baseline
        )

        return BrowserProfile(
            id: profileID,
            createdAt: baseline,
            updatedAt: baseline,
            workspaces: [workspace],
            session: session
        )
    }

    /// Removes private data and repairs record references before serialization.
    func persistableCopy() -> BrowserProfile {
        var copy = self
        copy.session = session.persistableCopy()

        let workspaceIDs = Set(copy.workspaces.map(\.id))
        copy.session.tabs.removeAll { !workspaceIDs.contains($0.workspaceID) }
        copy.session = copy.session.persistableCopy()

        let tabIDs = Set(copy.session.tabs.map(\.id))
        copy.tabIslands = copy.tabIslands.compactMap { island in
            guard workspaceIDs.contains(island.workspaceID) else { return nil }
            var sanitizedIsland = island
            sanitizedIsland.tabIDs = island.tabIDs.filter(tabIDs.contains)
            return sanitizedIsland
        }

        let islandsByID = copy.tabIslands.reduce(into: [UUID: TabIslandRecord]()) {
            $0[$1.id] = $1
        }
        copy.session.tabs = copy.session.tabs.map { tab in
            var sanitizedTab = tab
            if let islandID = tab.islandID,
               islandsByID[islandID]?.tabIDs.contains(tab.id) != true {
                sanitizedTab.islandID = nil
            }
            return sanitizedTab
        }

        let splitSessionIDs = Set(copy.session.splitSessions.map(\.id))
        let islandsByWorkspace = Dictionary(grouping: copy.tabIslands, by: \.workspaceID)
        let tabsByWorkspace = Dictionary(grouping: copy.session.tabs, by: \.workspaceID)

        copy.workspaces = copy.workspaces.map { workspace in
            var sanitizedWorkspace = workspace
            let workspaceTabs = tabsByWorkspace[workspace.id] ?? []
            let workspaceTabIDs = Set(workspaceTabs.map(\.id))
            let listedTabIDs = workspace.tabIDs.filter(workspaceTabIDs.contains)
            let listedSet = Set(listedTabIDs)
            let unlistedTabIDs = workspaceTabs
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(\.id)
                .filter { !listedSet.contains($0) }

            sanitizedWorkspace.tabIDs = listedTabIDs + unlistedTabIDs
            sanitizedWorkspace.islandIDs = (islandsByWorkspace[workspace.id] ?? []).map(\.id)
            sanitizedWorkspace.splitSessionIDs = workspace.splitSessionIDs.filter(splitSessionIDs.contains)

            if let selectedTabID = workspace.selectedTabID,
               workspaceTabIDs.contains(selectedTabID) {
                sanitizedWorkspace.selectedTabID = selectedTabID
            } else {
                sanitizedWorkspace.selectedTabID = sanitizedWorkspace.tabIDs.first
            }
            return sanitizedWorkspace
        }

        if let activeWorkspaceID = copy.session.activeWorkspaceID,
           !workspaceIDs.contains(activeWorkspaceID) {
            copy.session.activeWorkspaceID = copy.workspaces.first?.id
        }

        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case createdAt
        case updatedAt
        case workspaces
        case tabIslands
        case bookmarks
        case history
        case speedDials
        case downloads
        case pinboardNotes
        case session
    }

    init(from decoder: Decoder) throws {
        let defaults = BrowserProfile.defaultProfile
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? BrowserProfile.currentSchemaVersion
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? defaults.id
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? defaults.createdAt
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? defaults.updatedAt
        workspaces = try container.decodeIfPresent([WorkspaceRecord].self, forKey: .workspaces)
            ?? defaults.workspaces
        tabIslands = try container.decodeIfPresent([TabIslandRecord].self, forKey: .tabIslands) ?? []
        bookmarks = try container.decodeIfPresent([BookmarkRecord].self, forKey: .bookmarks) ?? []
        history = try container.decodeIfPresent([HistoryRecord].self, forKey: .history) ?? []
        speedDials = try container.decodeIfPresent([SpeedDialRecord].self, forKey: .speedDials) ?? []
        downloads = try container.decodeIfPresent([DownloadRecord].self, forKey: .downloads) ?? []
        pinboardNotes = try container.decodeIfPresent([PinboardNoteRecord].self, forKey: .pinboardNotes) ?? []
        session = try container.decodeIfPresent(BrowserSessionSnapshot.self, forKey: .session)
            ?? defaults.session
    }
}
