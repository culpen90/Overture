import SwiftUI

@MainActor
struct TabStrip: View {
    let tabs: [BrowserTabController]
    let selectedTabID: UUID?
    let workspaces: [WorkspaceRecord]
    let islands: [TabIslandRecord]
    let accent: BrowserAccent
    let onSelectTab: (UUID) -> Void
    let onNewTab: () -> Void
    let onCloseTab: (UUID) -> Void
    let onDuplicateTab: (UUID) -> Void
    let onTogglePin: (UUID) -> Void
    let onMoveTab: (UUID, UUID) -> Void
    let onReorderTab: (UUID, UUID) -> Void
    let onCreateIsland: (UUID) -> Void
    let onAddToSplit: (UUID) -> Void
    let onTabSearch: () -> Void

    init(
        tabs: [BrowserTabController],
        selectedTabID: UUID?,
        workspaces: [WorkspaceRecord],
        islands: [TabIslandRecord],
        accent: BrowserAccent,
        onSelectTab: @escaping (UUID) -> Void,
        onNewTab: @escaping () -> Void,
        onCloseTab: @escaping (UUID) -> Void,
        onDuplicateTab: @escaping (UUID) -> Void,
        onTogglePin: @escaping (UUID) -> Void,
        onMoveTab: @escaping (UUID, UUID) -> Void,
        onReorderTab: @escaping (UUID, UUID) -> Void,
        onCreateIsland: @escaping (UUID) -> Void,
        onAddToSplit: @escaping (UUID) -> Void,
        onTabSearch: @escaping () -> Void
    ) {
        self.tabs = tabs
        self.selectedTabID = selectedTabID
        self.workspaces = workspaces
        self.islands = islands
        self.accent = accent
        self.onSelectTab = onSelectTab
        self.onNewTab = onNewTab
        self.onCloseTab = onCloseTab
        self.onDuplicateTab = onDuplicateTab
        self.onTogglePin = onTogglePin
        self.onMoveTab = onMoveTab
        self.onReorderTab = onReorderTab
        self.onCreateIsland = onCreateIsland
        self.onAddToSplit = onAddToSplit
        self.onTabSearch = onTabSearch
    }

    private var tint: Color { OvertureDesign.accent(for: accent) }
    private var pinnedTabs: [BrowserTabController] { tabs.filter(\.isPinned) }

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onTabSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .help("Search Tabs")
            .accessibilityLabel("Search Tabs")
            .accessibilityHint("Shows all open tabs and lets you search by title or address")

