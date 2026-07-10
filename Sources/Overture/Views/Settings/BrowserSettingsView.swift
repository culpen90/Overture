import AppKit
import SwiftUI

@MainActor
struct BrowserSettingsView: View {
    @ObservedObject var preferences: BrowserPreferences
    @StateObject private var protonVPNIntegration: ProtonVPNIntegration

    init(preferences: BrowserPreferences) {
        self.preferences = preferences
        _protonVPNIntegration = StateObject(wrappedValue: ProtonVPNIntegration())
    }

    init(preferences: BrowserPreferences, protonVPNIntegration: ProtonVPNIntegration) {
        self.preferences = preferences
        _protonVPNIntegration = StateObject(wrappedValue: protonVPNIntegration)
    }

    var body: some View {
        TabView {
            GeneralSettingsPane(preferences: preferences)
                .tabItem { Label("General", systemImage: "gearshape") }

            AppearanceSettingsPane(preferences: preferences)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }

            PrivacySettingsPane(
                preferences: preferences,
                protonVPNIntegration: protonVPNIntegration
            )
            .tabItem { Label("Privacy", systemImage: "hand.raised") }

            DownloadsSettingsPane(preferences: preferences)
                .tabItem { Label("Downloads", systemImage: "arrow.down.circle") }

            AboutSettingsPane(preferences: preferences)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(OvertureDesign.Spacing.comfortable)
        .frame(minWidth: 640, idealWidth: 680, minHeight: 470, idealHeight: 520)
        .tint(OvertureDesign.accent(for: preferences.accent))
        .preferredColorScheme(preferences.appearance.preferredColorScheme)
    }
}

@MainActor
private struct GeneralSettingsPane: View {
    @ObservedObject var preferences: BrowserPreferences

    var body: some View {
        Form {
            Section("Search") {
                Picker("Default search engine", selection: $preferences.searchProvider) {
                    ForEach(SearchProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
            }

            Section("Startup") {
                Toggle("Restore windows and tabs from the previous session", isOn: $preferences.restorePreviousSession)
                Toggle("Always use private browsing", isOn: $preferences.alwaysUsePrivateBrowsing)
            }

            Section("Browsing") {
                Toggle("Prefer secure HTTPS connections", isOn: $preferences.httpsFirst)
                Text("Overture still permits HTTP for local addresses and sites you enter explicitly.")
                    .font(.caption)
                    .foregroundStyle(OvertureDesign.secondaryText)
            }

            Section("Window") {
                Toggle("Show the sidebar", isOn: $preferences.sidebarVisible)
                Picker("Tab layout", selection: $preferences.tabLayout) {
                    ForEach(BrowserTabLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("Restore All Defaults") {
                    preferences.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings.general")
    }
}

@MainActor
private struct AppearanceSettingsPane: View {
    @ObservedObject var preferences: BrowserPreferences

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: $preferences.appearance) {
                    ForEach(BrowserAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Accent color", selection: $preferences.accent) {
                    ForEach(BrowserAccent.allCases) { accent in
                        Label {
                            Text(accent.title)
                        } icon: {
                            Circle()
                                .fill(OvertureDesign.accent(for: accent))
                                .frame(width: 10, height: 10)
                        }
                        .tag(accent)
                    }
                }
            }

            Section("Web Pages") {
                LabeledContent("Default page zoom") {
                    HStack(spacing: OvertureDesign.Spacing.standard) {
                        Slider(value: $preferences.pageZoom, in: 0.5...2, step: 0.05)
                            .frame(width: 220)
                        Text("\(Int((preferences.pageZoom * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                        Button("Reset") {
                            preferences.pageZoom = 1
                        }
                        .disabled(preferences.pageZoom == 1)
                    }
                }
                Text("Individual tabs can override this default from the View menu.")
                    .font(.caption)
                    .foregroundStyle(OvertureDesign.secondaryText)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings.appearance")
    }
}

@MainActor
private struct PrivacySettingsPane: View {
    @ObservedObject var preferences: BrowserPreferences
    @ObservedObject var protonVPNIntegration: ProtonVPNIntegration

    var body: some View {
        Form {
            Section("Protection") {
                Toggle("Block known trackers", isOn: $preferences.trackerBlockingEnabled)
                Toggle("Block intrusive ads", isOn: $preferences.adBlockingEnabled)
                Text("Blocking uses local WebKit content rules and does not send your browsing activity to Overture.")
                    .font(.caption)
                    .foregroundStyle(OvertureDesign.secondaryText)
            }

            Section("History") {
                Toggle("Save browsing history", isOn: $preferences.saveBrowsingHistory)
                Toggle("Clear browsing history when Overture quits", isOn: $preferences.clearHistoryOnQuit)
                    .disabled(!preferences.saveBrowsingHistory)
                Text("Private windows never write pages to browsing history or the restored session.")
                    .font(.caption)
                    .foregroundStyle(OvertureDesign.secondaryText)
            }

            Section("VPN Companion") {
                ProtonVPNCard(integration: protonVPNIntegration)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings.privacy")
    }
}

@MainActor
private struct DownloadsSettingsPane: View {
    @ObservedObject var preferences: BrowserPreferences

    var body: some View {
        Form {
            Section("Save Location") {
                LabeledContent("Download folder") {
                    HStack(spacing: OvertureDesign.Spacing.standard) {
                        Text(preferences.downloadLocation)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                            .frame(maxWidth: 280, alignment: .trailing)
                        Button("Choose…") { chooseDownloadFolder() }
                    }
                }

                Toggle("Ask where to save each file", isOn: $preferences.askWhereToSaveDownloads)
            }

            Section {
                Button("Open Downloads Folder") {
                    NSWorkspace.shared.open(preferences.downloadDirectoryURL)
                }
                .disabled(!FileManager.default.fileExists(atPath: preferences.downloadLocation))
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings.downloads")
    }

    private func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Download Folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = preferences.downloadDirectoryURL

        if panel.runModal() == .OK, let selectedURL = panel.url {
            preferences.downloadLocation = selectedURL.path
        }
    }
}

@MainActor
private struct AboutSettingsPane: View {
    @ObservedObject var preferences: BrowserPreferences

    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where version != build:
            return "Version \(version) (\(build))"
        case let (version?, _):
            return "Version \(version)"
        default:
            return "Development build"
        }
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: OvertureDesign.Spacing.comfortable) {
                    OvertureMark(
                        size: 68,
                        accent: OvertureDesign.accent(for: preferences.accent)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overture")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        Text(versionDescription)
                            .foregroundStyle(OvertureDesign.secondaryText)
                        Text("An open-source macOS browser built with SwiftUI and WebKit.")
                            .font(.callout)
                            .foregroundStyle(OvertureDesign.secondaryText)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Project") {
                LabeledContent("License", value: "MIT")
                Link("View Overture on GitHub", destination: URL(string: "https://github.com/culpen90/Overture")!)
                Text("Overture is an independent project and is not affiliated with Opera Software.")
                    .font(.caption)
                    .foregroundStyle(OvertureDesign.secondaryText)
            }
        }
        .formStyle(.grouped)
        .accessibilityIdentifier("settings.about")
    }
}
