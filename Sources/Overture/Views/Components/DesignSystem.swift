import SwiftUI

enum OvertureDesign {
    static let brand = Color(red: 0.91, green: 0.18, blue: 0.31)
    static let brandHighlight = Color(red: 1, green: 0.42, blue: 0.31)

    static var canvas: Color { Color(nsColor: .windowBackgroundColor) }
    static var sidebar: Color { Color(nsColor: .underPageBackgroundColor) }
    static var panel: Color { Color(nsColor: .controlBackgroundColor) }
    static var elevatedPanel: Color { Color(nsColor: .textBackgroundColor) }
    static var separator: Color { Color(nsColor: .separatorColor) }
    static var primaryText: Color { Color(nsColor: .labelColor) }
    static var secondaryText: Color { Color(nsColor: .secondaryLabelColor) }

    static func accent(for accent: BrowserAccent) -> Color {
        switch accent {
        case .overture: brand
        case .violet: Color(red: 0.55, green: 0.32, blue: 0.94)
        case .blue: Color(red: 0.18, green: 0.48, blue: 0.94)
        case .teal: Color(red: 0.02, green: 0.64, blue: 0.66)
        case .green: Color(red: 0.18, green: 0.66, blue: 0.38)
        case .orange: Color(red: 0.96, green: 0.46, blue: 0.14)
        }
    }

    enum Spacing {
        static let compact: CGFloat = 6
        static let standard: CGFloat = 10
        static let comfortable: CGFloat = 16
        static let spacious: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 8
        static let panel: CGFloat = 14
    }
}

extension BrowserAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Overture's original mark: a rounded stage containing an opening musical gesture.
struct OvertureMark: View {
    var size: CGFloat = 32
    var accent: Color = OvertureDesign.brand

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.72), OvertureDesign.brandHighlight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: side * 0.3, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: max(1, side * 0.025))

                Path { path in
                    path.move(to: CGPoint(x: side * 0.2, y: side * 0.58))
                    path.addCurve(
                        to: CGPoint(x: side * 0.47, y: side * 0.39),
                        control1: CGPoint(x: side * 0.3, y: side * 0.58),
                        control2: CGPoint(x: side * 0.32, y: side * 0.39)
                    )
                    path.addCurve(
                        to: CGPoint(x: side * 0.8, y: side * 0.5),
                        control1: CGPoint(x: side * 0.62, y: side * 0.39),
                        control2: CGPoint(x: side * 0.68, y: side * 0.5)
                    )
                }
                .stroke(
                    .white,
                    style: StrokeStyle(lineWidth: max(2, side * 0.1), lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Overture")
    }
}

private struct OverturePanelModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(OvertureDesign.panel, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(OvertureDesign.separator.opacity(0.65), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

extension View {
    func overturePanel(
        padding: CGFloat = OvertureDesign.Spacing.comfortable,
        cornerRadius: CGFloat = OvertureDesign.Radius.panel
    ) -> some View {
        modifier(OverturePanelModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

struct OverturePrimaryButtonStyle: ButtonStyle {
    var tint: Color = OvertureDesign.brand
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                tint.opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.42),
                in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct OvertureSecondaryButtonStyle: ButtonStyle {
    var tint: Color = OvertureDesign.brand
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isEnabled ? tint : OvertureDesign.secondaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                tint.opacity(configuration.isPressed ? 0.16 : 0.08),
                in: RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OvertureDesign.Radius.control, style: .continuous)
                    .stroke(tint.opacity(isEnabled ? 0.28 : 0.12), lineWidth: 1)
            }
    }
}

struct OvertureToolbarButtonStyle: ButtonStyle {
    var tint: Color = OvertureDesign.brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .foregroundStyle(configuration.isPressed ? tint : OvertureDesign.primaryText)
            .background(
                tint.opacity(configuration.isPressed ? 0.14 : 0),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}
