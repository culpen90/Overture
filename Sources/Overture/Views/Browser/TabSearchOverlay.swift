import SwiftUI

@MainActor
struct TabSearchOverlay: View {
    private let controllers: [BrowserTabController]
    private let workspaces: [WorkspaceRecord]
    private let groups: [TabIslandRecord]
    private let activeControllerID: UUID?
    private let accent: BrowserAccent
    private let onSelect: (BrowserTabController) -> Void
    private let onClose: () -> Void

    @State private var query = ""
    @State private var highlightedControllerID: UUID?
    @FocusState private var isSearchFocused: Bool

    init(
        controllers: [BrowserTabController],
        workspaces: [WorkspaceRecord],
        groups: [TabIslandRecord],
        activeControllerID: UUID? = nil,
        accent: BrowserAccent = .overture,
        onSelect: @escaping (BrowserTabController) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.controllers = controllers
        self.workspaces = workspaces
        self.groups = groups
        self.activeControllerID = activeControllerID
        self.accent = accent
        self.onSelect = onSelect
        self.onClose = onClose
    }

    private var tint: Color {
        OvertureDesign.accent(for: accent)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                Divider()
                results
            }
            .frame(maxWidth: 720, maxHeight: 540)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(OvertureDesign.separator)
            }
            .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
            .padding(40)
        }
        .tint(tint)
        .onAppear {
            highlightedControllerID = filteredControllers.first?.id
        }
        .task {
            await Task.yield()
            isSearchFocused = true
        }
        .onChange(of: query) { _, _ in
            highlightedControllerID = filteredControllers.first?.id
        }
        .onMoveCommand(perform: moveSelection)
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search open tabs")
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Search Tabs")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(resultSummary)
                        .font(.caption)
                        .foregroundStyle(OvertureDesign.secondaryText)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
                .keyboardShortcut(.cancelAction)
                .help("Close Tab Search (Esc)")
                .accessibilityLabel("Close tab search")
            }

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSearchFocused ? tint : OvertureDesign.secondaryText)
                    .accessibilityHidden(true)

                TextField("Search by title or address", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .onSubmit(selectHighlightedController)
                    .accessibilityLabel("Search open tabs by title or address")

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(OvertureDesign.secondaryText)
                    .help("Clear search")
                    .accessibilityLabel("Clear tab search")
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(
                OvertureDesign.elevatedPanel,
                in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
                    .stroke(
                        isSearchFocused ? tint.opacity(0.72) : OvertureDesign.separator,
                        lineWidth: isSearchFocused ? 1.5 : 1
                    )
            }
        }
        .padding(16)
    }

    @ViewBuilder
    private var results: some View {
        if filteredControllers.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: query.isEmpty ? "rectangle.stack" : "magnifyingglass")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(OvertureDesign.secondaryText)
                Text(query.isEmpty ? "No Open Tabs" : "No Matching Tabs")
                    .font(.headline)
                Text(
                    query.isEmpty
                        ? "Open a tab to make it available here."
                        : "Try a different page title or address."
                )
                .font(.caption)
                .foregroundStyle(OvertureDesign.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(filteredControllers, id: \.id) { controller in
                            TabSearchResultRow(
                                controller: controller,
                                workspaceName: workspaceName(for: controller),
                                groupName: groupName(for: controller),
                                duplicateCount: duplicateCount(for: controller),
                                isCurrent: controller.id == activeControllerID,
                                isHighlighted: controller.id == highlightedControllerID,
                                tint: tint,
                                onHighlight: {
                                    highlightedControllerID = controller.id
                                },
                                onSelect: {
                                    select(controller)
                                }
                            )
                            .id(controller.id)
                        }
                    }
                    .padding(7)
                }
                .onChange(of: highlightedControllerID) { _, newID in
                    guard let newID else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    private var resultSummary: String {
        let count = filteredControllers.count
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return count == 1 ? "1 open tab" : "\(count) open tabs"
        }
        return count == 1 ? "1 matching tab" : "\(count) matching tabs"
    }

    private var filteredControllers: [BrowserTabController] {
        let normalizedQuery = normalized(query)

        return controllers.enumerated()
            .compactMap { index, controller -> (BrowserTabController, Int, Int)? in
                guard let score = matchScore(for: controller, query: normalizedQuery) else {
                    return nil
                }
                return (controller, score, index)
            }
            .sorted { left, right in
                let leftIsCurrent = left.0.id == activeControllerID
                let rightIsCurrent = right.0.id == activeControllerID
                if leftIsCurrent != rightIsCurrent { return leftIsCurrent }
                if left.1 != right.1 { return left.1 < right.1 }
                return left.2 < right.2
            }
            .map(\.0)
    }

    private var duplicateCounts: [String: Int] {
        controllers.reduce(into: [:]) { result, controller in
            guard let key = duplicateKey(for: controller) else { return }
            result[key, default: 0] += 1
        }
    }

    private func matchScore(for controller: BrowserTabController, query: String) -> Int? {
        guard !query.isEmpty else { return 0 }

        let title = normalized(controller.title)
        let address = normalized(controller.url?.absoluteString ?? controller.displayURL)
        let host = normalized(controller.url?.host ?? "")

        if title == query || address == query || host == query { return 0 }
        if title.hasPrefix(query) { return 1 }
        if host.hasPrefix(query) || address.hasPrefix(query) { return 2 }
        if title.contains(query) { return 3 }
        if host.contains(query) || address.contains(query) { return 4 }
        return nil
    }

    private func workspaceName(for controller: BrowserTabController) -> String {
        workspaces.first { $0.id == controller.workspaceID }?.name.nonemptyTitle ?? "Workspace"
    }

    private func groupName(for controller: BrowserTabController) -> String? {
        guard let groupID = controller.groupID else { return nil }
        return groups.first { $0.id == groupID }?.name.nonemptyTitle ?? "Group"
    }

    private func duplicateCount(for controller: BrowserTabController) -> Int {
        guard let key = duplicateKey(for: controller) else { return 0 }
        return duplicateCounts[key, default: 0]
    }

    private func duplicateKey(for controller: BrowserTabController) -> String? {
        guard !controller.isShowingStartPage,
              let url = controller.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil
        if components.path == "/" { components.path = "" }
        return components.string?.lowercased()
    }

    private func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            )
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let results = filteredControllers
        guard !results.isEmpty else { return }

        let currentIndex = highlightedControllerID.flatMap { selectedID in
            results.firstIndex { $0.id == selectedID }
        } ?? 0

        switch direction {
        case .up:
            highlightedControllerID = results[max(0, currentIndex - 1)].id
        case .down:
            highlightedControllerID = results[min(results.count - 1, currentIndex + 1)].id
        default:
            break
        }
    }

    private func selectHighlightedController() {
        let controller = highlightedControllerID.flatMap { selectedID in
            filteredControllers.first { $0.id == selectedID }
        } ?? filteredControllers.first

        guard let controller else { return }
        select(controller)
    }

    private func select(_ controller: BrowserTabController) {
        onSelect(controller)
        onClose()
    }
}

