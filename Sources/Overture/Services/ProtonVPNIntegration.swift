import AppKit
import Foundation

/// A transparent hand-off to Proton VPN's separately installed macOS app.
/// Overture never claims to create, inspect, or control the VPN tunnel itself.
@MainActor
final class ProtonVPNIntegration: ObservableObject {
    static let freePlanURL = URL(string: "https://protonvpn.com/free-vpn/macos")!
    static let downloadURL = URL(string: "https://protonvpn.com/download-macos")!
    static let supportURL = URL(string: "https://protonvpn.com/support/protonvpn-mac-vpn-application")!

    private static let knownBundleIdentifiers = [
        "ch.protonvpn.mac"
    ]

    private static let commonApplicationURLs = [
        URL(fileURLWithPath: "/Applications/Proton VPN.app"),
        URL(fileURLWithPath: "/Applications/ProtonVPN.app")
    ]

    @Published private(set) var applicationURL: URL?

    var isInstalled: Bool { applicationURL != nil }

    var actionTitle: String {
        isInstalled ? "Open Proton VPN" : "Get Proton VPN Free"
    }

    let disclosure = "VPN protection is provided by the separate Proton VPN app. Overture cannot see your Proton account, VPN traffic, or connection status."

    init() {
        refreshInstallationState()
    }

    func refreshInstallationState() {
        applicationURL = Self.knownBundleIdentifiers
            .compactMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
            .first

        if applicationURL == nil {
            applicationURL = Self.commonApplicationURLs.first {
                FileManager.default.fileExists(atPath: $0.path)
            }
        }
    }

    func openOrOfferInstallation() {
        refreshInstallationState()

        if let applicationURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration)
            return
        }

        NSWorkspace.shared.open(Self.freePlanURL)
    }

    func openDownloadPage() {
        NSWorkspace.shared.open(Self.downloadURL)
    }

    func openSetupGuide() {
        NSWorkspace.shared.open(Self.supportURL)
    }
}
