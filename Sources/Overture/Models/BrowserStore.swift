import AppKit
import Combine
import Foundation
import WebKit

enum BrowserPersistenceStatus: String, Equatable, Sendable {
    case idle
    case loading
    case dirty
    case saving
    case saved
    case failed
}

@MainActor
final class BrowserStore: ObservableObject {
    enum StoreError: LocalizedError {
        case noSelectedTab
        case unknownWorkspace
        case invalidSplit

        var errorDescription: String? {
            switch self {
            case .noSelectedTab: "There is no selected browser tab."
            case .unknownWorkspace: "The requested workspace does not exist."
            case .invalidSplit: "Split view requires two to four tabs from one workspace."
            }
        }
    }

    let preferences: BrowserPreferences

    @Published private(set) var workspaces: [WorkspaceRecord]
    @Published private(set) var tabIslands: [TabIslandRecord]
    @Published private(set) var bookmarks: [BookmarkRecord]
    @Published private(set) var history: [HistoryRecord]
    @Published private(set) var speedDials: [SpeedDialRecord]
    @Published private(set) var downloads: [DownloadRecord]
    @Published private(set) var pinboardNotes: [PinboardNoteRecord]

    @Published private(set) var tabs: [BrowserTabController] = []
    @Published private(set) var selectedTabID: UUID?
    @Published private(set) var activeWorkspaceID: UUID?
    @Published private(set) var recentlyClosedTabs: [BrowserTabSnapshot]
    @Published var activeLibraryPanel: BrowserLibrarySection?
    @Published var isSidebarVisible: Bool {
        didSet { preferences.sidebarVisible = isSidebarVisible }
    }

    @Published private(set) var splitTabIDs: [UUID] = []
    @Published private(set) var splitLayout: SplitLayout = .twoColumns
    @Published private(set) var focusedSplitTabID: UUID?

    @Published private(set) var isLoading = false
    @Published private(set) var persistenceError: String?
    @Published private(set) var persistenceStatus: BrowserPersistenceStatus = .idle

    var selectedTab: BrowserTabController? {
        selectedTabID.flatMap { id in tabs.first { $0.id == id } }
    }

    var currentWorkspace: WorkspaceRecord? {
        activeWorkspaceID.flatMap { id in workspaces.first { $0.id == id } }
    }

    var currentWorkspaceTabs: [BrowserTabController] {
        guard let workspace = currentWorkspace else { return [] }
        let positions = Dictionary(uniqueKeysWithValues: workspace.tabIDs.enumerated().map { ($1, $0) })
        return tabs
            .filter { $0.workspaceID == workspace.id }
            .sorted { (positions[$0.id] ?? .max) < (positions[$1.id] ?? .max) }
    }

    var isSplitViewActive: Bool { splitTabIDs.count >= 2 }

    var profile: BrowserProfile { makeProfile() }

    private let persistence: BrowserPersistence
    private let contentBlockerService: ContentBlockerService
    private let persistenceDebounce: Duration
    private var persistenceTask: Task<Void, Never>?
    private var isHydrating = false
    private var hasStarted = false
    private var profileID: UUID
    private var profileCreatedAt: Date
    private var sessionID: UUID
    private var activeSplitSessionID: UUID?
    private var downloadResumeData: [UUID: Data] = [:]
    private var tabSubscriptions: [UUID: Set<AnyCancellable>] = [:]

    init(
        persistence: BrowserPersistence = BrowserPersistence(),
        preferences: BrowserPreferences? = nil,
        contentBlockerService: ContentBlockerService? = nil,
        persistenceDebounce: Duration = .milliseconds(400)
    ) {
        let profile = BrowserProfile.defaultProfile
        let preferences = preferences ?? BrowserPreferences()
        self.persistence = persistence
        self.preferences = preferences
        self.contentBlockerService = contentBlockerService ?? .shared
        self.persistenceDebounce = persistenceDebounce
        self.profileID = profile.id
        self.profileCreatedAt = profile.createdAt
        self.sessionID = profile.session.id
        self.workspaces = profile.workspaces
        self.tabIslands = profile.tabIslands
        self.bookmarks = profile.bookmarks
        self.history = profile.history
        self.speedDials = profile.speedDials
        self.downloads = profile.downloads
        self.pinboardNotes = profile.pinboardNotes
        self.recentlyClosedTabs = profile.session.recentlyClosedTabs
        self.activeWorkspaceID = profile.session.activeWorkspaceID
        self.selectedTabID = profile.session.activeTabID
        self.isSidebarVisible = preferences.sidebarVisible
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await load()
    }

    func load() async {
        persistenceTask?.cancel()
        isLoading = true
        persistenceStatus = .loading
        defer { isLoading = false }

        do {
            apply(try await persistence.load())
            persistenceError = nil
            persistenceStatus = .idle
        } catch {
            apply(.defaultProfile)
            persistenceError = error.localizedDescription
            persistenceStatus = .failed
        }
    }