@MainActor
private struct TabSearchResultRow: View {
    @ObservedObject var controller: BrowserTabController

    let workspaceName: String
    let groupName: String?
    let duplicateCount: Int
    let isCurrent: Bool
    let isHighlighted: Bool
    let tint: Color
    let onHighlight: () -> Void
    let onSelect: () -> Void

    private var pageAddress: String {
        if controller.isShowingStartPage { return "Overture Start Page" }
        return controller.url?.absoluteString ?? controller.displayURL
    }

    private var pageTitle: String {
        controller.title.nonemptyTitle ?? controller.url?.host ?? "Untitled Tab"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(isCurrent ? 0.16 : 0.08))
                    Image(systemName: controller.isPrivate ? "eye.slash" : "globe")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isCurrent ? tint : OvertureDesign.secondaryText)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(pageTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OvertureDesign.primaryText)
                            .lineLimit(1)

                        if controller.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(OvertureDesign.secondaryText)
                                .help("Pinned tab")
                        }
                    }

                    Text(pageAddress)
                        .font(.system(size: 10.5))
                        .foregroundStyle(OvertureDesign.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 5) {
                        TabCue(symbol: "square.grid.2x2", title: workspaceName)

                        if let groupName {
                            TabCue(symbol: "rectangle.3.group", title: groupName)
                        }

                        if controller.isPrivate {
                            TabCue(symbol: "eye.slash.fill", title: "Private", color: .purple)
                        }

                        if duplicateCount > 1 {
                            TabCue(
                                symbol: "square.on.square",
                                title: "\(duplicateCount) duplicates",
                                color: .orange
                            )
                            .help("\(duplicateCount) open tabs share this address")
                        }

                        if isCurrent {
                            TabCue(symbol: "checkmark.circle.fill", title: "Current", color: tint)
                        }
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: "return")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isHighlighted ? tint : Color.clear)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(
                isHighlighted ? tint.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering in
            if isHovering { onHighlight() }
        }
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Switch to this tab")
    }

    private var accessibilityDescription: String {
        var details = [pageTitle, pageAddress, "Workspace \(workspaceName)"]
        if let groupName { details.append("Group \(groupName)") }
        if controller.isPrivate { details.append("Private") }
        if duplicateCount > 1 { details.append("\(duplicateCount) duplicate tabs") }
        if isCurrent { details.append("Current tab") }
        return details.joined(separator: ", ")
    }
}

private struct TabCue: View {
    let symbol: String
    let title: String
    var color: Color = OvertureDesign.secondaryText

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.09), in: Capsule())
    }
}

private extension String {
    var nonemptyTitle: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
