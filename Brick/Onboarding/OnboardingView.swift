import BrickKit
import SwiftUI

/// Three honest screens, then the two things that actually gate use:
/// authorization and a paired brick. Nothing is asked for before it's needed.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    private var controller: BrickController { model.controller }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()

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
        }
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Theme.chalk : Theme.graphite)
                    .frame(width: index == page ? 18 : 6, height: 6)
                    .animation(.snappy, value: page)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Pages

    private func explainer(
        block: Bool = false,
        eyebrow: String,
        title: String,
        body: String
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            if block {
                BrickBlock(width: 200)
                    .padding(.bottom, 46)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(eyebrow).engraved()
                Text(title)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.chalk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(body)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.ash)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)

            Spacer()

            pageDots.padding(.bottom, 22)

            PaperCard {
                Button("Continue") { withAnimation { page += 1 } }
                    .buttonStyle(SolidPill())
            }
        }
    }

    private var setup: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

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

                        step(
                            index: 2,
                            title: "Pair your brick",
                            detail: controller.state.tag.map { "Paired \(Format.day($0.pairedAt))" }
                                ?? "Hold your iPhone near it.",
                            done: controller.state.isPaired,
                            enabled: model.isAuthorized
                        ) {
                            Button(model.scanning ? "Scanning" : "Scan") {
                                Task { await model.scan { try await controller.pairBrick() } }
                            }
                            .disabled(model.scanning)
                        }

                        step(
                            index: 3,
                            title: "Choose what it blocks",
                            detail: controller.state.blocklist.summary,
                            done: !controller.state.blocklist.isEmpty,
                            enabled: controller.state.isPaired
                        ) {
                            NavigationLink("Choose") { BlocklistView() }
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer()

                    pageDots.padding(.bottom, 30)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
        HStack(spacing: 16) {
            Group {
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.chalk))
                } else {
                    Text("\(index)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ash)
                        .frame(width: 26, height: 26)
                        .background(Circle().strokeBorder(Theme.graphite, lineWidth: 1))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.chalk)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ash)
            }

            Spacer(minLength: 8)

            if !done {
                action()
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(Capsule().fill(Theme.chalk))
            }
        }
        .opacity(enabled || done ? 1 : 0.35)
        .disabled(!enabled && !done)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Step \(index). \(title). \(done ? "Done" : detail)")
    }
}
