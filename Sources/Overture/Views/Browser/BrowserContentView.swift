import SwiftUI

@MainActor
struct BrowserContentView: View {
    let tabs: [BrowserTabController]
    let selectedTabID: UUID?
    let splitTabIDs: [UUID]
    let splitLayout: SplitLayout
    let focusedSplitTabID: UUID?
    let speedDials: [SpeedDialRecord]
    let recentHistory: [HistoryRecord]
    let searchProvider: SearchProvider
    let accent: BrowserAccent
    @Binding var isFindPresented: Bool

    let onNavigate: (UUID, URL) -> Void
    let onShowStartPage: (UUID) -> Void
    let onFocusSplitTab: (UUID) -> Void
    let onAddSpeedDial: () -> Void
    let onEditSpeedDial: (SpeedDialRecord) -> Void
    let onDeleteSpeedDial: (SpeedDialRecord) -> Void

    private var visibleSplitIDs: [UUID] {
        Array(splitTabIDs.filter { id in tabs.contains(where: { $0.id == id }) }.prefix(4))
    }

    var body: some View {
        Group {
            if visibleSplitIDs.count >= 2 {
                splitContent(ids: visibleSplitIDs)
            } else if let selectedTabID {
                pane(tabID: selectedTabID, isSplit: false)
            } else {
                BrowserEmptyState(
                    symbolName: "rectangle.stack.badge.plus",
                    title: "No open tabs",
                    message: "Open a new tab to start browsing.",
                    accent: OvertureDesign.accent(for: accent)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OvertureDesign.canvas)
            }
        }
        .background(OvertureDesign.canvas)
    }

    @ViewBuilder
    private func splitContent(ids: [UUID]) -> some View {
        switch splitLayout {
        case .twoColumns:
            HSplitView {
                pane(tabID: ids[0], isSplit: true)
                pane(tabID: ids[1], isSplit: true)
            }

        case .twoRows:
            VSplitView {
                pane(tabID: ids[0], isSplit: true)
                pane(tabID: ids[1], isSplit: true)
            }

        case .threeColumns:
            HSplitView {
                ForEach(Array(ids.prefix(3)), id: \.self) { id in
                    pane(tabID: id, isSplit: true)
                }
            }

        case .mainLeft:
            HSplitView {
                pane(tabID: ids[0], isSplit: true)
                    .frame(minWidth: 420)
                VSplitView {
                    ForEach(Array(ids.dropFirst().prefix(2)), id: \.self) { id in
                        pane(tabID: id, isSplit: true)
                    }
                }
            }

        case .mainRight:
            HSplitView {
                VSplitView {
                    ForEach(Array(ids.dropLast().prefix(2)), id: \.self) { id in
                        pane(tabID: id, isSplit: true)
                    }
                }
                pane(tabID: ids.last ?? ids[0], isSplit: true)
                    .frame(minWidth: 420)
            }

        case .fourGrid:
            VSplitView {
                HSplitView {
                    pane(tabID: ids[0], isSplit: true)
                    pane(tabID: ids[1], isSplit: true)
                }
                if ids.count >= 4 {
                    HSplitView {
                        pane(tabID: ids[2], isSplit: true)
                        pane(tabID: ids[3], isSplit: true)
                    }
                } else if ids.count == 3 {
                    pane(tabID: ids[2], isSplit: true)
                }
            }
        }
    }

    @ViewBuilder
    private func pane(tabID: UUID, isSplit: Bool) -> some View {
        if let controller = tabs.first(where: { $0.id == tabID }) {
            BrowserPaneView(
                controller: controller,
                isSplit: isSplit,
                isFocused: !isSplit || focusedSplitTabID == tabID,
                speedDials: speedDials,
                recentHistory: recentHistory,
                searchProvider: searchProvider,
                accent: accent,
                isFindPresented: isFindPresented && (!isSplit || focusedSplitTabID == tabID),
                onNavigate: { onNavigate(tabID, $0) },
                onShowStartPage: { onShowStartPage(tabID) },
                onFocus: { onFocusSplitTab(tabID) },
                onDismissFind: { isFindPresented = false },
                onAddSpeedDial: onAddSpeedDial,
                onEditSpeedDial: onEditSpeedDial,
                onDeleteSpeedDial: onDeleteSpeedDial
            )
        }
    }
}

@MainActor
private struct BrowserPaneView: View {
    @ObservedObject var controller: BrowserTabController

    let isSplit: Bool
    let isFocused: Bool
    let speedDials: [SpeedDialRecord]
    let recentHistory: [HistoryRecord]
    let searchProvider: SearchProvider
    let accent: BrowserAccent
    let isFindPresented: Bool
    let onNavigate: (URL) -> Void
    let onShowStartPage: () -> Void
    let onFocus: () -> Void
    let onDismissFind: () -> Void
    let onAddSpeedDial: () -> Void
    let onEditSpeedDial: (SpeedDialRecord) -> Void
    let onDeleteSpeedDial: (SpeedDialRecord) -> Void

    private var tint: Color { OvertureDesign.accent(for: accent) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if controller.isShowingStartPage {
                    StartPageView(
                        speedDials: speedDials,
                        recentHistory: recentHistory,
                        searchProvider: searchProvider,
                        accent: accent,
                        onNavigate: onNavigate,
                        onAddSpeedDial: onAddSpeedDial,
                        onEditSpeedDial: onEditSpeedDial,
                        onDeleteSpeedDial: onDeleteSpeedDial
                    )
                } else if let error = controller.error {
                    PageErrorView(
                        error: error,
                        onRetry: { controller.reload() },
                        onStartPage: onShowStartPage
                    )
                } else {
                    WebViewRepresentable(controller: controller)
                        .id(controller.id)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if isSplit {
                Button(action: onFocus) {
                    HStack(spacing: 6) {
                        Image(systemName: controller.isPrivate ? "hand.raised.fill" : "globe")
                        Text(controller.title)
                            .lineLimit(1)
                        if controller.isLoading {
                            ProgressView().controlSize(.mini)
                        }
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.ultraThickMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(isFocused ? tint : OvertureDesign.separator, lineWidth: isFocused ? 1.5 : 1) }
                }
                .buttonStyle(.plain)
                .padding(8)
                .help("Focus \(controller.title)")
            }

            if isFindPresented, !controller.isShowingStartPage {
                FindBar(
                    controller: controller,
                    isPresented: Binding(
                        get: { isFindPresented },
                        set: { if !$0 { onDismissFind() } }
                    )
                )
                .padding(.top, isSplit ? 44 : 10)
                .padding(.trailing, 10)
            }
        }
        .overlay {
            if controller.isPrivate {
                Rectangle()
                    .strokeBorder(Color.purple.opacity(isFocused ? 0.65 : 0.30), lineWidth: isFocused ? 2 : 1)
                    .allowsHitTesting(false)
            } else if isSplit {
                Rectangle()
                    .strokeBorder(isFocused ? tint.opacity(0.70) : .clear, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browser pane, \(controller.title)")
        .accessibilityValue(isFocused ? "Focused" : "")
    }
}
