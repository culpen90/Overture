import SwiftUI

struct StartPageView: View {
    let speedDials: [SpeedDialRecord]
    let recentHistory: [HistoryRecord]
    let searchProvider: SearchProvider
    let accent: BrowserAccent
    let onNavigate: (URL) -> Void
    let onAddSpeedDial: () -> Void
    let onEditSpeedDial: (SpeedDialRecord) -> Void
    let onDeleteSpeedDial: (SpeedDialRecord) -> Void

    @State private var query = ""
    @FocusState private var isSearchFocused: Bool

    private var tint: Color { OvertureDesign.accent(for: accent) }
    private var recentItems: [HistoryRecord] {
        Array(recentHistory.sorted { $0.lastVisitedAt > $1.lastVisitedAt }.prefix(8))
    }

    var body: some View {
        ZStack {
            OvertureDesign.canvas

            LinearGradient(
                colors: [tint.opacity(0.11), .clear, tint.opacity(0.035)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    hero
                    speedDialSection
                    recentSection
                }
                .frame(maxWidth: 1_080)
                .padding(.horizontal, 42)
                .padding(.top, 42)
                .padding(.bottom, 56)
                .frame(maxWidth: .infinity)
            }
        }
        .tint(tint)
    }

    private var hero: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                OvertureMark(size: 50, accent: tint)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Overture")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Your web, in motion.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(OvertureDesign.secondaryText)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSearchFocused ? tint : OvertureDesign.secondaryText)
                    .accessibilityHidden(true)

                TextField("Search or enter an address", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onSubmit(submitQuery)
                    .accessibilityLabel("Search or address")
                    .accessibilityHint("Searches with \(searchProvider.title), or opens a web address")

                Text(searchProvider.title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.09), in: Capsule())
                    .accessibilityLabel("Search provider: \(searchProvider.title)")

                Button(action: submitQuery) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
                .accessibilityLabel("Go")
            }
            .padding(.leading, 17)
            .padding(.trailing, 9)
            .padding(.vertical, 9)
            .background(
                OvertureDesign.elevatedPanel,
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(isSearchFocused ? tint.opacity(0.72) : OvertureDesign.separator, lineWidth: isSearchFocused ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.09), radius: 18, y: 8)
            .frame(maxWidth: 720)
        }
        .padding(.bottom, 4)
    }

    private var speedDialSection: some View {
        VStack(alignment: .leading, spacing: OvertureDesign.Spacing.comfortable) {
            sectionHeader(
                title: "Speed Dial",
                subtitle: "Your favorite places, one click away"
            ) {
                Button(action: onAddSpeedDial) {
                    Label("Add site", systemImage: "plus")
                }
                .buttonStyle(OvertureSecondaryButtonStyle(tint: tint))
                .accessibilityHint("Adds a site to Speed Dial")
            }

            if speedDials.isEmpty {
                BrowserEmptyState(
                    symbolName: "square.grid.2x2",
                    title: "Make this page yours",
                    message: "Add the sites you reach for most. They will stay here for quick access.",
                    actionTitle: "Add your first site",
                    actionSystemImage: "plus",
                    accent: tint,
                    onAction: onAddSpeedDial
                )
                .overturePanel(padding: 0)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 148, maximum: 210), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(speedDials.sorted { $0.sortIndex < $1.sortIndex }) { speedDial in
                        SpeedDialTile(
                            speedDial: speedDial,
                            accent: tint,
                            onOpen: { onNavigate(speedDial.url) },
                            onEdit: { onEditSpeedDial(speedDial) },
                            onDelete: { onDeleteSpeedDial(speedDial) }
                        )
                    }
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: OvertureDesign.Spacing.comfortable) {
            sectionHeader(
                title: "Recently visited",
                subtitle: "Pick up where you left off"
            ) { EmptyView() }

            if recentItems.isEmpty {
                BrowserEmptyState(
                    symbolName: "clock.arrow.circlepath",
                    title: "No recent pages yet",
                    message: "Pages you visit will appear here, unless browsing history is disabled.",
                    accent: tint
                )
                .overturePanel(padding: 0)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                        RecentHistoryRow(item: item, accent: tint) {
                            onNavigate(item.url)
                        }

                        if index < recentItems.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .overturePanel(padding: 6)
            }
        }
    }

    private func sectionHeader<Trailing: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(OvertureDesign.secondaryText)
            }
            .accessibilityElement(children: .combine)

            Spacer()
            trailing()
        }
    }

    private func submitQuery() {
        guard let url = AddressResolver.resolve(query, searchProvider: searchProvider) else { return }
        onNavigate(url)
    }
}

private struct SpeedDialTile: View {
    let speedDial: SpeedDialRecord
    let accent: Color
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var tileColor: Color {
        Color(overtureHex: speedDial.colorHex) ?? accent
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 13) {
                    Group {
                        if let thumbnailURL = speedDial.thumbnailURL {
                            AsyncImage(url: thumbnailURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    monogram
                                }
                            }
                        } else {
                            monogram
                        }
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(speedDial.title.isEmpty ? speedDial.url.host ?? "Website" : speedDial.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(OvertureDesign.primaryText)
                            .lineLimit(1)

                        Text(speedDial.url.host ?? speedDial.url.absoluteString)
                            .font(.system(size: 10.5))
                            .foregroundStyle(OvertureDesign.secondaryText)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                OvertureDesign.panel,
                in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.panel, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OvertureDesign.Radius.panel, style: .continuous)
                    .stroke(OvertureDesign.separator.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.045), radius: 7, y: 3)
            .contextMenu {
                Button("Open", systemImage: "arrow.up.right.square", action: onOpen)
                Button("Edit", systemImage: "pencil", action: onEdit)
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            }
            .accessibilityLabel(speedDial.title.isEmpty ? speedDial.url.absoluteString : speedDial.title)
            .accessibilityHint("Opens \(speedDial.url.host ?? speedDial.url.absoluteString)")

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 24)
                    .background(.regularMaterial, in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(8)
            .accessibilityLabel("Options for \(speedDial.title)")
        }
    }

    private var monogram: some View {
        ZStack {
            LinearGradient(
                colors: [tileColor, tileColor.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String((speedDial.title.isEmpty ? speedDial.url.host ?? "W" : speedDial.title).prefix(1)).uppercased())
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct RecentHistoryRow: View {
    let item: HistoryRecord
    let accent: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.isEmpty ? item.url.host ?? "Untitled page" : item.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(OvertureDesign.primaryText)
                        .lineLimit(1)
                    Text(item.url.host ?? item.url.absoluteString)
                        .font(.system(size: 10.5))
                        .foregroundStyle(OvertureDesign.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text(item.lastVisitedAt, style: .relative)
                    .font(.system(size: 10.5))
                    .foregroundStyle(OvertureDesign.secondaryText)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(OvertureDesign.secondaryText)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(item.url.host ?? item.url.absoluteString)")
        .accessibilityValue("Visited \(item.lastVisitedAt.formatted(.relative(presentation: .named)))")
        .accessibilityHint("Opens this page")
    }
}

private extension Color {
    init?(overtureHex value: String) {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6, let rawValue = UInt64(hex, radix: 16) else { return nil }

        self.init(
            red: Double((rawValue >> 16) & 0xFF) / 255,
            green: Double((rawValue >> 8) & 0xFF) / 255,
            blue: Double(rawValue & 0xFF) / 255
        )
    }
}
