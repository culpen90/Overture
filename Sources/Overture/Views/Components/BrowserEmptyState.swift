import SwiftUI

struct BrowserEmptyState: View {
    let symbolName: String
    let title: String
    let message: String
    var actionTitle: String?
    var actionSystemImage: String?
    var accent: Color
    var onAction: (() -> Void)?

    init(
        symbolName: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        actionSystemImage: String? = nil,
        accent: Color = OvertureDesign.brand,
        onAction: (() -> Void)? = nil
    ) {
        self.symbolName = symbolName
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.actionSystemImage = actionSystemImage
        self.accent = accent
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: OvertureDesign.Spacing.standard) {
            Image(systemName: symbolName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 54, height: 54)
                .background(
                    accent.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(OvertureDesign.primaryText)

                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(OvertureDesign.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    if let actionSystemImage {
                        Label(actionTitle, systemImage: actionSystemImage)
                    } else {
                        Text(actionTitle)
                    }
                }
                .buttonStyle(OvertureSecondaryButtonStyle(tint: accent))
                .accessibilityHint("Performs the suggested action")
            }
        }
        .padding(OvertureDesign.Spacing.spacious)
        .frame(maxWidth: .infinity, minHeight: 180)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }
}
