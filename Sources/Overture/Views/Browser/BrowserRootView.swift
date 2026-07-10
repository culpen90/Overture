import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
struct BrowserRootView: View {
    @ObservedObject private var preferences: BrowserPreferences
    @StateObject private var store: BrowserStore
    @StateObject private var protonVPN = ProtonVPNIntegration()

    @Environment(\.scenePhase) private var scenePhase

    @State private var isSidebarExpanded = true
    @State private var isTabSearchPresented = false
    @State private var isFindPresented = false
    @State private var locationFocusRequest = 0
    @State private var editorRoute: BrowserEditorRoute?
    @State private var utilityErrorMessage: String?

    init(
        preferences: BrowserPreferences,
        persistence: BrowserPersistence = BrowserPersistence()
    ) {
        self.preferences = preferences
        _store = StateObject(
            wrappedValue: BrowserStore(
                persistence: persistence,
                preferences: preferences
            )
        )
    }

    private var selectedTab: BrowserTabController? { store.selectedTab }

    private var selectedPageIsBookmarked: Bool {
        guard let url = selectedTab?.url else { return false }
        return store.bookmarks.contains { $0.url == url }
    }

    private var currentSidebarDestination: SidebarDestination {
        switch store.activeLibraryPanel {
        case .bookmarks: .bookmarks
        case .history: .history
        case .downloads: .downloads
        case .pinboard: .pinboards
        case nil: .startPage
        }
    }

    private var activeDownloadCount: Int {
        store.downloads.filter { [.queued, .downloading, .paused].contains($0.state) }.count
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if preferences.tabLayout == .horizontal {
                    tabStrip
                }

                if let selectedTab {
                    NavigationToolbar(
                        controller: selectedTab,
                        isBookmarked: selectedPageIsBookmarked,
                        bookmarks: store.bookmarks,
                        history: store.history,
                        isSplitActive: store.isSplitViewActive,
                        preferences: preferences,
                        focusRequest: locationFocusRequest,
                        onNavigate: store.navigateOmnibox,
                        toggleBookmark: toggleSelectedBookmark,
                        showDownloads: { showLibrary(.downloads) },
                        showFind: { isFindPresented = true },
                        toggleContentBlocking: toggleContentBlocking,
                        enterSplit: toggleSplit,
                        takeSnapshot: saveSnapshot,
                        savePDF: savePDF
                    )
                } else {
                    Color.clear.frame(height: 48)
                }

                HStack(spacing: 0) {
                    if store.isSidebarVisible {
                        sidebar
                    }

                    if preferences.tabLayout == .vertical {
                        VerticalTabRail(
                            tabs: store.currentWorkspaceTabs,
                            selectedTabID: store.selectedTabID,
                            accent: preferences.accent,
                            onSelect: store.selectTab,
                            onClose: store.closeTab,
                            onNew: { _ = store.newTab() },
                            onSearch: { isTabSearchPresented = true }
                        )
                    }

                    mainContent
                }
            }
            .background(OvertureDesign.canvas)

            if store.isLoading {
                loadingOverlay
            }

