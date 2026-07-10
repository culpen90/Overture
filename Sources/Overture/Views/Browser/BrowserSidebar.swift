import SwiftUI

enum SidebarDestination: String, CaseIterable, Identifiable {
    case startPage
    case bookmarks
    case history
    case downloads
    case pinboards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startPage: "Start Page"
        case .bookmarks: "Bookmarks"
        case .history: "History"
        case .downloads: "Downloads"
        case .pinboards: "Pinboards"
        }
    }

    var symbolName: String {
        switch self {
        case .startPage: "sparkles"
        case .bookmarks: "star"
        case .history: "clock.arrow.circlepath"
        case .downloads: "arrow.down.circle"
        case .pinboards: "note.text"
        }
    }
}

struct BrowserSidebar: View {
    @Binding var isExpanded: Bool

    let workspaces: [WorkspaceRecord]
    let activeWorkspaceID: UUID?
    let currentDestination: SidebarDestination
    let downloadBadge: Int
    let accent: BrowserAccent
    let onSelectDestination: (SidebarDestination) -> Void
    let onSelectWorkspace: (UUID) -> Void
    let onAddWorkspace: () -> Void
    let onEditWorkspace: (WorkspaceRecord) -> Void
    let onOpenProtonCompanion: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        isExpanded: Binding<Bool>,
        workspaces: [WorkspaceRecord],
        activeWorkspaceID: UUID?,
        currentDestination: SidebarDestination,
        downloadBadge: Int,
        accent: BrowserAccent,
        onSelectDestination: @escaping (SidebarDestination) -> Void,
        onSelectWorkspace: @escaping (UUID) -> Void,
        onAddWorkspace: @escaping () -> Void,
        onEditWorkspace: @escaping (WorkspaceRecord) -> Void,
        onOpenProtonCompanion: @escaping () -> Void
    ) {
        _isExpanded = isExpanded
        self.workspaces = workspaces
        self.activeWorkspaceID = activeWorkspaceID
        self.currentDestination = currentDestination
        self.downloadBadge = max(downloadBadge, 0)
        self.accent = accent
        self.onSelectDestination = onSelectDestination
        self.onSelectWorkspace = onSelectWorkspace
        self.onAddWorkspace = onAddWorkspace
        self.onEditWorkspace = onEditWorkspace
        self.onOpenProtonCompanion = onOpenProtonCompanion
    }

    private var tint: Color { OvertureDesign.accent(for: accent) }
    private var visibleWorkspaces: [WorkspaceRecord] {
        workspaces
            .filter { $0.isVisible || $0.id == activeWorkspaceID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(spacing: 6) {
                    destinationRail

                    Divider()
                        .padding(.vertical, 5)

                    workspaceRail
                }
                .padding(.horizontal, isExpanded ? 10 : 9)
                .padding(.vertical, 10)
            }

            Divider()
            utilityRail
                .padding(.horizontal, isExpanded ? 10 : 9)
                .padding(.vertical, 9)
        }
        .frame(width: isExpanded ? 220 : 62)
        .background(OvertureDesign.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(OvertureDesign.separator)
                .frame(width: 1)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isExpanded)
        .tint(tint)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browser sidebar")
    }

    @ViewBuilder
    private var header: some View {
        if isExpanded {
            HStack(spacing: 10) {
                OvertureMark(size: 30, accent: tint)
                Text("Overture")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 4)
                collapseButton
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
        } else {
            VStack(spacing: 5) {
                OvertureMark(size: 28, accent: tint)
                collapseButton
            }
            .frame(height: 68)
        }
    }

    private var collapseButton: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Image(systemName: isExpanded ? "sidebar.left" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
        .help(isExpanded ? "Collapse Sidebar" : "Expand Sidebar")
        .accessibilityLabel(isExpanded ? "Collapse Sidebar" : "Expand Sidebar")
        .accessibilityHint("Changes the sidebar between compact and expanded layouts")
    }

    private var destinationRail: some View {
        VStack(spacing: 4) {
            ForEach(SidebarDestination.allCases) { destination in
                Button {
                    onSelectDestination(destination)
                } label: {
                    SidebarRowLabel(
                        title: destination.title,
                        symbolName: destination.symbolName,
                        isExpanded: isExpanded,
                        isSelected: currentDestination == destination,
                        accent: tint,
                        badge: destination == .downloads ? downloadBadge : 0
                    )
                }
                .buttonStyle(.plain)
                .help(destination.title)
                .accessibilityLabel(destinationAccessibilityLabel(destination))
                .accessibilityHint("Opens \(destination.title)")
                .accessibilityAddTraits(currentDestination == destination ? .isSelected : [])
            }
        }
    }

    private var workspaceRail: some View {
        VStack(spacing: 5) {
            if isExpanded {
                HStack {
                    Text("WORKSPACES")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(OvertureDesign.secondaryText)
                        .tracking(0.7)
                    Spacer()
                    Button(action: onAddWorkspace) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
                    .help("Add Workspace")
                    .accessibilityLabel("Add Workspace")
                }
                .padding(.leading, 9)
                .frame(height: 28)
            }

            ForEach(visibleWorkspaces) { workspace in
                WorkspaceSidebarRow(
                    workspace: workspace,
                    isExpanded: isExpanded,
                    isSelected: workspace.id == activeWorkspaceID,
                    accent: tint,
                    onSelect: { onSelectWorkspace(workspace.id) },
                    onEdit: { onEditWorkspace(workspace) }
                )
            }

            if !isExpanded {
                Button(action: onAddWorkspace) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 38, height: 34)
                        .foregroundStyle(OvertureDesign.secondaryText)
                        .background(
                            OvertureDesign.secondaryText.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .help("Add Workspace")
                .accessibilityLabel("Add Workspace")
            }
        }
    }

    private var utilityRail: some View {
        VStack(spacing: 4) {
            Button(action: onOpenProtonCompanion) {
                SidebarRowLabel(
                    title: "Proton VPN",
                    symbolName: "shield.lefthalf.filled",
                    isExpanded: isExpanded,
                    isSelected: false,
                    accent: Color(red: 0.40, green: 0.29, blue: 0.92),
                    badge: 0
                )
            }
            .buttonStyle(.plain)
            .help("Open Proton VPN Companion")
            .accessibilityLabel("Proton VPN Companion")
            .accessibilityHint("Opens the companion app or installation options")

            SettingsLink {
                SidebarRowLabel(
                    title: "Settings",
                    symbolName: "gearshape",
                    isExpanded: isExpanded,
                    isSelected: false,
                    accent: tint,
                    badge: 0
                )
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens Overture settings")
        }
    }

    private func destinationAccessibilityLabel(_ destination: SidebarDestination) -> String {
        if destination == .downloads, downloadBadge > 0 {
            return "Downloads, \(downloadBadge) active"
        }
        return destination.title
    }
}