    func flushPersistence() async {
        persistenceTask?.cancel()
        persistenceTask = nil
        await persistNow()
    }

    // MARK: - Navigation and tabs

    func navigateOmnibox(_ input: String) {
        guard let destination = AddressResolver.resolve(
            input,
            searchProvider: preferences.searchProvider,
            httpsFirst: preferences.httpsFirst
        ) else { return }

        if let selectedTab {
            selectedTab.load(destination)
        } else {
            _ = newTab(url: destination)
        }
    }

    @discardableResult
    func newTab(
        url: URL? = nil,
        isPrivate: Bool? = nil,
        workspaceID: UUID? = nil,
        select: Bool = true
    ) -> BrowserTabController {
        let resolvedWorkspaceID = workspaceID
            ?? activeWorkspaceID
            ?? ensureWorkspace().id
        if !workspaces.contains(where: { $0.id == resolvedWorkspaceID }) {
            _ = ensureWorkspace(id: resolvedWorkspaceID)
        }

        let controller = makeController(
            id: UUID(),
            initialURL: url,
            isPrivate: isPrivate ?? preferences.alwaysUsePrivateBrowsing,
            isPinned: false,
            workspaceID: resolvedWorkspaceID,
            islandID: nil,
            zoom: preferences.pageZoom
        )
        tabs.append(controller)
        appendTab(controller.id, toWorkspace: resolvedWorkspaceID)
        if select { selectTab(id: controller.id) }
        schedulePersistence()
        return controller
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let controller = tabs[index]
        let workspaceID = controller.workspaceID
        let workspaceOrder = workspaces.first(where: { $0.id == workspaceID })?.tabIDs ?? []
        let closedPosition = workspaceOrder.firstIndex(of: id) ?? 0

        if !controller.isPrivate {
            recentlyClosedTabs.insert(snapshot(for: controller, sortIndex: closedPosition), at: 0)
            recentlyClosedTabs = Array(recentlyClosedTabs.prefix(25))
        }

        tabs.remove(at: index)
        tabSubscriptions[id] = nil
        removeTabReferences(id)

        if selectedTabID == id {
            let remaining = tabs.filter { $0.workspaceID == workspaceID }
            let replacementIndex = min(closedPosition, max(remaining.count - 1, 0))
            selectedTabID = remaining.isEmpty ? tabs.first?.id : remaining[replacementIndex].id
        }

        if tabs.isEmpty {
            _ = newTab(workspaceID: activeWorkspaceID, select: true)
        } else if let selectedTabID {
            selectTab(id: selectedTabID)
        }
        schedulePersistence()
    }

    @discardableResult
    func reopenLastClosedTab() -> BrowserTabController? {
        guard !recentlyClosedTabs.isEmpty else { return nil }
        var snapshot = recentlyClosedTabs.removeFirst()
        if !workspaces.contains(where: { $0.id == snapshot.workspaceID }) {
            snapshot.workspaceID = activeWorkspaceID ?? ensureWorkspace().id
            snapshot.islandID = nil
        }
        let controller = restore(snapshot)
        tabs.append(controller)
        appendTab(controller.id, toWorkspace: controller.workspaceID)
        selectTab(id: controller.id)
        schedulePersistence()
        return controller
    }

    @discardableResult
    func duplicateTab(id: UUID) -> BrowserTabController? {
        guard let source = tabs.first(where: { $0.id == id }) else { return nil }
        return newTab(
            url: source.isShowingStartPage ? nil : source.url,
            isPrivate: source.isPrivate,
            workspaceID: source.workspaceID,
            select: true
        )
    }

    func selectTab(id: UUID) {
        guard let controller = tabs.first(where: { $0.id == id }) else { return }
        if isSplitViewActive, !splitTabIDs.contains(id) {
            exitSplit()
        }
        selectedTabID = id
        activeWorkspaceID = controller.workspaceID
        focusedSplitTabID = splitTabIDs.contains(id) ? id : focusedSplitTabID
        mutateWorkspace(controller.workspaceID) { workspace in
            workspace.selectedTabID = id
            workspace.modifiedAt = Date()
        }
        schedulePersistence()
    }

    func cycleTab(_ offset: Int = 1) {
        let candidates = currentWorkspaceTabs
        guard !candidates.isEmpty else { return }
        let currentIndex = selectedTabID.flatMap { id in candidates.firstIndex { $0.id == id } } ?? 0
        let nextIndex = (currentIndex + offset % candidates.count + candidates.count) % candidates.count
        selectTab(id: candidates[nextIndex].id)
    }