            if isTabSearchPresented {
                TabSearchOverlay(
                    controllers: store.tabs,
                    workspaces: store.workspaces,
                    groups: store.tabIslands,
                    activeControllerID: store.selectedTabID,
                    accent: preferences.accent,
                    onSelect: { controller in
                        store.selectTab(id: controller.id)
                        store.activeLibraryPanel = nil
                        isTabSearchPresented = false
                    },
                    onClose: { isTabSearchPresented = false }
                )
                .zIndex(500)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .preferredColorScheme(preferences.appearance.preferredColorScheme)
        .tint(OvertureDesign.accent(for: preferences.accent))
        .focusedSceneValue(\.browserCommandActions, commandActions)
        .sheet(item: $editorRoute, content: editorSheet)
        .alert(
            "Overture couldn’t complete that action",
            isPresented: Binding(
                get: { utilityErrorMessage != nil },
                set: { if !$0 { utilityErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { utilityErrorMessage = nil }
        } message: {
            Text(utilityErrorMessage ?? "Unknown error")
        }
        .task { await store.start() }
        .onChange(of: preferences.sidebarVisible) { _, isVisible in
            store.isSidebarVisible = isVisible
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            Task { await store.flushPersistence() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            if preferences.clearHistoryOnQuit {
                store.clearHistory()
            }
            Task { await store.flushPersistence() }
        }
    }

    private var tabStrip: some View {
        TabStrip(
            tabs: store.currentWorkspaceTabs,
            selectedTabID: store.selectedTabID,
            workspaces: store.workspaces,
            islands: store.tabIslands.filter { $0.workspaceID == store.activeWorkspaceID },
            accent: preferences.accent,
            onSelectTab: { id in
                store.selectTab(id: id)
                store.activeLibraryPanel = nil
            },
            onNewTab: { _ = store.newTab() },
            onCloseTab: store.closeTab,
            onDuplicateTab: { _ = store.duplicateTab(id: $0) },
            onTogglePin: { id in
                guard let tab = store.tabs.first(where: { $0.id == id }) else { return }
                store.setPinned(!tab.isPinned, tabID: id)
            },
            onMoveTab: { tabID, workspaceID in
                store.moveTab(id: tabID, toWorkspaceID: workspaceID)
            },
            onReorderTab: { sourceID, targetID in
                store.reorderTab(id: sourceID, before: targetID)
            },
            onCreateIsland: createIsland,
            onAddToSplit: addTabToSplit,
            onTabSearch: { isTabSearchPresented = true }
        )
    }

    private var sidebar: some View {
        BrowserSidebar(
            isExpanded: $isSidebarExpanded,
            workspaces: store.workspaces,
            activeWorkspaceID: store.activeWorkspaceID,
            currentDestination: currentSidebarDestination,
            downloadBadge: activeDownloadCount,
            accent: preferences.accent,
            onSelectDestination: selectSidebarDestination,
            onSelectWorkspace: { id in
                store.selectWorkspace(id: id)
                store.activeLibraryPanel = nil
            },
            onAddWorkspace: { editorRoute = .workspace(nil) },
            onEditWorkspace: { editorRoute = .workspace($0) },
            onOpenProtonCompanion: protonVPN.openOrOfferInstallation
        )
    }

    @ViewBuilder
    private var mainContent: some View {
        if let panel = store.activeLibraryPanel {
            BrowserLibraryView(
                initialSection: panel,
                bookmarks: store.bookmarks,
                history: store.history,
                downloads: store.downloads,
                pinboardNotes: store.pinboardNotes,
                accent: preferences.accent,
                onOpenURL: openFromLibrary,
                onDeleteBookmark: { store.removeBookmark(id: $0.id) },
                onDeleteHistory: { store.removeHistory(id: $0.id) },
                onClearHistory: store.clearHistory,
                onDeleteDownload: { store.deleteDownload(id: $0.id) },
                onRevealDownload: { _ = store.revealDownload(id: $0.id) },
                onRetryDownload: { record in
                    Task { await store.retryDownload(id: record.id) }
                },
                onSaveNote: savePinboardNote,
                onDeleteNote: { store.removePinboardNote(id: $0.id) },
                onClose: { store.activeLibraryPanel = nil }
            )
            .id(panel)
        } else {
            BrowserContentView(
                tabs: store.tabs,
                selectedTabID: store.selectedTabID,
                splitTabIDs: store.splitTabIDs,
                splitLayout: store.splitLayout,
                focusedSplitTabID: store.focusedSplitTabID,
                speedDials: store.speedDials,
                recentHistory: store.history,
                searchProvider: preferences.searchProvider,
                accent: preferences.accent,
                isFindPresented: $isFindPresented,
                onNavigate: { tabID, url in
                    store.tabs.first(where: { $0.id == tabID })?.load(url)
                },
                onShowStartPage: { tabID in
                    store.tabs.first(where: { $0.id == tabID })?.showStartPage()
                },
                onFocusSplitTab: store.focusSplitTab,
                onAddSpeedDial: { editorRoute = .speedDial(nil) },
                onEditSpeedDial: { editorRoute = .speedDial($0) },
                onDeleteSpeedDial: { store.removeSpeedDial(id: $0.id) }
            )
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            OvertureMark(size: 48, accent: OvertureDesign.accent(for: preferences.accent))
            ProgressView()
            Text("Restoring your browser…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Restoring browser session")
    }

    private var commandActions: BrowserCommandActions {
        BrowserCommandActions(
            newTab: { _ = store.newTab() },
            newPrivateTab: { _ = store.newTab(isPrivate: true) },
            closeTab: {
                if let id = store.selectedTabID { store.closeTab(id: id) }
            },
            reopenClosedTab: { _ = store.reopenLastClosedTab() },
            focusLocation: { locationFocusRequest += 1 },
            reload: { store.selectedTab?.reloadOrStop() },
            goBack: { store.selectedTab?.goBack() },
            goForward: { store.selectedTab?.goForward() },
            showStartPage: showStartPage,
            showFind: { isFindPresented = true },
            toggleBookmark: toggleSelectedBookmark,
            showBookmarks: { showLibrary(.bookmarks) },
            showHistory: { showLibrary(.history) },
            showDownloads: { showLibrary(.downloads) },
            nextTab: { store.cycleTab(1) },
            previousTab: { store.cycleTab(-1) },
            zoomIn: store.zoomIn,
            zoomOut: store.zoomOut,
            resetZoom: store.resetZoom,
            toggleSidebar: {
                store.isSidebarVisible.toggle()
                preferences.sidebarVisible = store.isSidebarVisible
            },
            enterSplit: enterSplitWithNeighbor,
            exitSplit: store.exitSplit,
            printPage: {
                do { _ = try store.printPage() }
                catch { utilityErrorMessage = error.localizedDescription }
            }
        )
    }

    @ViewBuilder
    private func editorSheet(_ route: BrowserEditorRoute) -> some View {
        switch route {
        case let .speedDial(item):
            SpeedDialEditorSheet(existing: item, searchProvider: preferences.searchProvider) { saved in
                if store.speedDials.contains(where: { $0.id == saved.id }) {
                    store.updateSpeedDial(saved)
                } else {
                    _ = store.addSpeedDial(url: saved.url, title: saved.title, colorHex: saved.colorHex)
                }
            }

        case let .workspace(workspace):
            WorkspaceEditorSheet(existing: workspace) { saved in
                if store.workspaces.contains(where: { $0.id == saved.id }) {
                    store.updateWorkspace(saved)
                } else {
                    _ = store.addWorkspace(
                        name: saved.name,
                        symbolName: saved.symbolName,
                        colorHex: saved.colorHex
                    )
                }
            }

        case let .bookmark(bookmark):
            BookmarkEditorSheet(
                existing: bookmark,
                suggestedURL: selectedTab?.url,
                suggestedTitle: selectedTab?.title ?? ""
            ) { saved in
                if store.bookmarks.contains(where: { $0.id == saved.id }) {
                    store.updateBookmark(saved)
                } else {
                    _ = store.addBookmark(
                        url: saved.url,
                        title: saved.title,
                        folderName: saved.folderName,
                        tags: saved.tags
                    )
                }
            }
        }
    }

    private func selectSidebarDestination(_ destination: SidebarDestination) {
        switch destination {
        case .startPage:
            showStartPage()
        case .bookmarks:
            showLibrary(.bookmarks)
        case .history:
            showLibrary(.history)
        case .downloads:
            showLibrary(.downloads)
        case .pinboards:
            showLibrary(.pinboard)
        }
    }

    private func showStartPage() {
        store.activeLibraryPanel = nil
        if let selectedTab {
            selectedTab.showStartPage()
        } else {
            _ = store.newTab()
        }
    }

    private func showLibrary(_ panel: BrowserLibrarySection) {
        store.activeLibraryPanel = panel
        isFindPresented = false
    }

    private func openFromLibrary(_ url: URL) {
        store.activeLibraryPanel = nil
        if let selectedTab {
            selectedTab.load(url)
        } else {
            _ = store.newTab(url: url)
        }
    }

    private func toggleSelectedBookmark() {
        guard let tab = selectedTab,
              !tab.isShowingStartPage,
              let url = tab.url else { return }
        if let existing = store.bookmarks.first(where: { $0.url == url }) {
            store.removeBookmark(id: existing.id)
        } else {
            _ = store.addBookmark(url: url, title: tab.title)
        }
    }

    private func toggleContentBlocking() {
        let enabled = !(selectedTab?.isContentBlockingEnabled ?? true)
        Task { await store.setContentBlockingEnabled(enabled) }
    }

    private func enterSplitWithNeighbor() {
        guard let selectedID = store.selectedTabID else { return }
        let candidates = store.currentWorkspaceTabs.filter { $0.id != selectedID }
        let neighbor = candidates.first ?? store.newTab(workspaceID: store.activeWorkspaceID, select: false)
        _ = store.enterSplit(with: [selectedID, neighbor.id])
    }

    private func toggleSplit() {
        if store.isSplitViewActive {
            store.exitSplit()
        } else {
            enterSplitWithNeighbor()
        }
    }

    private func addTabToSplit(_ tabID: UUID) {
        if store.isSplitViewActive {
            _ = store.addTabToSplit(tabID)
            return
        }
        guard let selectedID = store.selectedTabID, selectedID != tabID else {
            enterSplitWithNeighbor()
            return
        }
        _ = store.enterSplit(with: [selectedID, tabID])
    }

    private func createIsland(_ tabID: UUID) {
        let pairedIDs: [UUID]
        if let selectedID = store.selectedTabID, selectedID != tabID {
            pairedIDs = [selectedID, tabID]
        } else {
            pairedIDs = [tabID]
        }
        _ = store.createTabIsland(name: "Tab Island", tabIDs: pairedIDs)
    }

    private func savePinboardNote(_ note: PinboardNoteRecord) {
        if store.pinboardNotes.contains(where: { $0.id == note.id }) {
            store.updatePinboardNote(note)
        } else {
            _ = store.addPinboardNote(
                title: note.title,
                body: note.body,
                linkedURL: note.linkedURL,
                colorHex: note.colorHex,
                positionX: note.positionX,
                positionY: note.positionY
            )
        }
    }

    private func saveSnapshot() {
        Task {
            do {
                let image = try await store.snapshot()
                guard let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw BrowserExportError.imageEncodingFailed
                }
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.png]
                panel.nameFieldStringValue = safeExportName(extension: "png")
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try data.write(to: url, options: .atomic)
            } catch {
                utilityErrorMessage = error.localizedDescription
            }
        }
    }

    private func savePDF() {
        Task {
            do {
                let data = try await store.pdf()
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.pdf]
                panel.nameFieldStringValue = safeExportName(extension: "pdf")
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try data.write(to: url, options: .atomic)
            } catch {
                utilityErrorMessage = error.localizedDescription
            }
        }
    }

    private func safeExportName(extension fileExtension: String) -> String {
        let rawTitle = selectedTab?.title ?? "Web Page"
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let safeTitle = rawTitle.components(separatedBy: invalid).joined(separator: "-")
        return "\(safeTitle.isEmpty ? "Web Page" : safeTitle).\(fileExtension)"
    }
}

private enum BrowserEditorRoute: Identifiable {
    case speedDial(SpeedDialRecord?)
    case workspace(WorkspaceRecord?)
    case bookmark(BookmarkRecord?)

    var id: String {
        switch self {
        case let .speedDial(item): "speed-dial-\(item?.id.uuidString ?? "new")"
        case let .workspace(item): "workspace-\(item?.id.uuidString ?? "new")"
        case let .bookmark(item): "bookmark-\(item?.id.uuidString ?? "new")"
        }
    }
}

private enum BrowserExportError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        "Overture could not encode the page snapshot as a PNG image."
    }
}

