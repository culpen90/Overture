import SwiftUI

@MainActor
struct BrowserCommandActions {
    let newTab: () -> Void
    let newPrivateTab: () -> Void
    let closeTab: () -> Void
    let reopenClosedTab: () -> Void
    let focusLocation: () -> Void
    let reload: () -> Void
    let goBack: () -> Void
    let goForward: () -> Void
    let showStartPage: () -> Void
    let showFind: () -> Void
    let toggleBookmark: () -> Void
    let showBookmarks: () -> Void
    let showHistory: () -> Void
    let showDownloads: () -> Void
    let nextTab: () -> Void
    let previousTab: () -> Void
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let resetZoom: () -> Void
    let toggleSidebar: () -> Void
    let enterSplit: () -> Void
    let exitSplit: () -> Void
    let printPage: () -> Void
}

private struct BrowserCommandActionsKey: FocusedValueKey {
    typealias Value = BrowserCommandActions
}

extension FocusedValues {
    var browserCommandActions: BrowserCommandActions? {
        get { self[BrowserCommandActionsKey.self] }
        set { self[BrowserCommandActionsKey.self] = newValue }
    }
}

struct BrowserCommands: Commands {
    @FocusedValue(\.browserCommandActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Tab") { actions?.newTab() }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(actions == nil)

            Button("New Private Tab") { actions?.newPrivateTab() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions == nil)

            Button("Reopen Closed Tab") { actions?.reopenClosedTab() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(actions == nil)

            Divider()

            Button("Close Tab") { actions?.closeTab() }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(actions == nil)
        }

        CommandMenu("Navigate") {
            Button("Open Location…") { actions?.focusLocation() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(actions == nil)

            Button("Start Page") { actions?.showStartPage() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(actions == nil)

            Divider()

            Button("Back") { actions?.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(actions == nil)

            Button("Forward") { actions?.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(actions == nil)

            Button("Reload Page") { actions?.reload() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(actions == nil)
        }

        CommandMenu("Tabs") {
            Button("Next Tab") { actions?.nextTab() }
                .keyboardShortcut("}", modifiers: [.command, .shift])
                .disabled(actions == nil)

            Button("Previous Tab") { actions?.previousTab() }
                .keyboardShortcut("{", modifiers: [.command, .shift])
                .disabled(actions == nil)

            Divider()

            Button("Open Split View") { actions?.enterSplit() }
                .keyboardShortcut("s", modifiers: [.command, .control])
                .disabled(actions == nil)

            Button("Exit Split View") { actions?.exitSplit() }
                .disabled(actions == nil)
        }

        CommandGroup(after: .sidebar) {
            Button("Find on Page…") { actions?.showFind() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(actions == nil)

            Divider()

            Button("Actual Size") { actions?.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(actions == nil)

            Button("Zoom In") { actions?.zoomIn() }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(actions == nil)

            Button("Zoom Out") { actions?.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(actions == nil)

            Divider()

            Button("Toggle Overture Sidebar") { actions?.toggleSidebar() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }

        CommandMenu("Library") {
            Button("Bookmark This Page") { actions?.toggleBookmark() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(actions == nil)

            Button("Bookmarks") { actions?.showBookmarks() }
                .keyboardShortcut("b", modifiers: [.command, .shift])
                .disabled(actions == nil)

            Button("History") { actions?.showHistory() }
                .keyboardShortcut("y", modifiers: .command)
                .disabled(actions == nil)

            Button("Downloads") { actions?.showDownloads() }
                .keyboardShortcut("j", modifiers: .command)
                .disabled(actions == nil)
        }

        CommandGroup(after: .printItem) {
            Button("Print Page…") { actions?.printPage() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(actions == nil)
        }
    }
}
