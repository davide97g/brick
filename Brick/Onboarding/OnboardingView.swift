import BrickKit
import SwiftUI

/// Three honest screens, then the two things that actually gate use:
/// authorization and a paired brick. Nothing is asked for before it's needed.
///
/// The paper card and the dots are static chrome outside the `TabView`: only
/// the dark content swipes. Keeping the card in the page would slide a second
/// copy of itself into view on every drag, and its bottom safe-area inset
/// doesn't resolve correctly inside a paged container.
extension AnyLayout {
    /// A step reads as a row until the text needs the whole width.
    static func stepLayout(stacked: Bool, @ViewBuilder content: () -> some View) -> some View {
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout { content() }
    }
}

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var page = 0

    private static let pageCount = 4
    private var isSetupPage: Bool { page == Self.pageCount - 1 }

    private var controller: BrickController { model.controller }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    explainer(
                        block: true,
                        eyebrow: "The idea",
                        title: "One object.\nOne decision.",
                        body: "Leave the brick where you work. Tap it to start, then walk away. Getting your apps back means going back to it."
                    )
                    .tag(0)

                    explainer(
                        eyebrow: "Privacy",
                        title: "Nothing leaves\nyour phone.",
                        body: "Apple hands this app opaque tokens, not app names — it can't see what you blocked. No account, no analytics, no networking code at all."
                    )
                    .tag(1)

                    explainer(
                        eyebrow: "The catch",
                        title: "Deleting the app\nunblocks everything.",
                        body: "That's how iOS works, and no app can change it. To shut that door: Settings → Screen Time → Content & Privacy → App Deletion → Don't Allow."
                    )
                    .tag(2)

                    setup.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots
                    .padding(.top, 4)
                    .padding(.bottom, isSetupPage ? 28 : 22)

                if !isSetupPage {
                    PaperCard {
                        Button("Continue") { advance() }
                            .buttonStyle(SolidPill())
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .animation(.smooth(duration: 0.35), value: isSetupPage)
        .task {
            #if DEBUG
            // Screenshot hook: -uiPreview onboard2 opens that page directly.
            if let preview = model.uiPreview, preview.hasPrefix("onboard"),
               let index = Int(preview.dropFirst("onboard".count)) {
                page = min(max(0, index), Self.pageCount - 1)
            }
            #endif
        }
    }

    private var keyStepTitle: String {
        controller.unlockMethod == .biometric ? "\(controller.biometricName) is the key" : "Pair your brick"
    }

    private var keyStepDetail: String {
        switch controller.unlockMethod {
        case .biometric:
            return "No brick. The way out is in your hand — only the minimum duration holds."
        case .brick:
            return controller.state.tag.map { "Paired \(Format.day($0.pairedAt))" }
                ?? "Hold your iPhone near it."
        }
    }

    private func advance() {
        withAnimation(.smooth(duration: 0.45)) {
            page = min(page + 1, Self.pageCount - 1)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<Self.pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.chalk : Theme.graphite)
                    .frame(width: index == page ? 18 : 6, height: 6)
            }
        }
        .animation(.smooth(duration: 0.3), value: page)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(Self.pageCount)")
    }

    // MARK: Pages

    private func explainer(
        block: Bool = false,
        eyebrow: String,
        title: String,
        body: String
    ) -> some View {
        CenteredScroll {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            if block, !typeSize.isAccessibilitySize {
                BrickBlock(width: 200)
                    .padding(.bottom, 46)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(eyebrow).engraved()
                Text(title)
                    .brickText(34, weight: .light, relativeTo: .largeTitle)
                    // Already 34pt: past a point it only costs the body text
                    // the room it needs.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(Theme.chalk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(body)
                    .brickText(16)
                    .foregroundStyle(Theme.ash)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 24)

            Spacer(minLength: 0)
        }
        }
    }

    private var setup: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()

                CenteredScroll {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 26) {
                        Text("Set up").engraved()

                        step(
                            index: 1,
                            title: "Allow Screen Time access",
                            detail: "Required to block anything.",
                            done: model.isAuthorized,
                            enabled: true
                        ) {
                            Button("Allow") { Task { await model.requestAuthorization() } }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            step(
                                index: 2,
                                title: keyStepTitle,
                                detail: keyStepDetail,
                                done: controller.state.hasKey,
                                enabled: model.isAuthorized
                            ) {
                                Button(model.scanning ? "Scanning" : "Scan") {
                                    Task { await model.scan { try await controller.pairBrick() } }
                                }
                                .disabled(model.scanning)
                            }

                            // The brick is the product, so this is a plain line
                            // of text rather than a second button: a way past a
                            // brick that doesn't exist yet, not an equal choice.
                            if !controller.state.hasKey,
                               model.isAuthorized,
                               controller.biometricsAvailable {
                                Button("No brick yet? Use \(controller.biometricName) instead.") {
                                    Task { await model.scan { try await controller.useBiometricUnlock() } }
                                }
                                .brickText(13, relativeTo: .footnote)
                                .foregroundStyle(Theme.ash)
                                .underline()
                                .padding(.leading, 42)
                                .disabled(model.scanning)
                            }
                        }

                        step(
                            index: 3,
                            title: "Choose what it blocks",
                            detail: controller.state.blocklist.summary,
                            done: !controller.state.blocklist.isEmpty,
                            enabled: controller.state.hasKey
                        ) {
                            NavigationLink("Choose") {
                                SetupDetailView(setupID: controller.defaultProfile().id)
                            }
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer(minLength: 0)
                }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ScaledMetric(relativeTo: .caption) private var markerSize: CGFloat = 26
    @ScaledMetric(relativeTo: .subheadline) private var actionHeight: CGFloat = 38

    @ViewBuilder
    private func marker(index: Int, done: Bool) -> some View {
        if done {
            Image(systemName: "checkmark")
                .brickText(12, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(Theme.ink)
                .frame(width: markerSize, height: markerSize)
                .background(Circle().fill(Theme.chalk))
        } else {
            Text("\(index)")
                .brickText(12, weight: .medium, relativeTo: .caption)
                .foregroundStyle(Theme.ash)
                .frame(width: markerSize, height: markerSize)
                .background(Circle().strokeBorder(Theme.graphite, lineWidth: 1))
        }
    }

    private func step(
        index: Int,
        title: String,
        detail: String,
        done: Bool,
        enabled: Bool,
        @ViewBuilder action: () -> some View
    ) -> some View {
        // Three columns stop being three columns at accessibility sizes: the
        // title gets squeezed to a word a line. Stack them instead.
        let stacked = typeSize.isAccessibilitySize
        return AnyLayout.stepLayout(stacked: stacked) {
            marker(index: index, done: done)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .brickText(16)
                    .foregroundStyle(Theme.chalk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .brickText(13, relativeTo: .footnote)
                    .foregroundStyle(Theme.ash)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            if !done {
                action()
                    .brickText(14, weight: .medium, relativeTo: .subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(minHeight: actionHeight)
                    .background(Capsule().fill(Theme.chalk))
                    .fixedSize()
            }
        }
        .opacity(enabled || done ? 1 : 0.35)
        .disabled(!enabled && !done)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(index). \(title). \(done ? "Done" : detail)")
    }
}
