import SwiftUI

@MainActor
struct SpeedDialEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: SpeedDialRecord?
    let searchProvider: SearchProvider
    let onSave: (SpeedDialRecord) -> Void

    @State private var title: String
    @State private var address: String
    @State private var colorHex: String

    private let colors = ["#E82E4F", "#7C5CFC", "#2F7DEA", "#02A3A8", "#2DA862", "#F07524", "#3B3A50"]

    init(
        existing: SpeedDialRecord? = nil,
        searchProvider: SearchProvider,
        onSave: @escaping (SpeedDialRecord) -> Void
    ) {
        self.existing = existing
        self.searchProvider = searchProvider
        self.onSave = onSave
        _title = State(initialValue: existing?.title ?? "")
        _address = State(initialValue: existing?.url.absoluteString ?? "")
        _colorHex = State(initialValue: existing?.colorHex ?? "#7C5CFC")
    }

    private var resolvedURL: URL? {
        AddressResolver.resolve(address, searchProvider: searchProvider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                OvertureMark(size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Add to Speed Dial" : "Edit Speed Dial")
                        .font(.title2.bold())
                    Text("Keep a favorite site on your start page.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                TextField("Name", text: $title, prompt: Text("Website name"))
                TextField("Address", text: $address, prompt: Text("example.com"))

                LabeledContent("Tile color") {
                    HStack(spacing: 9) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                Circle()
                                    .fill(colorValue(color))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if colorHex == color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(color)
                            .accessibilityValue(colorHex == color ? "Selected" : "")
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Add" : "Save") { save() }
                    .buttonStyle(OverturePrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(resolvedURL == nil)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func save() {
        guard let url = resolvedURL else { return }
        var record = existing ?? SpeedDialRecord(title: title, url: url)
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? url.host ?? "Website"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.url = url
        record.colorHex = colorHex
        record.modifiedAt = Date()
        onSave(record)
        dismiss()
    }

    private func colorValue(_ hex: String) -> Color {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard let value = UInt64(cleaned, radix: 16) else { return .accentColor }
        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}

@MainActor
struct WorkspaceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: WorkspaceRecord?
    let onSave: (WorkspaceRecord) -> Void

    @State private var name: String
    @State private var symbolName: String
    @State private var colorHex: String

    private let symbols = ["house", "briefcase", "person.2", "graduationcap", "gamecontroller", "airplane", "heart", "star"]
    private let colors = ["#E82E4F", "#7C5CFC", "#2F7DEA", "#02A3A8", "#2DA862", "#F07524"]

    init(existing: WorkspaceRecord? = nil, onSave: @escaping (WorkspaceRecord) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _symbolName = State(initialValue: existing?.symbolName ?? "briefcase")
        _colorHex = State(initialValue: existing?.colorHex ?? "#7C5CFC")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(existing == nil ? "New Workspace" : "Edit Workspace")
                .font(.title2.bold())

            Form {
                TextField("Name", text: $name, prompt: Text("Workspace name"))

                LabeledContent("Icon") {
                    HStack(spacing: 8) {
                        ForEach(symbols, id: \.self) { symbol in
                            selectorButton(symbol: symbol)
                        }
                    }
                }

                LabeledContent("Color") {
                    HStack(spacing: 9) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                colorHex = color
                            } label: {
                                Circle()
                                    .fill(hexColor(color))
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        if colorHex == color {
                                            Circle().strokeBorder(.white, lineWidth: 2).padding(3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(existing == nil ? "Create" : "Save") { save() }
                    .buttonStyle(OverturePrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func selectorButton(symbol: String) -> some View {
        Button { symbolName = symbol } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
                .foregroundStyle(symbolName == symbol ? .white : .primary)
                .background(symbolName == symbol ? OvertureDesign.brand : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityValue(symbolName == symbol ? "Selected" : "")
    }

    private func save() {
        var workspace = existing ?? WorkspaceRecord(name: name)
        workspace.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        workspace.symbolName = symbolName
        workspace.colorHex = colorHex
        workspace.modifiedAt = Date()
        onSave(workspace)
        dismiss()
    }

    private func hexColor(_ hex: String) -> Color {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        let value = UInt64(cleaned, radix: 16) ?? 0x7C5CFC
        return Color(red: Double((value >> 16) & 0xff) / 255, green: Double((value >> 8) & 0xff) / 255, blue: Double(value & 0xff) / 255)
    }
}

@MainActor
struct BookmarkEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: BookmarkRecord?
    let suggestedURL: URL?
    let suggestedTitle: String
    let onSave: (BookmarkRecord) -> Void

    @State private var title: String
    @State private var address: String
    @State private var folder: String
    @State private var tags: String

    init(
        existing: BookmarkRecord? = nil,
        suggestedURL: URL? = nil,
        suggestedTitle: String = "",
        onSave: @escaping (BookmarkRecord) -> Void
    ) {
        self.existing = existing
        self.suggestedURL = suggestedURL
        self.suggestedTitle = suggestedTitle
        self.onSave = onSave
        _title = State(initialValue: existing?.title ?? suggestedTitle)
        _address = State(initialValue: existing?.url.absoluteString ?? suggestedURL?.absoluteString ?? "")
        _folder = State(initialValue: existing?.folderName ?? "")
        _tags = State(initialValue: existing?.tags.joined(separator: ", ") ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(existing == nil ? "Add Bookmark" : "Edit Bookmark")
                .font(.title2.bold())

            Form {
                TextField("Name", text: $title)
                TextField("Address", text: $address)
                TextField("Folder", text: $folder, prompt: Text("Optional"))
                TextField("Tags", text: $tags, prompt: Text("Comma separated"))
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .buttonStyle(OverturePrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(URL(string: address) == nil)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func save() {
        guard let url = URL(string: address) else { return }
        var bookmark = existing ?? BookmarkRecord(title: title, url: url)
        bookmark.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? url.host ?? "Bookmark" : title
        bookmark.url = url
        bookmark.folderName = folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : folder
        bookmark.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        bookmark.modifiedAt = Date()
        onSave(bookmark)
        dismiss()
    }
}
