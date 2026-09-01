import SwiftUI

/// One accent, one surface treatment, no decoration. The app should feel like
/// an object rather than a dashboard.
enum Theme {
    static let accent = Color.orange
    static let ringTrack = Color.primary.opacity(0.08)

    static let sessionGradient = LinearGradient(
        colors: [Color.orange, Color.orange.opacity(0.55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// The brick itself, drawn. Used as the app's one piece of iconography.
struct BrickGlyph: View {
    var size: CGFloat = 96
    var isActive: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(isActive ? AnyShapeStyle(Theme.sessionGradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
            .frame(width: size, height: size * 0.62)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isActive ? 0 : 0.12), lineWidth: 1)
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        isActive ? Color.white.opacity(0.7) : Color.primary.opacity(0.25),
                        lineWidth: size * 0.02
                    )
                    .frame(width: size * 0.26, height: size * 0.26)
            }
            .shadow(color: .black.opacity(isActive ? 0.25 : 0.08), radius: size * 0.12, y: size * 0.06)
    }
}
