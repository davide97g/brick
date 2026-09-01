import SwiftUI

/// The app is an instrument panel for a physical object, not a dashboard.
///
/// Two zones: a near-black machined surface where the state lives, and a warm
/// paper card where the controls live. Monochrome throughout, with exactly one
/// chromatic value — `oxide` — reserved for the emergency unlock. Colour
/// appears only where the commitment breaks.
enum Theme {
    /// Not pure black: OLED smears on true #000 during scroll.
    static let ink = Color(hex: 0x0B0B0D)
    static let inkRaised = Color(hex: 0x141416)
    static let paper = Color(hex: 0xEDE7DC)
    static let paperEdge = Color(hex: 0xDCD4C6)

    /// Primary text on ink. ~18:1.
    static let chalk = Color(hex: 0xF2F2F0)
    /// Secondary text on ink. ~7:1 — safe for body, not just large text.
    static let ash = Color(hex: 0x9C9CA1)
    /// Unelapsed ticks, hairlines, disabled marks. Decorative only.
    static let graphite = Color(hex: 0x3A3A3E)

    /// Ink-side text on the paper card.
    static let inkOnPaper = Color(hex: 0x17171A)
    static let ashOnPaper = Color(hex: 0x6B675F)

    /// The only chroma in the app.
    static let oxide = Color(hex: 0xB4614F)

    static let cardRadius: CGFloat = 30
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Type

extension View {
    /// Engraved hardware label: small, wide-tracked, upper case.
    func engraved(_ color: Color = Theme.ash) -> some View {
        self
            .font(.system(size: 11, weight: .medium))
            .tracking(2.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Instrument readout: thin, large, tabular so digits don't jitter.
    func readout(size: CGFloat) -> some View {
        self
            .font(.system(size: size, weight: .ultraLight))
            .monospacedDigit()
            .kerning(-1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - Surfaces

/// The paper card docked at the bottom of every screen. Controls live here;
/// state lives on the dark surface above it.
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 18) { content }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.top, 26)
            .padding(.bottom, 30)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.cardRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: Theme.cardRadius,
                    style: .continuous
                )
                .fill(Theme.paper)
                .ignoresSafeArea(edges: .bottom)
            }
    }
}

// MARK: - Controls

/// Filled pill, ink on paper. One per screen — the primary action.
struct SolidPill: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(isEnabled ? Theme.paper : Theme.ashOnPaper)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                Capsule().fill(isEnabled ? Theme.inkOnPaper : Theme.paperEdge)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.22), value: configuration.isPressed)
    }
}

// MARK: - The object

/// The brick, drawn as a machined block seen face on: a chamfered slab with a
/// single engraved ring at its centre. Same silhouette as the printed object.
struct BrickBlock: View {
    var width: CGFloat = 190
    var isActive = false

    private var height: CGFloat { width * 0.62 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.19, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: isActive
                            ? [Theme.paper, Theme.paperEdge]
                            : [Color(hex: 0x272729), Color(hex: 0x141416)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: width * 0.19, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: isActive
                                    ? [.clear]
                                    : [Color(hex: 0x54545A), Color(hex: 0x1E1E21)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }

            // The engraved tap target, offset high like the real one.
            Circle()
                .strokeBorder(
                    isActive ? Theme.inkOnPaper.opacity(0.5) : Theme.ash.opacity(0.85),
                    lineWidth: width * 0.014
                )
                .frame(width: width * 0.2, height: width * 0.2)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.5), radius: width * 0.1, y: width * 0.045)
        .accessibilityHidden(true)
    }
}