            Divider().frame(height: 24)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 5) {
                        ForEach(pinnedTabs, id: \.id) { tab in
                            tabChip(tab, compact: true, groupColor: nil)
                                .id(tab.id)
                        }

                        if !pinnedTabs.isEmpty, !tabClusters.isEmpty {
                            Divider()
                                .frame(height: 24)
                                .padding(.horizontal, 2)
                        }

                        ForEach(tabClusters, id: \.id) { cluster in
                            clusterView(cluster)
                        }

                        if tabs.isEmpty {
                            Text("No tabs open")
                                .font(.system(size: 11.5))
                                .foregroundStyle(OvertureDesign.secondaryText)
                                .padding(.horizontal, 14)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedTabID) { _, selectedID in
                    guard let selectedID else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(selectedID, anchor: .center)
                    }
                }
            }

            Divider().frame(height: 24)

            Button(action: onNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .help("New Tab")
            .accessibilityLabel("New Tab")
            .accessibilityHint("Opens a new tab in the current workspace")
        }
        .padding(.horizontal, 7)
        .frame(height: 44)
        .background(OvertureDesign.sidebar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(OvertureDesign.separator)
                .frame(height: 1)
        }
        .tint(tint)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab strip")
    }

    private var tabClusters: [TabCluster] {
        let unpinnedTabs = tabs.filter { !$0.isPinned }
        let tabByID = unpinnedTabs.reduce(into: [UUID: BrowserTabController]()) {
            $0[$1.id] = $1
        }
        let islandByID = islands.reduce(into: [UUID: TabIslandRecord]()) {
            $0[$1.id] = $1
        }
        var consumedTabIDs = Set<UUID>()
        var result: [TabCluster] = []

        for tab in unpinnedTabs where !consumedTabIDs.contains(tab.id) {
            guard let groupID = tab.groupID, let island = islandByID[groupID] else {
                consumedTabIDs.insert(tab.id)
                result.append(.single(tab))
                continue
            }

            let recordedTabs = island.tabIDs.compactMap { tabByID[$0] }
            let recordedIDs = Set(recordedTabs.map(\.id))
            let additionalTabs = unpinnedTabs.filter {
                $0.groupID == groupID && !recordedIDs.contains($0.id)
            }
            let groupedTabs = recordedTabs + additionalTabs

            guard !groupedTabs.isEmpty else {
                consumedTabIDs.insert(tab.id)
                result.append(.single(tab))
                continue
            }

            consumedTabIDs.formUnion(groupedTabs.map(\.id))
            result.append(.island(island, groupedTabs))
        }
        return result
    }

    @ViewBuilder
    private func clusterView(_ cluster: TabCluster) -> some View {
        switch cluster {
        case let .single(tab):
            tabChip(tab, compact: false, groupColor: nil)
                .id(tab.id)

        case let .island(island, groupedTabs):
            TabIslandClusterView(
                island: island,
                tabs: groupedTabs,
                selectedTabID: selectedTabID,
                workspaces: workspaces,
                accent: tint,
                onSelectTab: onSelectTab,
                onCloseTab: onCloseTab,
                onDuplicateTab: onDuplicateTab,
                onTogglePin: onTogglePin,
                onMoveTab: onMoveTab,
                onReorderTab: onReorderTab,
                onCreateIsland: onCreateIsland,
                onAddToSplit: onAddToSplit
            )
        }
    }

    private func tabChip(
        _ tab: BrowserTabController,
        compact: Bool,
        groupColor: Color?
    ) -> some View {
        BrowserTabChip(
            tab: tab,
            isSelected: selectedTabID == tab.id,
            compact: compact,
            workspaces: workspaces,
            accent: tint,
            groupColor: groupColor,
            onSelect: { onSelectTab(tab.id) },
            onClose: { onCloseTab(tab.id) },
            onDuplicate: { onDuplicateTab(tab.id) },
            onTogglePin: { onTogglePin(tab.id) },
            onMove: { onMoveTab(tab.id, $0) },
            onReorder: { onReorderTab($0, tab.id) },
            onCreateIsland: { onCreateIsland(tab.id) },
            onAddToSplit: { onAddToSplit(tab.id) }
        )
    }
}

@MainActor
private enum TabCluster {
    case single(BrowserTabController)
    case island(TabIslandRecord, [BrowserTabController])

    var id: String {
        switch self {
        case let .single(tab): "tab-\(tab.id.uuidString)"
        case let .island(island, _): "island-\(island.id.uuidString)"
        }
    }
}

@MainActor
private struct TabIslandClusterView: View {
    let island: TabIslandRecord
    let tabs: [BrowserTabController]
    let selectedTabID: UUID?
    let workspaces: [WorkspaceRecord]
    let accent: Color
    let onSelectTab: (UUID) -> Void
    let onCloseTab: (UUID) -> Void
    let onDuplicateTab: (UUID) -> Void
    let onTogglePin: (UUID) -> Void
    let onMoveTab: (UUID, UUID) -> Void
    let onReorderTab: (UUID, UUID) -> Void
    let onCreateIsland: (UUID) -> Void
    let onAddToSplit: (UUID) -> Void

    private var islandColor: Color {
        tabStripColor(island.colorHex, fallback: accent)
    }

    var body: some View {
        if island.isCollapsed {
            collapsedIsland
        } else {
            expandedIsland
        }
    }

