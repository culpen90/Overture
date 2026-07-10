import SwiftUI

enum BrowserLibrarySection: String, CaseIterable, Identifiable {
    case bookmarks
    case history
    case downloads
    case pinboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookmarks: "Bookmarks"
        case .history: "History"
        case .downloads: "Downloads"
        case .pinboard: "Pinboard"
        }
    }

    var symbolName: String {
        switch self {
        case .bookmarks: "star"
        case .history: "clock.arrow.circlepath"
        case .downloads: "arrow.down.circle"
        case .pinboard: "note.text"
        }
    }
}

struct BrowserLibraryView: View {
    let bookmarks: [BookmarkRecord]
    let history: [HistoryRecord]
    let downloads: [DownloadRecord]
    let pinboardNotes: [PinboardNoteRecord]
    let accent: BrowserAccent
    let onOpenURL: (URL) -> Void
    let onDeleteBookmark: (BookmarkRecord) -> Void
    let onDeleteHistory: (HistoryRecord) -> Void
    let onClearHistory: () -> Void
    let onDeleteDownload: (DownloadRecord) -> Void
    let onRevealDownload: (DownloadRecord) -> Void
    let onRetryDownload: (DownloadRecord) -> Void
    let onSaveNote: (PinboardNoteRecord) -> Void
    let onDeleteNote: (PinboardNoteRecord) -> Void
    let onClose: () -> Void

    @State private var selectedSection: BrowserLibrarySection
    @State private var searchText = ""
    @State private var downloadFilter: DownloadFilter = .all
    @State private var isConfirmingHistoryClear = false
    @FocusState private var isSearchFocused: Bool

    init(
        initialSection: BrowserLibrarySection = .bookmarks,
        bookmarks: [BookmarkRecord],
        history: [HistoryRecord],
        downloads: [DownloadRecord],
        pinboardNotes: [PinboardNoteRecord],
        accent: BrowserAccent = .overture,
        onOpenURL: @escaping (URL) -> Void,
        onDeleteBookmark: @escaping (BookmarkRecord) -> Void,
        onDeleteHistory: @escaping (HistoryRecord) -> Void,
        onClearHistory: @escaping () -> Void,
        onDeleteDownload: @escaping (DownloadRecord) -> Void,
        onRevealDownload: @escaping (DownloadRecord) -> Void,
        onRetryDownload: @escaping (DownloadRecord) -> Void,
        onSaveNote: @escaping (PinboardNoteRecord) -> Void,
        onDeleteNote: @escaping (PinboardNoteRecord) -> Void,
        onClose: @escaping () -> Void
    ) {
        _selectedSection = State(initialValue: initialSection)
        self.bookmarks = bookmarks
        self.history = history
        self.downloads = downloads
        self.pinboardNotes = pinboardNotes
        self.accent = accent
        self.onOpenURL = onOpenURL
        self.onDeleteBookmark = onDeleteBookmark
        self.onDeleteHistory = onDeleteHistory
        self.onClearHistory = onClearHistory
        self.onDeleteDownload = onDeleteDownload
        self.onRevealDownload = onRevealDownload
        self.onRetryDownload = onRetryDownload
        self.onSaveNote = onSaveNote
        self.onDeleteNote = onDeleteNote
        self.onClose = onClose
    }

