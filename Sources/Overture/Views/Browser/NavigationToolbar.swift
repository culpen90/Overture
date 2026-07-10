import SwiftUI

@MainActor
struct NavigationToolbar: View {
    @ObservedObject private var controller: BrowserTabController
    @ObservedObject private var preferences: BrowserPreferences

    private let isBookmarked: Bool
    private let bookmarks: [BookmarkRecord]
    private let history: [HistoryRecord]
    private let isSplitActive: Bool
    private let focusRequest: Int
    private let onNavigate: (String) -> Void
    private let toggleBookmark: () -> Void
    private let showDownloads: () -> Void
    private let showFind: () -> Void
    private let toggleContentBlocking: () -> Void
    private let enterSplit: () -> Void
    private let takeSnapshot: () -> Void
    private let savePDF: () -> Void

    @State private var addressText: String
    @State private var isShowingSuggestions = false
    @State private var highlightedSuggestionID: String?
    @FocusState private var isAddressFocused: Bool

    init(
        controller: BrowserTabController,
        isBookmarked: Bool,
        bookmarks: [BookmarkRecord],
        history: [HistoryRecord],
        isSplitActive: Bool = false,
        preferences: BrowserPreferences,
        focusRequest: Int,
        onNavigate: @escaping (String) -> Void,
        toggleBookmark: @escaping () -> Void,
        showDownloads: @escaping () -> Void,
        showFind: @escaping () -> Void,
        toggleContentBlocking: @escaping () -> Void,
        enterSplit: @escaping () -> Void,
        takeSnapshot: @escaping () -> Void,
        savePDF: @escaping () -> Void
    ) {
        self.controller = controller
        self.isBookmarked = isBookmarked
        self.bookmarks = bookmarks
        self.history = history
        self.isSplitActive = isSplitActive
        self.preferences = preferences
        self.focusRequest = focusRequest
        self.onNavigate = onNavigate
        self.toggleBookmark = toggleBookmark
        self.showDownloads = showDownloads
        self.showFind = showFind
        self.toggleContentBlocking = toggleContentBlocking
        self.enterSplit = enterSplit
        self.takeSnapshot = takeSnapshot
        self.savePDF = savePDF
        _addressText = State(initialValue: controller.displayURL)
    }

    private var tint: Color {
        OvertureDesign.accent(for: preferences.accent)
    }

    private var canUsePageActions: Bool {
        !controller.isShowingStartPage && controller.url != nil
    }