    private var expandedIsland: some View {
        HStack(spacing: 4) {
            VStack(spacing: 2) {
                Circle()
                    .fill(islandColor)
                    .frame(width: 7, height: 7)
                Text("\(tabs.count)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(islandColor)
            }
            .frame(width: 18)
            .help(island.name)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tab Island \(island.name), \(tabs.count) tabs")

            ForEach(tabs, id: \.id) { tab in
                BrowserTabChip(
                    tab: tab,
                    isSelected: selectedTabID == tab.id,
                    compact: false,
                    workspaces: workspaces,
                    accent: accent,
                    groupColor: islandColor,
                    onSelect: { onSelectTab(tab.id) },
                    onClose: { onCloseTab(tab.id) },
                    onDuplicate: { onDuplicateTab(tab.id) },
                    onTogglePin: { onTogglePin(tab.id) },
                    onMove: { onMoveTab(tab.id, $0) },
                    onReorder: { onReorderTab($0, tab.id) },
                    onCreateIsland: { onCreateIsland(tab.id) },
                    onAddToSplit: { onAddToSplit(tab.id) }
                )
                .id(tab.id)
            }
        }
        .padding(3)
        .background(
            islandColor.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(islandColor.opacity(0.22), lineWidth: 1)
        }
    }

    private var collapsedIsland: some View {
        Menu {
            Section(island.name) {
                ForEach(tabs, id: \.id) { tab in
                    Button {
                        onSelectTab(tab.id)
                    } label: {
                        Label(tab.title, systemImage: menuSymbol(for: tab))
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(islandColor)
                    .frame(width: 8, height: 8)
                Text(island.name.isEmpty ? "Tab Island" : island.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Text("\(tabs.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(islandColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(islandColor.opacity(0.12), in: Capsule())
            }
            .foregroundStyle(OvertureDesign.primaryText)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                islandColor.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(islandColor.opacity(0.28), lineWidth: 1)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Collapsed Tab Island \(island.name), \(tabs.count) tabs")
        .accessibilityHint("Opens a menu of tabs in this island")
    }

    private func menuSymbol(for tab: BrowserTabController) -> String {
        if tab.error != nil { return "exclamationmark.triangle" }
        if tab.isPrivate { return "eye.slash" }
        if tab.isLoading { return "arrow.triangle.2.circlepath" }
        return tab.isStartPage ? "sparkles" : "globe"
    }
}

@MainActor
private struct BrowserTabChip: View {
    @ObservedObject var tab: BrowserTabController

    let isSelected: Bool
    let compact: Bool
    let workspaces: [WorkspaceRecord]
    let accent: Color
    let groupColor: Color?
    let onSelect: () -> Void
    let onClose: () -> Void
    let onDuplicate: () -> Void
    let onTogglePin: () -> Void
    let onMove: (UUID) -> Void
    let onReorder: (UUID) -> Void
    let onCreateIsland: () -> Void
    let onAddToSplit: () -> Void

    @State private var isHovering = false

    private var stateColor: Color {
        if tab.error != nil { return .red }
        if tab.isPrivate { return Color(red: 0.55, green: 0.32, blue: 0.94) }
        return groupColor ?? accent
    }

    private var backgroundColor: Color {
        if isSelected { return OvertureDesign.selectedTab }
        if tab.isPrivate { return stateColor.opacity(0.075) }
        return isHovering ? OvertureDesign.panel : .clear
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: compact ? 0 : 7) {
                    stateIcon

                    if !compact {
                        Text(tab.title.isEmpty ? "New Tab" : tab.title)
                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(OvertureDesign.primaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 2)

                        if tab.isPrivate {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(stateColor)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.leading, compact ? 0 : 9)
                .padding(.trailing, compact ? 0 : 3)
                .frame(width: compact ? 34 : nil, height: 32)
                .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(tabHelp)
            .accessibilityLabel(tabAccessibilityLabel)
            .accessibilityHint("Selects this tab")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if !compact, isSelected || isHovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .background(OvertureDesign.secondaryText.opacity(0.08), in: Circle())
                .padding(.trailing, 5)
                .accessibilityLabel("Close \(tab.title)")
            }
        }
        .frame(width: compact ? 38 : 174, height: 34)
        .background(
            backgroundColor,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    isSelected ? stateColor.opacity(0.55) : OvertureDesign.separator.opacity(isHovering ? 0.7 : 0.25),
                    lineWidth: isSelected ? 1.25 : 1
                )
        }
        .overlay(alignment: .top) {
            if let groupColor {
                Capsule()
                    .fill(groupColor)
                    .frame(width: compact ? 18 : 54, height: 2)
                    .padding(.top, 1)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if tab.isLoading {
                GeometryReader { proxy in
                    Capsule()
                        .fill(stateColor)
                        .frame(
                            width: max(4, proxy.size.width * max(tab.estimatedProgress, 0.06)),
                            height: 2
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .allowsHitTesting(false)
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu { tabContextMenu }
        .draggable(tab.id.uuidString)
        .dropDestination(for: String.self) { identifiers, _ in
            guard let rawID = identifiers.first,
                  let sourceID = UUID(uuidString: rawID),
                  sourceID != tab.id else {
                return false
            }
            onReorder(sourceID)
            return true
        }
    }

    @ViewBuilder
    private var stateIcon: some View {
        if tab.isLoading {
            ProgressView()
                .controlSize(.mini)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        } else {
            Image(systemName: tabSymbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tab.error == nil ? stateColor : Color.red)
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var tabContextMenu: some View {
        Button("Duplicate Tab", systemImage: "plus.square.on.square", action: onDuplicate)
        Button(
            tab.isPinned ? "Unpin Tab" : "Pin Tab",
            systemImage: tab.isPinned ? "pin.slash" : "pin",
            action: onTogglePin
        )

        if workspaces.contains(where: { $0.id != tab.workspaceID && $0.isVisible }) {
            Menu("Move to Workspace", systemImage: "square.grid.2x2") {
                ForEach(
                    workspaces
                        .filter { $0.id != tab.workspaceID && $0.isVisible }
                        .sorted { $0.sortIndex < $1.sortIndex }
                ) { workspace in
                    Button(workspace.name) { onMove(workspace.id) }
                }
            }
        }

        Divider()
        Button("Create Tab Island", systemImage: "rectangle.3.group", action: onCreateIsland)
        Button("Add to Split Screen", systemImage: "rectangle.split.2x1", action: onAddToSplit)
        Divider()
        Button("Close Tab", systemImage: "xmark", role: .destructive, action: onClose)
    }

    private var tabSymbol: String {
        if tab.error != nil { return "exclamationmark.triangle.fill" }
        if tab.isPrivate { return "eye.slash.fill" }
        if tab.isStartPage { return "sparkles" }
        if tab.isPinned { return "pin.fill" }
        return "globe"
    }

    private var tabHelp: String {
        if let message = tab.errorMessage { return "\(tab.title) — \(message)" }
        return tab.url?.absoluteString ?? tab.title
    }

    private var tabAccessibilityLabel: String {
        var states: [String] = []
        if tab.isPrivate { states.append("private") }
        if tab.isPinned { states.append("pinned") }
        if tab.isLoading { states.append("loading") }
        if tab.error != nil { states.append("load error") }
        let suffix = states.isEmpty ? "" : ", " + states.joined(separator: ", ")
        return "\(tab.title.isEmpty ? "New Tab" : tab.title)\(suffix)"
    }
}

private func tabStripColor(_ hexValue: String, fallback: Color) -> Color {
    let hex = hexValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let rawValue = UInt64(hex, radix: 16) else { return fallback }
    return Color(
        red: Double((rawValue >> 16) & 0xFF) / 255,
        green: Double((rawValue >> 8) & 0xFF) / 255,
        blue: Double(rawValue & 0xFF) / 255
    )
}