@MainActor
private struct VerticalTabRail: View {
    let tabs: [BrowserTabController]
    let selectedTabID: UUID?
    let accent: BrowserAccent
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNew: () -> Void
    let onSearch: () -> Void

    private var tint: Color { OvertureDesign.accent(for: accent) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tabs")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onSearch) { Image(systemName: "magnifyingglass") }
                Button(action: onNew) { Image(systemName: "plus") }
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .padding(8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(tabs, id: \.id) { controller in
                        VerticalTabRow(
                            controller: controller,
                            isSelected: controller.id == selectedTabID,
                            tint: tint,
                            onSelect: { onSelect(controller.id) },
                            onClose: { onClose(controller.id) }
                        )
                    }
                }
                .padding(7)
            }
        }
        .frame(width: 220)
        .background(OvertureDesign.sidebar)
        .overlay(alignment: .trailing) { Divider() }
        .accessibilityLabel("Vertical tab list")
    }
}

@MainActor
private struct VerticalTabRow: View {
    @ObservedObject var controller: BrowserTabController
    let isSelected: Bool
    let tint: Color
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    Image(systemName: controller.isPrivate ? "hand.raised.fill" : controller.error == nil ? "globe" : "exclamationmark.triangle.fill")
                        .frame(width: 16)
                    Text(controller.title)
                        .lineLimit(1)
                    Spacer()
                    if controller.isLoading { ProgressView().controlSize(.mini) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(controller.title)")
        }
        .padding(.horizontal, 9)
        .frame(height: 34)
        .background(isSelected ? tint.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? tint.opacity(0.38) : .clear)
        }
        .accessibilityElement(children: .contain)
    }
}