    var body: some View {
        HStack(spacing: OvertureDesign.Spacing.compact) {
            navigationControls
            omnibox
                .zIndex(20)
            trailingControls
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(OvertureDesign.panel)
        .overlay(alignment: .bottom) {
            if controller.isLoading {
                ProgressView(value: controller.estimatedProgress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(tint)
                    .accessibilityLabel("Page loading progress")
                    .accessibilityValue(
                        "\(Int((controller.estimatedProgress * 100).rounded())) percent"
                    )
            }
        }
        .tint(tint)
        .zIndex(isShowingSuggestions ? 100 : 0)
        .onAppear {
            synchronizeAddress(force: true)
        }
        .onChange(of: controller.id) { _, _ in
            synchronizeAddress(force: true)
        }
        .onChange(of: controller.displayURL) { _, _ in
            synchronizeAddress(force: false)
        }
        .onChange(of: focusRequest) { _, _ in
            synchronizeAddress(force: true)
            isAddressFocused = true
            updateSuggestions()
        }
        .onChange(of: isAddressFocused) { _, isFocused in
            if isFocused {
                updateSuggestions()
            } else {
                isShowingSuggestions = false
                highlightedSuggestionID = nil
                synchronizeAddress(force: true)
            }
        }
        .onChange(of: addressText) { _, _ in
            updateSuggestions()
        }
        .onMoveCommand(perform: moveSuggestionSelection)
    }

    private var navigationControls: some View {
        HStack(spacing: 2) {
            Button {
                controller.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .disabled(!controller.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
            .help("Back (⌘[)")
            .accessibilityLabel("Back")

            Button {
                controller.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .disabled(!controller.canGoForward)
            .keyboardShortcut("]", modifiers: .command)
            .help("Forward (⌘])")
            .accessibilityLabel("Forward")

            Button {
                controller.reloadOrStop()
            } label: {
                Image(systemName: controller.isLoading ? "xmark" : "arrow.clockwise")
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .disabled(controller.isShowingStartPage)
            .keyboardShortcut("r", modifiers: .command)
            .help(controller.isLoading ? "Stop loading" : "Reload (⌘R)")
            .accessibilityLabel(controller.isLoading ? "Stop loading" : "Reload page")
        }
    }

    private var omnibox: some View {
        HStack(spacing: 7) {
            SiteIdentityIndicator(url: controller.url, isStartPage: controller.isShowingStartPage)

            if controller.isPrivate {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.purple)
                    .help("Private tab — this page is not added to saved history")
                    .accessibilityLabel("Private tab")
            }

            TextField("Search or enter address", text: $addressText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isAddressFocused)
                .onSubmit(submitAddress)
                .accessibilityLabel("Address and search")
                .help("Address and search (⌘L)")

            if isAddressFocused, !addressText.isEmpty {
                Button {
                    addressText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(OvertureDesign.secondaryText)
                .help("Clear address")
                .accessibilityLabel("Clear address")
            }

            Button(action: toggleContentBlocking) {
                Image(systemName: shieldSymbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(shieldColor)
            }
            .buttonStyle(.plain)
            .help(shieldHelp)
            .accessibilityLabel("Content blocking")
            .accessibilityValue(shieldAccessibilityValue)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 32, maxHeight: 32)
        .background(
            OvertureDesign.elevatedPanel,
            in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
                .stroke(
                    isAddressFocused ? tint.opacity(0.72) : OvertureDesign.separator,
                    lineWidth: isAddressFocused ? 1.5 : 1
                )
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { proxy in
                if isShowingSuggestions, !omniboxSuggestions.isEmpty {
                    suggestionPanel
                        .frame(width: proxy.size.width)
                        .offset(y: proxy.size.height + 5)
                }
            }
        }
    }

    private var trailingControls: some View {
        HStack(spacing: 2) {
            Button(action: toggleBookmark) {
                Image(systemName: isBookmarked ? "star.fill" : "star")
                    .foregroundStyle(isBookmarked ? tint : OvertureDesign.primaryText)
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .disabled(!canUsePageActions)
            .keyboardShortcut("d", modifiers: .command)
            .help(isBookmarked ? "Remove Bookmark (⌘D)" : "Add Bookmark (⌘D)")
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")

            Button(action: showDownloads) {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .keyboardShortcut("j", modifiers: [.command, .shift])
            .help("Downloads (⇧⌘J)")
            .accessibilityLabel("Show downloads")

            Button(action: enterSplit) {
                Image(systemName: isSplitActive ? "rectangle" : "rectangle.split.2x1")
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .disabled(!canUsePageActions && !isSplitActive)
            .help(isSplitActive ? "Exit Split View" : "Open this page in Split View")
            .accessibilityLabel(isSplitActive ? "Exit split view" : "Enter split view")

            pageMenu
        }
    }

    private var pageMenu: some View {
        Menu {
            Section("Page Zoom") {
                Button("Zoom In") {
                    controller.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!canUsePageActions)

                Button("Zoom Out") {
                    controller.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!canUsePageActions)

                Button("Actual Size (\(zoomPercentage))") {
                    controller.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!canUsePageActions || controller.zoomLevel == 1)
            }

            Divider()

            Button("Find in Page…", action: showFind)
                .keyboardShortcut("f", modifiers: .command)
                .disabled(!canUsePageActions)

            Button("Print…") {
                controller.printPage()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(!canUsePageActions)

            Button("Take Page Snapshot…", action: takeSnapshot)
                .disabled(!canUsePageActions)

            Button("Save Page as PDF…", action: savePDF)
                .disabled(!canUsePageActions)

            Divider()

            Button(
                controller.isContentBlockingEnabled
                    ? "Turn Off Content Blocking for This Tab"
                    : "Turn On Content Blocking for This Tab",
                action: toggleContentBlocking
            )
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Page options")
        .accessibilityLabel("Page options")
    }

    private var suggestionPanel: some View {
        VStack(spacing: 2) {
            ForEach(omniboxSuggestions) { suggestion in
                Button {
                    chooseSuggestion(suggestion)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: suggestion.kind.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(tint)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(OvertureDesign.primaryText)
                                .lineLimit(1)

                            Text(suggestion.subtitle)
                                .font(.system(size: 10.5))
                                .foregroundStyle(OvertureDesign.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer(minLength: 8)

                        Text(suggestion.kind.title)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(OvertureDesign.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 43)
                    .contentShape(Rectangle())
                    .background(
                        suggestion.id == highlightedSuggestionID
                            ? tint.opacity(0.12)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    if isHovering {
                        highlightedSuggestionID = suggestion.id
                    }
                }
                .accessibilityLabel("\(suggestion.title), \(suggestion.kind.title)")
                .accessibilityHint(suggestion.subtitle)
            }
        }
        .padding(5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(OvertureDesign.separator)
        }
        .shadow(color: .black.opacity(0.18), radius: 16, y: 7)
    }

    private var omniboxSuggestions: [OmniboxSuggestion] {
        let query = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }

        var suggestions: [OmniboxSuggestion] = []
        if let resolvedURL = AddressResolver.resolve(
            query,
            searchProvider: preferences.searchProvider,
            httpsFirst: preferences.httpsFirst
        ) {
            let searchURL = preferences.searchProvider.searchURL(for: query)
            let isSearch = resolvedURL == searchURL
            suggestions.append(
                OmniboxSuggestion(
                    id: "query:\(query)",
                    title: isSearch
                        ? "Search \(preferences.searchProvider.title) for “\(query)”"
                        : "Go to \(query)",
                    subtitle: resolvedURL.absoluteString,
                    navigationText: resolvedURL.absoluteString,
                    kind: isSearch ? .search : .address
                )
            )
        }

        let normalizedQuery = query.searchNormalized
        var seenURLs = Set<String>()

        let matchingBookmarks = bookmarks
            .filter { bookmark in
                bookmark.searchText.searchNormalized.contains(normalizedQuery)
            }
            .sorted { left, right in
                let leftScore = suggestionScore(
                    title: left.title,
                    url: left.url,
                    query: normalizedQuery
                )
                let rightScore = suggestionScore(
                    title: right.title,
                    url: right.url,
                    query: normalizedQuery
                )
                if leftScore != rightScore { return leftScore < rightScore }
                return left.sortIndex < right.sortIndex
            }

        for bookmark in matchingBookmarks {
            let key = bookmark.url.absoluteString.lowercased()
            guard seenURLs.insert(key).inserted else { continue }
            suggestions.append(
                OmniboxSuggestion(
                    id: "bookmark:\(key)",
                    title: bookmark.title.nonempty ?? bookmark.url.host ?? bookmark.url.absoluteString,
                    subtitle: bookmark.url.absoluteString,
                    navigationText: bookmark.url.absoluteString,
                    kind: .bookmark
                )
            )
            if suggestions.count == 7 { return suggestions }
        }

        let matchingHistory = history
            .filter { record in
                "\(record.title) \(record.url.absoluteString)"
                    .searchNormalized
                    .contains(normalizedQuery)
            }
            .sorted { left, right in
                let leftScore = suggestionScore(
                    title: left.title,
                    url: left.url,
                    query: normalizedQuery
                )
                let rightScore = suggestionScore(
                    title: right.title,
                    url: right.url,
                    query: normalizedQuery
                )
                if leftScore != rightScore { return leftScore < rightScore }
                return left.lastVisitedAt > right.lastVisitedAt
            }

        for record in matchingHistory {
            let key = record.url.absoluteString.lowercased()
            guard seenURLs.insert(key).inserted else { continue }
            suggestions.append(
                OmniboxSuggestion(
                    id: "history:\(key)",
                    title: record.title.nonempty ?? record.url.host ?? record.url.absoluteString,
                    subtitle: record.url.absoluteString,
                    navigationText: record.url.absoluteString,
                    kind: .history
                )
            )
            if suggestions.count == 7 { break }
        }

        return suggestions
    }

    private var shieldSymbolName: String {
        if controller.contentBlockingError != nil { return "exclamationmark.shield" }
        return controller.isContentBlockingEnabled ? "checkmark.shield.fill" : "shield.slash"
    }

    private var shieldColor: Color {
        if controller.contentBlockingError != nil { return .orange }
        return controller.isContentBlockingEnabled ? tint : OvertureDesign.secondaryText
    }

    private var shieldHelp: String {
        if let error = controller.contentBlockingError {
            return "Content blocking error: \(error)"
        }
        return controller.isContentBlockingEnabled
            ? "Content blocking is on for this tab"
            : "Content blocking is off for this tab"
    }

    private var shieldAccessibilityValue: String {
        if controller.contentBlockingError != nil { return "Error" }
        return controller.isContentBlockingEnabled ? "On" : "Off"
    }

    private var zoomPercentage: String {
        "\(Int((controller.zoomLevel * 100).rounded()))%"
    }

    private func synchronizeAddress(force: Bool) {
        guard force || !isAddressFocused else { return }
        addressText = controller.displayURL
    }

    private func submitAddress() {
        if isShowingSuggestions,
           let highlightedSuggestionID,
           let suggestion = omniboxSuggestions.first(where: { $0.id == highlightedSuggestionID }) {
            chooseSuggestion(suggestion)
            return
        }

        let submittedText = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedText.isEmpty else { return }
        onNavigate(submittedText)
        isShowingSuggestions = false
        highlightedSuggestionID = nil
        isAddressFocused = false
    }

    private func chooseSuggestion(_ suggestion: OmniboxSuggestion) {
        addressText = suggestion.navigationText
        onNavigate(suggestion.navigationText)
        isShowingSuggestions = false
        highlightedSuggestionID = nil
        isAddressFocused = false
    }

    private func updateSuggestions() {
        guard isAddressFocused else {
            isShowingSuggestions = false
            highlightedSuggestionID = nil
            return
        }

        isShowingSuggestions = !addressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let ids = omniboxSuggestions.map(\.id)
        if let highlightedSuggestionID, ids.contains(highlightedSuggestionID) {
            return
        }
        highlightedSuggestionID = ids.first
    }

    private func moveSuggestionSelection(_ direction: MoveCommandDirection) {
        guard isAddressFocused, isShowingSuggestions else { return }
        let suggestions = omniboxSuggestions
        guard !suggestions.isEmpty else { return }

        let currentIndex = highlightedSuggestionID.flatMap { currentID in
            suggestions.firstIndex { $0.id == currentID }
        } ?? 0

        switch direction {
        case .up:
            highlightedSuggestionID = suggestions[max(0, currentIndex - 1)].id
        case .down:
            highlightedSuggestionID = suggestions[min(suggestions.count - 1, currentIndex + 1)].id
        default:
            break
        }
    }

    private func suggestionScore(title: String, url: URL, query: String) -> Int {
        let normalizedTitle = title.searchNormalized
        let normalizedURL = url.absoluteString.searchNormalized
        if normalizedTitle == query || url.host?.searchNormalized == query { return 0 }
        if normalizedTitle.hasPrefix(query) { return 1 }
        if normalizedURL.hasPrefix(query) || url.host?.searchNormalized.hasPrefix(query) == true {
            return 2
        }
        if normalizedTitle.contains(query) { return 3 }
        return 4
    }
}

private struct SiteIdentityIndicator: View {
    let url: URL?
    let isStartPage: Bool

    private var identity: SiteIdentity {
        guard !isStartPage, let url else { return .startPage }
        switch url.scheme?.lowercased() {
        case "https": return .https
        case "http": return .http
        case "file": return .file
        case "data": return .data
        default: return .other
        }
    }

    var body: some View {
        Image(systemName: identity.symbolName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(identity.color)
            .frame(width: 14)
            .help(identity.help)
            .accessibilityLabel(identity.accessibilityLabel)
    }
}

private enum SiteIdentity {
    case startPage
    case https
    case http
    case file
    case data
    case other

    var symbolName: String {
        switch self {
        case .startPage: "magnifyingglass"
        case .https: "lock.fill"
        case .http: "exclamationmark.triangle.fill"
        case .file: "doc.fill"
        case .data: "curlybraces"
        case .other: "globe"
        }
    }

    var color: Color {
        switch self {
        case .https: .green
        case .http: .orange
        default: OvertureDesign.secondaryText
        }
    }

    var help: String {
        switch self {
        case .startPage: "Search or enter an address"
        case .https: "HTTPS connection"
        case .http: "Not secure — HTTP connection"
        case .file: "Local file"
        case .data: "Embedded data document"
        case .other: "Page identity information is unavailable"
        }
    }

    var accessibilityLabel: String { help }
}

private struct OmniboxSuggestion: Identifiable {
    enum Kind {
        case address
        case search
        case bookmark
        case history

        var symbolName: String {
            switch self {
            case .address: "globe"
            case .search: "magnifyingglass"
            case .bookmark: "star.fill"
            case .history: "clock.arrow.circlepath"
            }
        }

        var title: String {
            switch self {
            case .address: "Address"
            case .search: "Search"
            case .bookmark: "Bookmark"
            case .history: "History"
            }
        }
    }

    let id: String
    let title: String
    let subtitle: String
    let navigationText: String
    let kind: Kind
}

private extension BookmarkRecord {
    var searchText: String {
        [title, url.absoluteString, folderName ?? "", tags.joined(separator: " ")]
            .joined(separator: " ")
    }
}

private extension String {
    var searchNormalized: String {
        folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }

    var nonempty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
