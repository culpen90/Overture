import SwiftUI

struct PinboardView: View {
    let notes: [PinboardNoteRecord]
    let accent: BrowserAccent
    let onOpenURL: (URL) -> Void
    let onAdd: (PinboardNoteRecord) -> Void
    let onEdit: (PinboardNoteRecord) -> Void
    let onDelete: (PinboardNoteRecord) -> Void

    @State private var editor: PinboardEditorPresentation?

    init(
        notes: [PinboardNoteRecord],
        accent: BrowserAccent = .overture,
        onOpenURL: @escaping (URL) -> Void = { _ in },
        onAdd: @escaping (PinboardNoteRecord) -> Void,
        onEdit: @escaping (PinboardNoteRecord) -> Void,
        onDelete: @escaping (PinboardNoteRecord) -> Void
    ) {
        self.notes = notes
        self.accent = accent
        self.onOpenURL = onOpenURL
        self.onAdd = onAdd
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    private var tint: Color { OvertureDesign.accent(for: accent) }

    var body: some View {
        VStack(spacing: OvertureDesign.Spacing.comfortable) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pinboard")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Collect thoughts, links, and references in one place.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(OvertureDesign.secondaryText)
                }
                .accessibilityElement(children: .combine)

                Spacer()

                Button {
                    editor = PinboardEditorPresentation(
                        note: PinboardNoteRecord(body: "", colorHex: "#FFE08A"),
                        mode: .add
                    )
                } label: {
                    Label("New note", systemImage: "plus")
                }
                .buttonStyle(OverturePrimaryButtonStyle(tint: tint))
                .accessibilityHint("Opens a blank pinboard note")
            }

            if notes.isEmpty {
                BrowserEmptyState(
                    symbolName: "note.text.badge.plus",
                    title: "Your pinboard is ready",
                    message: "Save a thought or pair a note with a link you want to revisit.",
                    actionTitle: "Create a note",
                    actionSystemImage: "plus",
                    accent: tint
                ) {
                    editor = PinboardEditorPresentation(
                        note: PinboardNoteRecord(body: "", colorHex: "#FFE08A"),
                        mode: .add
                    )
                }
                .overturePanel(padding: 0)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 210, maximum: 320), spacing: 15)],
                        spacing: 15
                    ) {
                        ForEach(notes.sorted { $0.modifiedAt > $1.modifiedAt }) { note in
                            PinboardCard(
                                note: note,
                                onOpenURL: onOpenURL,
                                onEdit: {
                                    editor = PinboardEditorPresentation(note: note, mode: .edit)
                                },
                                onDelete: { onDelete(note) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .sheet(item: $editor) { presentation in
            PinboardNoteEditor(
                note: presentation.note,
                accent: tint,
                onCancel: { editor = nil },
                onSave: { savedNote in
                    switch presentation.mode {
                    case .add:
                        onAdd(savedNote)
                    case .edit:
                        onEdit(savedNote)
                    }
                    editor = nil
                }
            )
        }
    }
}

private struct PinboardCard: View {
    let note: PinboardNoteRecord
    let onOpenURL: (URL) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var noteColor: Color { pinboardColor(note.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(noteColor)
                    .accessibilityHidden(true)

                Text(note.title.isEmpty ? "Untitled note" : note.title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .lineLimit(2)

                Spacer(minLength: 4)

                Menu {
                    Button("Edit", systemImage: "pencil", action: onEdit)
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 22, height: 18)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Options for \(note.title.isEmpty ? "untitled note" : note.title)")
            }

            if !note.body.isEmpty {
                Text(note.body)
                    .font(.system(size: 12))
                    .foregroundStyle(OvertureDesign.primaryText.opacity(0.86))
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            if let url = note.linkedURL {
                Button {
                    onOpenURL(url)
                } label: {
                    Label(url.host ?? url.absoluteString, systemImage: "link")
                        .font(.system(size: 10.5, weight: .medium))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .foregroundStyle(noteColor)
                .accessibilityHint("Opens the linked page")
            }

            HStack {
                Text("Edited")
                Text(note.modifiedAt, style: .relative)
            }
            .font(.system(size: 9.5))
            .foregroundStyle(OvertureDesign.secondaryText)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 174, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [noteColor.opacity(0.18), noteColor.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(noteColor.opacity(0.3), lineWidth: 1)
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct PinboardNoteEditor: View {
    @State private var note: PinboardNoteRecord
    @State private var linkedURLText: String

    let accent: Color
    let onCancel: () -> Void
    let onSave: (PinboardNoteRecord) -> Void

    private let noteColors: [(name: String, hex: String)] = [
        ("Sunlight", "#FFE08A"),
        ("Rose", "#FF9AAA"),
        ("Lilac", "#BBA5FF"),
        ("Sky", "#8CCBFF"),
        ("Mint", "#8DE0C1")
    ]

    init(
        note: PinboardNoteRecord,
        accent: Color,
        onCancel: @escaping () -> Void,
        onSave: @escaping (PinboardNoteRecord) -> Void
    ) {
        _note = State(initialValue: note)
        _linkedURLText = State(initialValue: note.linkedURL?.absoluteString ?? "")
        self.accent = accent
        self.onCancel = onCancel
        self.onSave = onSave
    }

    private var canSave: Bool {
        !note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || URL(string: linkedURLText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty && note.body.isEmpty ? "New note" : "Edit note")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Changes are saved when you choose Save.")
                        .font(.system(size: 11))
                        .foregroundStyle(OvertureDesign.secondaryText)
                }

                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(OverturePrimaryButtonStyle(tint: accent))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .padding(20)

            Divider()

            Form {
                TextField("Title", text: $note.title)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Note")
                        .font(.caption)
                        .foregroundStyle(OvertureDesign.secondaryText)
                    TextEditor(text: $note.body)
                        .font(.system(size: 13))
                        .frame(minHeight: 130)
                        .padding(6)
                        .background(
                            OvertureDesign.elevatedPanel,
                            in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: OvertureDesign.Radius.control)
                                .stroke(OvertureDesign.separator, lineWidth: 1)
                        }
                }

                TextField("Linked URL (optional)", text: $linkedURLText)

                Picker("Note color", selection: $note.colorHex) {
                    ForEach(noteColors, id: \.hex) { color in
                        Label {
                            Text(color.name)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(pinboardColor(color.hex))
                        }
                        .tag(color.hex)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(width: 520, height: 470)
    }

    private func save() {
        let trimmedURL = linkedURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        note.linkedURL = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)
        note.modifiedAt = Date()
        onSave(note)
    }
}

private struct PinboardEditorPresentation: Identifiable {
    enum Mode {
        case add
        case edit
    }

    let id = UUID()
    let note: PinboardNoteRecord
    let mode: Mode
}

private func pinboardColor(_ hexValue: String) -> Color {
    let hex = hexValue.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard hex.count == 6, let rawValue = UInt64(hex, radix: 16) else {
        return Color(red: 1, green: 0.76, blue: 0.28)
    }

    return Color(
        red: Double((rawValue >> 16) & 0xFF) / 255,
        green: Double((rawValue >> 8) & 0xFF) / 255,
        blue: Double(rawValue & 0xFF) / 255
    )
}