    private var tint: Color { OvertureDesign.accent(for: accent) }
    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            HStack(spacing: 0) {
                librarySidebar
                Divider()
                selectedContent
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(OvertureDesign.canvas)
        .tint(tint)
        .confirmationDialog(
            "Clear all browsing history?",
            isPresented: $isConfirmingHistoryClear
        ) {
            Button("Clear History", role: .destructive, action: onClearHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all saved history records. Open tabs and bookmarks are not affected.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            OvertureMark(size: 30, accent: tint)
            Text("Library")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            Spacer(minLength: 24)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSearchFocused ? tint : OvertureDesign.secondaryText)
                    .accessibilityHidden(true)

                TextField("Search \(selectedSection.title.lowercased())", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .accessibilityLabel("Search \(selectedSection.title)")

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(OvertureDesign.secondaryText)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 260, height: 30)
            .background(
                OvertureDesign.elevatedPanel,
                in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
                    .stroke(isSearchFocused ? tint.opacity(0.65) : OvertureDesign.separator, lineWidth: 1)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(OvertureToolbarButtonStyle(tint: tint))
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Close Library")
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(OvertureDesign.panel)
    }

    private var librarySidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(BrowserLibrarySection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18)
                        Text(section.title)
                            .font(.system(size: 12.5, weight: .medium))
                        Spacer()
                        Text("\(itemCount(for: section))")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedSection == section ? tint : OvertureDesign.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (selectedSection == section ? tint : OvertureDesign.secondaryText).opacity(0.09),
                                in: Capsule()
                            )
                    }
                    .foregroundStyle(selectedSection == section ? tint : OvertureDesign.primaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .contentShape(Rectangle())
                    .background(
                        selectedSection == section ? tint.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(section.title), \(itemCount(for: section)) items")
                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
            }

            Spacer()

            Text("Saved on this Mac")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(OvertureDesign.secondaryText)
                .padding(.horizontal, 10)
        }
        .padding(10)
        .frame(width: 184)
        .background(OvertureDesign.librarySidebar)
    }

    @ViewBuilder
    private var selectedContent: some View {
        if selectedSection == .pinboard {
            PinboardView(
                notes: filteredNotes,
                accent: accent,
                onOpenURL: onOpenURL,
                onAdd: onSaveNote,
                onEdit: onSaveNote,
                onDelete: onDeleteNote
            )
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                sectionToolbar
                Divider()

                Group {
                    switch selectedSection {
                    case .bookmarks:
                        bookmarksContent
                    case .history:
                        historyContent
                    case .downloads:
                        downloadsContent
                    case .pinboard:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var sectionToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedSection.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(sectionSummary)
                    .font(.system(size: 11))
                    .foregroundStyle(OvertureDesign.secondaryText)
            }

            Spacer()

            if selectedSection == .downloads {
                Picker("Download filter", selection: $downloadFilter) {
                    ForEach(DownloadFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 132)
            }

            if selectedSection == .history, !history.isEmpty {
                Button(role: .destructive) {
                    isConfirmingHistoryClear = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(OvertureSecondaryButtonStyle(tint: .red))
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 70)
        .background(OvertureDesign.canvas)
    }

    @ViewBuilder
    private var bookmarksContent: some View {
        if filteredBookmarks.isEmpty {
            emptyState(
                symbol: normalizedSearch.isEmpty ? "star" : "magnifyingglass",
                title: normalizedSearch.isEmpty ? "No bookmarks yet" : "No bookmark matches",
                message: normalizedSearch.isEmpty
                    ? "Bookmark a page to keep it within easy reach."
                    : "Try a different title, address, folder, or tag."
            )
        } else {
            recordScrollView {
                ForEach(filteredBookmarks.sorted { $0.modifiedAt > $1.modifiedAt }) { bookmark in
                    BookmarkLibraryRow(
                        bookmark: bookmark,
                        accent: tint,
                        onOpen: { onOpenURL(bookmark.url) },
                        onDelete: { onDeleteBookmark(bookmark) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        if filteredHistory.isEmpty {
            emptyState(
                symbol: normalizedSearch.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass",
                title: normalizedSearch.isEmpty ? "No browsing history" : "No history matches",
                message: normalizedSearch.isEmpty
                    ? "Pages you visit will appear here when history is enabled."
                    : "Try searching for another page title or address."
            )
        } else {
            recordScrollView {
                ForEach(filteredHistory.sorted { $0.lastVisitedAt > $1.lastVisitedAt }) { item in
                    HistoryLibraryRow(
                        item: item,
                        accent: tint,
                        onOpen: { onOpenURL(item.url) },
                        onDelete: { onDeleteHistory(item) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var downloadsContent: some View {
        if filteredDownloads.isEmpty {
            emptyState(
                symbol: normalizedSearch.isEmpty && downloadFilter == .all
                    ? "arrow.down.circle"
                    : "line.3.horizontal.decrease.circle",
                title: normalizedSearch.isEmpty && downloadFilter == .all
                    ? "No downloads yet"
                    : "No downloads match",
                message: normalizedSearch.isEmpty && downloadFilter == .all
                    ? "Files you download will appear here with their progress and status."
                    : "Change the search or status filter to see more results."
            )
        } else {
            recordScrollView {
                ForEach(filteredDownloads.sorted { $0.updatedAt > $1.updatedAt }) { download in
                    DownloadLibraryRow(
                        download: download,
                        accent: tint,
                        onOpenSource: { onOpenURL(download.sourceURL) },
                        onReveal: { onRevealDownload(download) },
                        onRetry: { onRetryDownload(download) },
                        onDelete: { onDeleteDownload(download) }
                    )
                }
            }
        }
    }

    private func recordScrollView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                content()
            }
            .padding(18)
        }
    }

    private func emptyState(symbol: String, title: String, message: String) -> some View {
        BrowserEmptyState(
            symbolName: symbol,
            title: title,
            message: message,
            actionTitle: normalizedSearch.isEmpty ? nil : "Clear search",
            actionSystemImage: normalizedSearch.isEmpty ? nil : "xmark",
            accent: tint,
            onAction: normalizedSearch.isEmpty ? nil : { searchText = "" }
        )
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filteredBookmarks: [BookmarkRecord] {
        guard !normalizedSearch.isEmpty else { return bookmarks }
        return bookmarks.filter { bookmark in
            searchable([
                bookmark.title,
                bookmark.url.absoluteString,
                bookmark.folderName ?? "",
                bookmark.tags.joined(separator: " ")
            ])
        }
    }

    private var filteredHistory: [HistoryRecord] {
        guard !normalizedSearch.isEmpty else { return history }
        return history.filter { searchable([$0.title, $0.url.absoluteString]) }
    }

    private var filteredDownloads: [DownloadRecord] {
        downloads.filter { download in
            downloadFilter.includes(download.state)
                && (normalizedSearch.isEmpty || searchable([
                    download.suggestedFilename,
                    download.sourceURL.absoluteString,
                    download.state.rawValue
                ]))
        }
    }

    private var filteredNotes: [PinboardNoteRecord] {
        guard !normalizedSearch.isEmpty else { return pinboardNotes }
        return pinboardNotes.filter {
            searchable([$0.title, $0.body, $0.linkedURL?.absoluteString ?? ""])
        }
    }

    private func searchable(_ values: [String]) -> Bool {
        values.contains { $0.localizedCaseInsensitiveContains(normalizedSearch) }
    }

    private func itemCount(for section: BrowserLibrarySection) -> Int {
        switch section {
        case .bookmarks: bookmarks.count
        case .history: history.count
        case .downloads: downloads.count
        case .pinboard: pinboardNotes.count
        }
    }

    private var sectionSummary: String {
        let count: Int
        switch selectedSection {
        case .bookmarks: count = filteredBookmarks.count
        case .history: count = filteredHistory.count
        case .downloads: count = filteredDownloads.count
        case .pinboard: count = filteredNotes.count
        }
        return "\(count) \(count == 1 ? "item" : "items")"
    }
}

private struct BookmarkLibraryRow: View {
    let bookmark: BookmarkRecord
    let accent: Color
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LibraryRecordRow(
            symbol: "star.fill",
            symbolColor: accent,
            title: bookmark.title.isEmpty ? bookmark.url.host ?? "Untitled bookmark" : bookmark.title,
            subtitle: bookmark.url.host ?? bookmark.url.absoluteString,
            detail: bookmark.folderName,
            onOpen: onOpen,
            onDelete: onDelete
        )
    }
}

private struct HistoryLibraryRow: View {
    let item: HistoryRecord
    let accent: Color
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        LibraryRecordRow(
            symbol: "clock",
            symbolColor: accent,
            title: item.title.isEmpty ? item.url.host ?? "Untitled page" : item.title,
            subtitle: item.url.host ?? item.url.absoluteString,
            detail: item.visitCount == 1 ? "1 visit" : "\(item.visitCount) visits",
            trailingDate: item.lastVisitedAt,
            onOpen: onOpen,
            onDelete: onDelete
        )
    }
}

private struct LibraryRecordRow: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    var detail: String?
    var trailingDate: Date?
    let onOpen: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(symbolColor)
                        .frame(width: 34, height: 34)
                        .background(symbolColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(OvertureDesign.primaryText)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 10.5))
                            .foregroundStyle(OvertureDesign.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(OvertureDesign.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(OvertureDesign.secondaryText.opacity(0.07), in: Capsule())
                    }

                    if let trailingDate {
                        Text(trailingDate, style: .relative)
                            .font(.system(size: 9.5))
                            .foregroundStyle(OvertureDesign.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(subtitle)")
            .accessibilityHint("Opens this page")

            Menu {
                Button("Open", systemImage: "arrow.up.right.square", action: onOpen)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Options for \(title)")
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(
            OvertureDesign.panel,
            in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
                .stroke(OvertureDesign.separator.opacity(0.6), lineWidth: 1)
        }
        .contextMenu {
            Button("Open", systemImage: "arrow.up.right.square", action: onOpen)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

private struct DownloadLibraryRow: View {
    let download: DownloadRecord
    let accent: Color
    let onOpenSource: () -> Void
    let onReveal: () -> Void
    let onRetry: () -> Void
    let onDelete: () -> Void

    private var stateColor: Color {
        switch download.state {
        case .queued: OvertureDesign.secondaryText
        case .downloading: accent
        case .paused: .orange
        case .completed: .green
        case .failed: .red
        case .cancelled: OvertureDesign.secondaryText
        }
    }

    private var stateSymbol: String {
        switch download.state {
        case .queued: "clock"
        case .downloading: "arrow.down"
        case .paused: "pause.fill"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        case .cancelled: "xmark"
        }
    }

    private var statusTitle: String {
        switch download.state {
        case .queued: "Queued"
        case .downloading: "Downloading"
        case .paused: "Paused"
        case .completed: "Complete"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: stateSymbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(stateColor)
                .frame(width: 36, height: 36)
                .background(stateColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Button(action: onOpenSource) {
                    Text(download.suggestedFilename)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(OvertureDesign.primaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the download source")

                if download.state == .downloading {
                    if download.totalBytesExpected == nil {
                        ProgressView().controlSize(.small)
                    } else {
                        ProgressView(value: download.normalizedProgress)
                            .tint(accent)
                    }
                }

                HStack(spacing: 5) {
                    Text(statusTitle)
                        .foregroundStyle(stateColor)

                    if download.bytesReceived > 0 {
                        Text("•")
                        Text(byteDescription)
                    }

                    if let errorDescription = download.errorDescription,
                       download.state == .failed {
                        Text("•")
                        Text(errorDescription).lineLimit(1)
                    }
                }
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(OvertureDesign.secondaryText)
            }

            Spacer(minLength: 8)

            switch download.state {
            case .completed where download.destinationURL != nil:
                Button("Reveal", action: onReveal)
                    .buttonStyle(OvertureSecondaryButtonStyle(tint: accent))
            case .failed, .cancelled, .paused:
                Button("Retry", action: onRetry)
                    .buttonStyle(OvertureSecondaryButtonStyle(tint: accent))
            default:
                EmptyView()
            }

            Menu {
                Button("Open Source", systemImage: "safari", action: onOpenSource)
                if download.state == .completed, download.destinationURL != nil {
                    Button("Reveal in Finder", systemImage: "folder", action: onReveal)
                }
                if [.failed, .cancelled, .paused].contains(download.state) {
                    Button("Retry", systemImage: "arrow.clockwise", action: onRetry)
                }
                Divider()
                Button("Remove", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 26, height: 24)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Options for \(download.suggestedFilename)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(minHeight: 62)
        .background(
            OvertureDesign.panel,
            in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
                .stroke(OvertureDesign.separator.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(download.suggestedFilename), \(statusTitle)")
    }

    private var byteDescription: String {
        let received = ByteCountFormatter.string(fromByteCount: download.bytesReceived, countStyle: .file)
        guard let expected = download.totalBytesExpected, expected > 0 else { return received }
        return "\(received) of \(ByteCountFormatter.string(fromByteCount: expected, countStyle: .file))"
    }
}

private enum DownloadFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed
    case needsAttention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .active: "Active"
        case .completed: "Completed"
        case .needsAttention: "Needs attention"
        }
    }

    func includes(_ state: DownloadState) -> Bool {
        switch self {
        case .all:
            true
        case .active:
            [.queued, .downloading, .paused].contains(state)
        case .completed:
            state == .completed
        case .needsAttention:
            [.failed, .cancelled].contains(state)
        }
    }
}
