import SwiftUI

@MainActor
struct FindBar: View {
    @ObservedObject var controller: BrowserTabController
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var resultText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Find on page", text: $query)
                .textFieldStyle(.plain)
                .frame(width: 220)
                .focused($isFocused)
                .onSubmit { search(backwards: false) }
                .onChange(of: query) { _, _ in search(backwards: false) }

            Text(resultText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)

            Button { search(backwards: true) } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match")
            .disabled(query.isEmpty)

            Button { search(backwards: false) } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match")
            .disabled(query.isEmpty)

            Button { isPresented = false } label: {
                Image(systemName: "xmark")
            }
            .help("Close Find")
            .keyboardShortcut(.cancelAction)
        }
        .buttonStyle(OvertureToolbarButtonStyle())
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(OvertureDesign.separator)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .onAppear { isFocused = true }
        .accessibilityElement(children: .contain)
    }

    private func search(backwards: Bool) {
        guard !query.isEmpty else {
            resultText = ""
            return
        }

        Task {
            do {
                resultText = try await controller.find(query, backwards: backwards) ? "Match" : "No match"
            } catch {
                resultText = "Unavailable"
            }
        }
    }
}

@MainActor
struct PageErrorView: View {
    let error: BrowserTabController.NavigationError
    let onRetry: () -> Void
    let onStartPage: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(OvertureDesign.brand)

            VStack(spacing: 6) {
                Text("This page couldn’t be opened")
                    .font(.title2.bold())
                Text(error.message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                if let failingURL = error.failingURL {
                    Text(failingURL.absoluteString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 10) {
                Button("Start Page", action: onStartPage)
                    .buttonStyle(OvertureSecondaryButtonStyle())
                Button("Try Again", action: onRetry)
                    .buttonStyle(OverturePrimaryButtonStyle())
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OvertureDesign.canvas)
        .accessibilityElement(children: .contain)
    }
}
