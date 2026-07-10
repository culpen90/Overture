import SwiftUI

struct ProtonVPNCard: View {
    @ObservedObject var integration: ProtonVPNIntegration

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.40, green: 0.25, blue: 0.92), Color(red: 0.22, green: 0.71, blue: 0.60)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Proton VPN")
                        .font(.headline)
                    Text(integration.isInstalled ? "Installed on this Mac" : "Free plan available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(integration.actionTitle) {
                    integration.openOrOfferInstallation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }

            Text(integration.disclosure)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Button("Official download") { integration.openDownloadPage() }
                Button("Setup guide") { integration.openSetupGuide() }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        }
        .onAppear { integration.refreshInstallationState() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Proton VPN companion")
    }
}
