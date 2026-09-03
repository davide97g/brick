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
    /// Graphite's opposite number: recessed marks on the paper field.
    static let chalkline = Color(hex: 0xC7BEAE)

    /// Ink-side text on the paper card.
    static let inkOnPaper = Color(hex: 0x17171A)
    static let ashOnPaper = Color(hex: 0x6B675F)

    /// The only chroma in the app.
    static let oxide = Color(hex: 0xB4614F)

    static let cardRadius: CGFloat = 30
}

/// Which way round the instrument is.
///
/// Reverse mode inverts the two zones rather than introducing a colour: the
/// palette has exactly one chromatic value and it is spoken for. Paper becomes
/// the field, the machined surface becomes the card, and a glance says which
/// world the phone is in before a word is read.
struct Surface: Equatable {
    let field: Color
    let fieldText: Color
    let fieldMuted: Color
    let fieldRecessed: Color
    let card: Color
    let cardText: Color
    let cardMuted: Color

    static let standard = Surface(
        field: Theme.ink,
        fieldText: Theme.chalk,
        fieldMuted: Theme.ash,
        fieldRecessed: Theme.graphite,
        card: Theme.paper,
        cardText: Theme.inkOnPaper,
        cardMuted: Theme.ashOnPaper
    )

    static let reversed = Surface(
        field: Theme.paper,
        fieldText: Theme.inkOnPaper,
        fieldMuted: Theme.ashOnPaper,
        fieldRecessed: Theme.chalkline,
        card: Theme.ink,
        cardText: Theme.chalk,
        cardMuted: Theme.ash
    )
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

/// A system font at a chosen size that still follows the reader's text-size
/// setting. `Font.system(size:)` does not: it is fixed for ever, which is what
/// every size in this app used to be.
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    /// The app's text. Sizes stay hand-set — this is an instrument, and the
    /// scale between labels is part of it — but they scale with the reader.
    func brickText(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, relativeTo: style))
    }

    /// Engraved hardware label: small, wide-tracked, upper case.
    func engraved(_ color: Color = Theme.ash) -> some View {
        self
            .brickText(11, weight: .medium, relativeTo: .caption2)
            .tracking(2.4)
            .textCase(.uppercase)
            .multilineTextAlignment(.center)
            // Engraved labels wrap rather than truncate: a clipped one reads
            // as a rendering fault, not as a smaller label.
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(color)
    }

    /// Instrument readout: thin, large, tabular so digits don't jitter.
    ///
    /// Scales, but only so far: these numerals start at 40-66pt and live in a
    /// fixed bezel, so past a point growing them buys no legibility and only
    /// breaks the dial. Callers clamp with `instrumentTypeSize()`.
    func readout(size: CGFloat) -> some View {
        self
            .brickText(size, weight: .ultraLight, relativeTo: .largeTitle)
            .monospacedDigit()
            .kerning(-1)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// The ceiling for text inside the dial and the big readouts.
    func instrumentTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

/// Content that centres when it fits and scrolls when it doesn't — which is
/// what large text turns every full-height layout into.
struct CenteredScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content.frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

// MARK: - Surfaces

/// The paper card docked at the bottom of every screen. Controls live here;
/// state lives on the dark surface above it.
struct PaperCard<Content: View>: View {
    var surface: Surface = .standard
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
                .fill(surface.card)
                .ignoresSafeArea(edges: .bottom)
            }
    }
}

// MARK: - Controls

/// Filled pill, ink on paper. One per screen — the primary action.
struct SolidPill: ButtonStyle {
    var surface: Surface = .standard

    func makeBody(configuration: Configuration) -> some View {
        PillLabel(surface: surface, isPressed: configuration.isPressed) {
            configuration.label
        }
    }

    /// A view rather than inline styling, so the pill's height can scale with
    /// the label instead of clipping it at large text sizes.
    private struct PillLabel<Label: View>: View {
        let surface: Surface
        let isPressed: Bool
        @ViewBuilder var label: Label

        @Environment(\.isEnabled) private var isEnabled
        @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 54

        var body: some View {
            label
                .brickText(16, weight: .medium)
                .multilineTextAlignment(.center)
                .foregroundStyle(isEnabled ? surface.card : surface.cardText.opacity(0.55))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(
                    Capsule().fill(isEnabled ? surface.cardText : surface.cardText.opacity(0.10))
                )
                .scaleEffect(isPressed ? 0.97 : 1)
                .animation(.spring(duration: 0.22), value: isPressed)
        }
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