    func setPinned(_ pinned: Bool, tabID: UUID) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        tab.isPinned = pinned
        schedulePersistence()
    }

    func moveTab(id: UUID, toIndex index: Int) {
        guard let tab = tabs.first(where: { $0.id == id }),
              let workspaceIndex = workspaces.firstIndex(where: { $0.id == tab.workspaceID }),
              let oldIndex = workspaces[workspaceIndex].tabIDs.firstIndex(of: id) else { return }
        var ids = workspaces[workspaceIndex].tabIDs
        ids.remove(at: oldIndex)
        ids.insert(id, at: min(max(index, 0), ids.count))
        workspaces[workspaceIndex].tabIDs = ids
        workspaces[workspaceIndex].modifiedAt = Date()
        schedulePersistence()
    }

    func reorderTab(id: UUID, before targetID: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }),
              let workspace = workspaces.first(where: { $0.id == tab.workspaceID }),
              let targetIndex = workspace.tabIDs.firstIndex(of: targetID) else { return }
        moveTab(id: id, toIndex: targetIndex)
    }

    func moveTab(id: UUID, toWorkspaceID workspaceID: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }),
              workspaces.contains(where: { $0.id == workspaceID }) else { return }
        removeTabFromWorkspaceAndIsland(id)
        tab.workspaceID = workspaceID
        tab.groupID = nil
        appendTab(id, toWorkspace: workspaceID)
        if splitTabIDs.contains(id) { exitSplit() }
        selectTab(id: id)
        schedulePersistence()
    }

    // MARK: - Workspaces

    @discardableResult
    func addWorkspace(
        name: String,
        symbolName: String = "square.grid.2x2",
        colorHex: String = "#7C5CFC",
        select: Bool = true
    ) -> WorkspaceRecord {
        let workspace = WorkspaceRecord(
            name: normalizedName(name, fallback: "Workspace"),
            symbolName: symbolName,
            colorHex: colorHex,
            sortIndex: workspaces.count
        )
        workspaces.append(workspace)
        if select {
            activeWorkspaceID = workspace.id
            _ = newTab(workspaceID: workspace.id)
        }
        schedulePersistence()
        return workspace
    }

    func renameWorkspace(id: UUID, name: String) {
        mutateWorkspace(id) {
            $0.name = normalizedName(name, fallback: $0.name)
            $0.modifiedAt = Date()
        }
        schedulePersistence()
    }

    func updateWorkspace(_ workspace: WorkspaceRecord) {
        mutateWorkspace(workspace.id) { current in
            current.name = normalizedName(workspace.name, fallback: current.name)
            current.symbolName = workspace.symbolName
            current.colorHex = workspace.colorHex
            current.isVisible = workspace.isVisible
            current.modifiedAt = Date()
        }
        schedulePersistence()
    }

    func deleteWorkspace(id: UUID) {
        guard workspaces.count > 1,
              let deletedIndex = workspaces.firstIndex(where: { $0.id == id }) else { return }
        let fallback = workspaces.first { $0.id != id }!
        let movingTabs = tabs.filter { $0.workspaceID == id }
        for tab in movingTabs {
            tab.workspaceID = fallback.id
            tab.groupID = nil
        }
        mutateWorkspace(fallback.id) { workspace in
            workspace.tabIDs.append(contentsOf: movingTabs.map(\.id).filter { !workspace.tabIDs.contains($0) })
            workspace.modifiedAt = Date()
        }
        workspaces.remove(at: deletedIndex)
        tabIslands.removeAll { $0.workspaceID == id }
        if activeWorkspaceID == id { activeWorkspaceID = fallback.id }
        if splitTabIDs.contains(where: { tabID in movingTabs.contains { $0.id == tabID } }) { exitSplit() }
        selectWorkspace(id: fallback.id)
        schedulePersistence()
    }

    func selectWorkspace(id: UUID) {
        guard let workspace = workspaces.first(where: { $0.id == id }) else { return }
        activeWorkspaceID = id
        let selection = workspace.selectedTabID.flatMap { selected in
            tabs.first { $0.id == selected && $0.workspaceID == id }?.id
        } ?? tabs.first { $0.workspaceID == id }?.id
        if let selection {
            selectedTabID = selection
        } else {
            _ = newTab(workspaceID: id)
        }
        if !splitTabIDs.allSatisfy({ tabID in tabs.first(where: { $0.id == tabID })?.workspaceID == id }) {
            exitSplit()
        }
        schedulePersistence()
    }

    // MARK: - Tab islands

    @discardableResult
    func createTabIsland(
        name: String,
        tabIDs: [UUID],
        colorHex: String = "#2CC9B7"
    ) -> TabIslandRecord? {
        let uniqueIDs = unique(tabIDs)
        guard let first = uniqueIDs.first.flatMap({ id in tabs.first { $0.id == id } }) else { return nil }
        let validIDs = uniqueIDs.filter { id in tabs.contains { $0.id == id && $0.workspaceID == first.workspaceID } }
        guard !validIDs.isEmpty else { return nil }
        for id in validIDs { removeTabFromIsland(id) }
        let island = TabIslandRecord(
            workspaceID: first.workspaceID,
            name: normalizedName(name, fallback: "Tab Island"),
            colorHex: colorHex,
            tabIDs: validIDs,
            sortIndex: tabIslands.filter { $0.workspaceID == first.workspaceID }.count
        )
        tabIslands.append(island)
        for id in validIDs { tabs.first { $0.id == id }?.groupID = island.id }
        mutateWorkspace(first.workspaceID) {
            if !$0.islandIDs.contains(island.id) { $0.islandIDs.append(island.id) }
            $0.modifiedAt = Date()
        }
        schedulePersistence()
        return island
    }

    func renameTabIsland(id: UUID, name: String) {
        mutateIsland(id) {
            $0.name = normalizedName(name, fallback: $0.name)
            $0.modifiedAt = Date()
        }
        schedulePersistence()
    }

    func setTabIslandCollapsed(_ collapsed: Bool, id: UUID) {
        mutateIsland(id) {
            $0.isCollapsed = collapsed
            $0.modifiedAt = Date()
        }
        schedulePersistence()
    }

    func deleteTabIsland(id: UUID) {
        guard let island = tabIslands.first(where: { $0.id == id }) else { return }
        for tabID in island.tabIDs { tabs.first { $0.id == tabID }?.groupID = nil }
        tabIslands.removeAll { $0.id == id }
        mutateWorkspace(island.workspaceID) {
            $0.islandIDs.removeAll { $0 == id }
            $0.modifiedAt = Date()
        }
        schedulePersistence()
    }

    // MARK: - Split view

    @discardableResult
    func enterSplit(with tabIDs: [UUID], layout: SplitLayout? = nil) -> Bool {
        let IDs = Array(unique(tabIDs).prefix(4))
        guard (2...4).contains(IDs.count),
              let workspaceID = tabs.first(where: { $0.id == IDs[0] })?.workspaceID,
              IDs.allSatisfy({ id in tabs.contains { $0.id == id && $0.workspaceID == workspaceID } }) else {
            return false
        }
        splitTabIDs = IDs
        splitLayout = resolvedLayout(layout, paneCount: IDs.count)
        focusedSplitTabID = IDs.first
        activeSplitSessionID = UUID()
        activeWorkspaceID = workspaceID
        if let first = IDs.first { selectTab(id: first) }
        schedulePersistence()
        return true
    }

    @discardableResult
    func addTabToSplit(_ tabID: UUID) -> Bool {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return false }
        if splitTabIDs.isEmpty {
            guard let selectedTabID, selectedTabID != tabID else { return false }
            return enterSplit(with: [selectedTabID, tabID])
        }
        guard splitTabIDs.count < 4,
              !splitTabIDs.contains(tabID),
              tabs.first(where: { $0.id == splitTabIDs[0] })?.workspaceID == tab.workspaceID else {
            return false
        }
        splitTabIDs.append(tabID)
        splitLayout = resolvedLayout(nil, paneCount: splitTabIDs.count)
        focusedSplitTabID = tabID
        schedulePersistence()
        return true
    }

    func swapSplitTabs(_ firstID: UUID, _ secondID: UUID) {
        guard let first = splitTabIDs.firstIndex(of: firstID),
              let second = splitTabIDs.firstIndex(of: secondID) else { return }
        splitTabIDs.swapAt(first, second)
        schedulePersistence()
    }

    func setSplitLayout(_ layout: SplitLayout) {
        guard layout.paneCount == splitTabIDs.count else { return }
        splitLayout = layout
        schedulePersistence()
    }

    func focusSplitTab(_ tabID: UUID) {
        guard splitTabIDs.contains(tabID) else { return }
        focusedSplitTabID = tabID
        selectTab(id: tabID)
    }

    func exitSplit() {
        splitTabIDs = []
        focusedSplitTabID = nil
        activeSplitSessionID = nil
        splitLayout = .twoColumns
        schedulePersistence()
    }

    // MARK: - Bookmarks, history, speed dial, and pinboard

    @discardableResult
    func addBookmark(
        url: URL,
        title: String,
        folderName: String? = nil,
        tags: [String] = []
    ) -> BookmarkRecord {
        let bookmark = BookmarkRecord(
            title: normalizedName(title, fallback: url.host ?? url.absoluteString),
            url: url,
            folderName: folderName,
            tags: tags,
            sortIndex: bookmarks.count
        )
        bookmarks.append(bookmark)
        schedulePersistence()
        return bookmark
    }

    func updateBookmark(_ bookmark: BookmarkRecord) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        var copy = bookmark
        copy.modifiedAt = Date()
        bookmarks[index] = copy
        schedulePersistence()
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        schedulePersistence()
    }

    func removeHistory(id: UUID) {
        history.removeAll { $0.id == id }
        schedulePersistence()
    }

    func clearHistory() {
        history.removeAll()
        schedulePersistence()
    }

    @discardableResult
    func addSpeedDial(
        url: URL,
        title: String,
        colorHex: String = "#3B3A50"
    ) -> SpeedDialRecord {
        let item = SpeedDialRecord(
            title: normalizedName(title, fallback: url.host ?? url.absoluteString),
            url: url,
            colorHex: colorHex,
            sortIndex: speedDials.count
        )
        speedDials.append(item)
        schedulePersistence()
        return item
    }

    func updateSpeedDial(_ item: SpeedDialRecord) {
        guard let index = speedDials.firstIndex(where: { $0.id == item.id }) else { return }
        var copy = item
        copy.modifiedAt = Date()
        speedDials[index] = copy
        schedulePersistence()
    }

    func removeSpeedDial(id: UUID) {
        speedDials.removeAll { $0.id == id }
        normalizeSpeedDialSortIndexes()
        schedulePersistence()
    }

    func moveSpeedDial(id: UUID, toIndex index: Int) {
        guard let oldIndex = speedDials.firstIndex(where: { $0.id == id }) else { return }
        let item = speedDials.remove(at: oldIndex)
        speedDials.insert(item, at: min(max(index, 0), speedDials.count))
        normalizeSpeedDialSortIndexes()
        schedulePersistence()
    }

    @discardableResult
    func addPinboardNote(
        title: String = "",
        body: String,
        linkedURL: URL? = nil,
        colorHex: String = "#FFE08A",
        positionX: Double = 0,
        positionY: Double = 0
    ) -> PinboardNoteRecord {
        let note = PinboardNoteRecord(
            title: title,
            body: body,
            linkedURL: linkedURL,
            colorHex: colorHex,
            positionX: positionX,
            positionY: positionY
        )
        pinboardNotes.append(note)
        schedulePersistence()
        return note
    }

    func updatePinboardNote(_ note: PinboardNoteRecord) {
        guard let index = pinboardNotes.firstIndex(where: { $0.id == note.id }) else { return }
        var copy = note
        copy.modifiedAt = Date()
        pinboardNotes[index] = copy
        schedulePersistence()
    }

    func removePinboardNote(id: UUID) {
        pinboardNotes.removeAll { $0.id == id }
        schedulePersistence()
    }

    // MARK: - Download library

    @discardableResult
    func revealDownload(id: UUID) -> Bool {
        guard let url = downloads.first(where: { $0.id == id })?.destinationURL else { return false }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        return true
    }

    func deleteDownload(id: UUID, deleteFile: Bool = false) {
        guard let record = downloads.first(where: { $0.id == id }) else { return }
        if deleteFile, let destinationURL = record.destinationURL {
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
            } catch {
                persistenceError = error.localizedDescription
            }
        }
        downloads.removeAll { $0.id == id }
        downloadResumeData[id] = nil
        schedulePersistence()
    }

    func retryDownload(id: UUID) async {
        guard let record = downloads.first(where: { $0.id == id }) else { return }
        let controller = selectedTab ?? newTab()
        downloads.removeAll { $0.id == id }
        if let resumeData = downloadResumeData.removeValue(forKey: id) {
            _ = await controller.resumeDownload(from: resumeData)
        } else {
            _ = await controller.startDownload(URLRequest(url: record.sourceURL))
        }
        schedulePersistence()
    }

    // MARK: - Browser and privacy tools

    func setContentBlockingEnabled(_ enabled: Bool) async {
        preferences.trackerBlockingEnabled = enabled
        preferences.adBlockingEnabled = enabled
        for tab in tabs {
            await tab.setContentBlockingEnabled(enabled, reloadCurrentPage: true)
        }
    }

    func clearWebsiteData() async {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        var seen = Set<ObjectIdentifier>()
        var stores: [WKWebsiteDataStore] = [.default()]
        stores.append(contentsOf: tabs.map { $0.webView.configuration.websiteDataStore })
        for store in stores where seen.insert(ObjectIdentifier(store)).inserted {
            await withCheckedContinuation { continuation in
                store.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
                    continuation.resume()
                }
            }
        }
    }

    func zoomIn() {
        selectedTab?.zoomIn()
        schedulePersistence()
    }

    func zoomOut() {
        selectedTab?.zoomOut()
        schedulePersistence()
    }

    func resetZoom() {
        selectedTab?.resetZoom()
        schedulePersistence()
    }

    func setPageZoom(_ zoom: Double, makeDefault: Bool = false) {
        selectedTab?.setZoom(zoom)
        if makeDefault { preferences.pageZoom = zoom }
        schedulePersistence()
    }

    func findInPage(
        _ query: String,
        backwards: Bool = false,
        caseSensitive: Bool = false
    ) async throws -> Bool {
        guard let selectedTab else { throw StoreError.noSelectedTab }
        return try await selectedTab.find(
            query,
            backwards: backwards,
            caseSensitive: caseSensitive
        )
    }

    @discardableResult
    func printPage() throws -> NSPrintOperation {
        guard let selectedTab else { throw StoreError.noSelectedTab }
        return selectedTab.printPage()
    }

    func snapshot() async throws -> NSImage {
        guard let selectedTab else { throw StoreError.noSelectedTab }
        return try await selectedTab.snapshot()
    }

    func pdf() async throws -> Data {
        guard let selectedTab else { throw StoreError.noSelectedTab }
        return try await selectedTab.pdf()
    }

    // MARK: - Controller events

    func handleTabEvent(_ event: BrowserTabController.Event, from tabID: UUID) {
        switch event {
        case let .requestNewTab(url):
            let workspaceID = tabs.first(where: { $0.id == tabID })?.workspaceID
            _ = newTab(url: url, workspaceID: workspaceID)
        case .closeRequested:
            closeTab(id: tabID)
        case let .history(visit):
            guard let source = tabs.first(where: { $0.id == tabID }), !source.isPrivate else { return }
            recordHistory(visit)
        case let .download(event):
            handleDownloadEvent(event)
        case .webContentProcessTerminated:
            break
        }
    }

    func recordHistory(_ visit: BrowserTabController.HistoryVisit, isPrivate: Bool = false) {
        guard !isPrivate, preferences.saveBrowsingHistory else { return }
        if let index = history.firstIndex(where: { $0.url == visit.url }) {
            history[index].title = visit.title
            history[index].visitCount += 1
            history[index].lastVisitedAt = visit.visitedAt
            let record = history.remove(at: index)
            history.insert(record, at: 0)
        } else {
            history.insert(
                HistoryRecord(
                    title: visit.title,
                    url: visit.url,
                    firstVisitedAt: visit.visitedAt,
                    lastVisitedAt: visit.visitedAt
                ),
                at: 0
            )
        }
        history = Array(history.prefix(5_000))
        schedulePersistence()
    }

    private func handleDownloadEvent(_ event: BrowserTabController.DownloadEvent) {
        switch event {
        case let .started(item):
            let sourceURL = item.sourceURL ?? URL(string: "about:blank")!
            let record = DownloadRecord(
                id: item.id,
                sourceURL: sourceURL,
                destinationURL: item.destinationURL,
                suggestedFilename: item.filename,
                state: .downloading,
                startedAt: item.startedAt,
                updatedAt: item.startedAt
            )
            downloads.removeAll { $0.id == item.id }
            downloads.insert(record, at: 0)
        case let .progress(id, fractionCompleted):
            mutateDownload(id) {
                $0.state = .downloading
                $0.progress = fractionCompleted
                $0.updatedAt = Date()
            }
        case let .finished(id, destinationURL):
            mutateDownload(id) {
                $0.destinationURL = destinationURL
                $0.state = .completed
                $0.progress = 1
                $0.updatedAt = Date()
                $0.completedAt = Date()
                $0.errorDescription = nil
            }
            downloadResumeData[id] = nil
        case let .failed(id, error, resumeData):
            if downloads.contains(where: { $0.id == id }) {
                mutateDownload(id) {
                    $0.state = resumeData == nil ? .failed : .paused
                    $0.errorDescription = error.localizedDescription
                    $0.updatedAt = Date()
                }
            } else {
                downloads.insert(
                    DownloadRecord(
                        id: id,
                        sourceURL: error.failingURL ?? URL(string: "about:blank")!,
                        suggestedFilename: error.failingURL?.lastPathComponent ?? "Download",
                        state: resumeData == nil ? .failed : .paused,
                        errorDescription: error.localizedDescription
                    ),
                    at: 0
                )
            }
            downloadResumeData[id] = resumeData
        case let .cancelled(id, resumeData):
            mutateDownload(id) {
                $0.state = .cancelled
                $0.updatedAt = Date()
            }
            downloadResumeData[id] = resumeData
        }
        schedulePersistence()
    }

    // MARK: - Profile hydration and persistence

    private func apply(_ profile: BrowserProfile) {
        isHydrating = true
        defer { isHydrating = false }

        let sanitized = profile.persistableCopy()
        tabSubscriptions.removeAll()
        profileID = sanitized.id
        profileCreatedAt = sanitized.createdAt
        sessionID = sanitized.session.id
        workspaces = sanitized.workspaces
        tabIslands = sanitized.tabIslands
        bookmarks = sanitized.bookmarks
        history = sanitized.history
        speedDials = sanitized.speedDials
        downloads = sanitized.downloads
        pinboardNotes = sanitized.pinboardNotes
        recentlyClosedTabs = sanitized.session.recentlyClosedTabs

        if workspaces.isEmpty { _ = ensureWorkspace() }
        activeWorkspaceID = sanitized.session.activeWorkspaceID.flatMap { candidate in
            workspaces.contains { $0.id == candidate } ? candidate : nil
        } ?? workspaces.first?.id

        tabs = preferences.restorePreviousSession
            ? sanitized.session.tabs.map(restore)
            : []
        if tabs.isEmpty {
            _ = newTab(workspaceID: activeWorkspaceID, select: false)
        }

        selectedTabID = sanitized.session.activeTabID.flatMap { candidate in
            tabs.contains { $0.id == candidate } ? candidate : nil
        } ?? tabs.first(where: { $0.workspaceID == activeWorkspaceID })?.id
            ?? tabs.first?.id
        if let selectedTabID, let selected = tabs.first(where: { $0.id == selectedTabID }) {
            activeWorkspaceID = selected.workspaceID
        }

        if let split = sanitized.session.splitSessions.first(where: { split in
            split.tabIDs.count >= 2 && split.tabIDs.allSatisfy { id in tabs.contains { $0.id == id } }
        }) {
            activeSplitSessionID = split.id
            splitTabIDs = Array(split.tabIDs.prefix(4))
            splitLayout = resolvedLayout(split.layout, paneCount: splitTabIDs.count)
            focusedSplitTabID = split.focusedTabID.flatMap { splitTabIDs.contains($0) ? $0 : nil }
                ?? splitTabIDs.first
        } else {
            splitTabIDs = []
            focusedSplitTabID = nil
            activeSplitSessionID = nil
            splitLayout = .twoColumns
        }
    }

    private func makeProfile() -> BrowserProfile {
        let tabSnapshots = tabs.enumerated().map { index, tab in
            snapshot(for: tab, sortIndex: index)
        }
        let splitSessions: [SplitSessionSnapshot]
        if splitTabIDs.count >= 2, let workspaceID = activeWorkspaceID {
            splitSessions = [SplitSessionSnapshot(
                id: activeSplitSessionID ?? UUID(),
                workspaceID: workspaceID,
                tabIDs: splitTabIDs,
                layout: splitLayout,
                focusedTabID: focusedSplitTabID
            )]
        } else {
            splitSessions = []
        }

        return BrowserProfile(
            id: profileID,
            createdAt: profileCreatedAt,
            updatedAt: Date(),
            workspaces: workspaces,
            tabIslands: tabIslands,
            bookmarks: bookmarks,
            history: history,
            speedDials: speedDials,
            downloads: downloads,
            pinboardNotes: pinboardNotes,
            session: BrowserSessionSnapshot(
                id: sessionID,
                tabs: tabSnapshots,
                activeTabID: selectedTabID,
                activeWorkspaceID: activeWorkspaceID,
                recentlyClosedTabs: recentlyClosedTabs,
                splitSessions: splitSessions,
                savedAt: Date()
            )
        ).persistableCopy()
    }

    private func schedulePersistence() {
        guard !isHydrating else { return }
        persistenceStatus = .dirty
        persistenceTask?.cancel()
        let delay = persistenceDebounce
        persistenceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.persistNow()
        }
    }

    private func persistNow() async {
        guard !isHydrating else { return }
        persistenceStatus = .saving
        let snapshot = makeProfile()
        do {
            try await persistence.save(snapshot)
            persistenceError = nil
            persistenceStatus = .saved
        } catch {
            persistenceError = error.localizedDescription
            persistenceStatus = .failed
        }
    }

    // MARK: - Internal helpers

    private func makeController(
        id: UUID,
        initialURL: URL?,
        isPrivate: Bool,
        isPinned: Bool,
        workspaceID: UUID,
        islandID: UUID?,
        zoom: Double
    ) -> BrowserTabController {
        let shouldBlock = preferences.trackerBlockingEnabled || preferences.adBlockingEnabled
        let controller = BrowserTabController(
            id: id,
            initialURL: initialURL?.absoluteString == "overture://start" ? nil : initialURL,
            isPrivate: isPrivate,
            isPinned: isPinned,
            workspaceID: workspaceID,
            groupID: islandID,
            contentBlockingEnabled: shouldBlock,
            contentBlockerService: contentBlockerService,
            downloadDirectoryProvider: { [preferences] in preferences.downloadDirectoryURL },
            downloadDestinationProvider: { [preferences] suggestedFilename in
                guard preferences.askWhereToSaveDownloads else {
                    return .useDefaultDirectory
                }

                let panel = NSSavePanel()
                panel.title = "Save Download"
                panel.prompt = "Download"
                panel.canCreateDirectories = true
                panel.directoryURL = preferences.downloadDirectoryURL
                let pathSafeName = (suggestedFilename as NSString).lastPathComponent
                panel.nameFieldStringValue = pathSafeName.isEmpty ? "Download" : pathSafeName
                return panel.runModal() == .OK
                    ? panel.url.map(BrowserTabController.DownloadDestinationDecision.destination) ?? .cancel
                    : .cancel
            }
        )
        controller.setZoom(zoom)
        controller.eventHandler = { [weak self] event in
            self?.handleTabEvent(event, from: id)
        }
        var subscriptions = Set<AnyCancellable>()
        controller.$url
            .dropFirst()
            .sink { [weak self] _ in self?.schedulePersistence() }
            .store(in: &subscriptions)
        controller.$title
            .dropFirst()
            .sink { [weak self] _ in self?.schedulePersistence() }
            .store(in: &subscriptions)
        controller.$zoomLevel
            .dropFirst()
            .sink { [weak self] _ in self?.schedulePersistence() }
            .store(in: &subscriptions)
        tabSubscriptions[id] = subscriptions
        return controller
    }

    private func restore(_ snapshot: BrowserTabSnapshot) -> BrowserTabController {
        makeController(
            id: snapshot.id,
            initialURL: snapshot.url,
            isPrivate: snapshot.isPrivate,
            isPinned: snapshot.isPinned,
            workspaceID: snapshot.workspaceID,
            islandID: snapshot.islandID,
            zoom: snapshot.zoomScale
        )
    }

    private func snapshot(
        for controller: BrowserTabController,
        sortIndex: Int
    ) -> BrowserTabSnapshot {
        BrowserTabSnapshot(
            id: controller.id,
            workspaceID: controller.workspaceID,
            islandID: controller.groupID,
            url: controller.isShowingStartPage ? controller.startPageURL : controller.url ?? controller.startPageURL,
            title: controller.title,
            isPinned: controller.isPinned,
            isMuted: false,
            isPlayingAudio: false,
            isPrivate: controller.isPrivate,
            zoomScale: controller.zoomLevel,
            sortIndex: sortIndex,
            lastViewedAt: controller.id == selectedTabID ? Date() : .distantPast
        )
    }

    @discardableResult
    private func ensureWorkspace(id: UUID = UUID()) -> WorkspaceRecord {
        if let existing = workspaces.first(where: { $0.id == id }) { return existing }
        let workspace = WorkspaceRecord(
            id: id,
            name: workspaces.isEmpty ? "Personal" : "Workspace",
            symbolName: workspaces.isEmpty ? "house" : "square.grid.2x2",
            sortIndex: workspaces.count
        )
        workspaces.append(workspace)
        activeWorkspaceID = activeWorkspaceID ?? workspace.id
        return workspace
    }

    private func appendTab(_ tabID: UUID, toWorkspace workspaceID: UUID) {
        mutateWorkspace(workspaceID) {
            if !$0.tabIDs.contains(tabID) { $0.tabIDs.append(tabID) }
            $0.selectedTabID = tabID
            $0.modifiedAt = Date()
        }
    }

    private func removeTabReferences(_ tabID: UUID) {
        for index in workspaces.indices {
            workspaces[index].tabIDs.removeAll { $0 == tabID }
            if workspaces[index].selectedTabID == tabID {
                workspaces[index].selectedTabID = workspaces[index].tabIDs.first
            }
        }
        removeTabFromIsland(tabID)
        splitTabIDs.removeAll { $0 == tabID }
        if splitTabIDs.count < 2 {
            splitTabIDs = []
            focusedSplitTabID = nil
            activeSplitSessionID = nil
            splitLayout = .twoColumns
        } else {
            if focusedSplitTabID == tabID { focusedSplitTabID = splitTabIDs.first }
            splitLayout = resolvedLayout(nil, paneCount: splitTabIDs.count)
        }
    }

    private func removeTabFromWorkspaceAndIsland(_ tabID: UUID) {
        for index in workspaces.indices {
            workspaces[index].tabIDs.removeAll { $0 == tabID }
        }
        removeTabFromIsland(tabID)
    }

    private func removeTabFromIsland(_ tabID: UUID) {
        guard let islandIndex = tabIslands.firstIndex(where: { $0.tabIDs.contains(tabID) }) else {
            tabs.first { $0.id == tabID }?.groupID = nil
            return
        }
        let islandID = tabIslands[islandIndex].id
        let workspaceID = tabIslands[islandIndex].workspaceID
        tabIslands[islandIndex].tabIDs.removeAll { $0 == tabID }
        tabs.first { $0.id == tabID }?.groupID = nil
        if tabIslands[islandIndex].tabIDs.isEmpty {
            tabIslands.remove(at: islandIndex)
            mutateWorkspace(workspaceID) { $0.islandIDs.removeAll { $0 == islandID } }
        }
    }

    private func mutateWorkspace(_ id: UUID, _ mutation: (inout WorkspaceRecord) -> Void) {
        guard let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        mutation(&workspaces[index])
    }

    private func mutateIsland(_ id: UUID, _ mutation: (inout TabIslandRecord) -> Void) {
        guard let index = tabIslands.firstIndex(where: { $0.id == id }) else { return }
        mutation(&tabIslands[index])
    }

    private func mutateDownload(_ id: UUID, _ mutation: (inout DownloadRecord) -> Void) {
        guard let index = downloads.firstIndex(where: { $0.id == id }) else { return }
        mutation(&downloads[index])
    }

    private func normalizeSpeedDialSortIndexes() {
        for index in speedDials.indices {
            speedDials[index].sortIndex = index
            speedDials[index].modifiedAt = Date()
        }
    }

    private func resolvedLayout(_ requested: SplitLayout?, paneCount: Int) -> SplitLayout {
        if let requested, requested.paneCount == paneCount { return requested }
        switch paneCount {
        case 2: return .twoColumns
        case 3: return .threeColumns
        default: return .fourGrid
        }
    }

    private func unique(_ values: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return values.filter { seen.insert($0).inserted }
    }

    private func normalizedName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