private struct SidebarRowLabel: View {
    let title: String
    let symbolName: String
    let isExpanded: Bool
    let isSelected: Bool
    let accent: Color
    let badge: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)
                .overlay(alignment: .topTrailing) {
                    if !isExpanded, badge > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(OvertureDesign.sidebar, lineWidth: 1.5))
                            .offset(x: 4, y: -4)
                    }
                }

            if isExpanded {
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)

                Spacer(minLength: 4)

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                }
            }
        }
        .foregroundStyle(isSelected ? accent : OvertureDesign.primaryText)
        .padding(.horizontal, isExpanded ? 10 : 0)
        .frame(width: isExpanded ? nil : 42, height: 36)
        .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
        .background(
            isSelected ? accent.opacity(0.11) : .clear,
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .contentShape(Rectangle())
    }
}

private struct WorkspaceSidebarRow: View {
    let workspace: WorkspaceRecord
    let isExpanded: Bool
    let isSelected: Bool
    let accent: Color
    let onSelect: () -> Void
    let onEdit: () -> Void

    private var workspaceColor: Color {
        sidebarColor(workspace.colorHex, fallback: accent)
    }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(workspaceColor.opacity(isSelected ? 0.18 : 0.1))
                        Image(systemName: workspace.symbolName.isEmpty ? "square.grid.2x2" : workspace.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(workspaceColor)
                    }
                    .frame(width: 28, height: 28)

                    if isExpanded {
                        Text(workspace.name)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? workspaceColor : OvertureDesign.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                    }
                }
                .padding(.horizontal, isExpanded ? 5 : 3)
                .frame(width: isExpanded ? nil : 42, height: 36)
                .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
                .background(
                    isSelected ? workspaceColor.opacity(0.09) : .clear,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(workspace.name)
            .accessibilityLabel("Workspace \(workspace.name)")
            .accessibilityHint("Switches to this workspace")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .contextMenu {
                Button("Edit Workspace", systemImage: "pencil", action: onEdit)
            }

            if isExpanded {
                Menu {
                    Button("Edit Workspace", systemImage: "pencil", action: onEdit)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Options for workspace \(workspace.name)")
            }
        }
    }
}

private func sidebarColor(_ hexValue: String, fallback: Color) -> Color {
    let hex = hexValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let rawValue = UInt64(hex, radix: 16) else { return fallback }
    return Color(
        red: Double((rawValue >> 16) & 0xFF) / 255,
        green: Double((rawValue >> 8) & 0xFF) / 255,
        blue: Double(rawValue & 0xFF) / 255
    )
}
