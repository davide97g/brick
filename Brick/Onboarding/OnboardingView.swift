import BrickKit
import SwiftUI

/// Three honest screens, then the two things that actually gate use:
/// authorization and a paired brick. Nothing is asked for before it's needed.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var page = 0

    private var controller: BrickController { model.controller }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                explainer(
                    glyph: true,
                    title: "One brick. One decision.",
                    body: "Leave the brick where you work. Tap it to start, then walk away. Getting your apps back means going back to it."
                )
                .tag(0)

                explainer(
                    symbol: "lock.shield",
                    title: "Nothing leaves your phone",
                    body: "Apple hands this app opaque tokens, not app names — it can't see what you blocked. There are no accounts, no analytics, and no networking code at all."
                )
                .tag(1)

                explainer(
                    symbol: "exclamationmark.triangle",
                    title: "Deleting the app unblocks everything",
                    body: "That's how iOS works, and no app can change it. If you want that door shut, turn on Screen Time → Content & Privacy → App Deletion → Don't Allow."
                )
                .tag(2)

                setupPage
                    .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Pages

    private func explainer(
        glyph: Bool = false,
        symbol: String? = nil,
        title: String,
        body: String
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()
            if glyph {
                BrickGlyph(size: 140)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("Continue") { withAnimation { page += 1 } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            Spacer().frame(height: 48)
        }
        .padding(28)
    }

    private var setupPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Set up")
                .font(.title.bold())

            VStack(spacing: 12) {
                setupRow(
                    number: 1,
                    title: "Allow Screen Time access",
                    detail: "Required to block anything.",
                    done: model.isAuthorized
                ) {
                    Button("Allow") { Task { await model.requestAuthorization() } }
                        .buttonStyle(.borderedProminent)
                }

                setupRow(
                    number: 2,
                    title: "Pair your brick",
                    detail: controller.state.tag.map { "Paired \(Format.day($0.pairedAt))" } ?? "Hold your iPhone near it.",
                    done: controller.state.isPaired,
                    enabled: model.isAuthorized
                ) {
                    Button(model.scanning ? "Scanning…" : "Scan") {
                        Task { await model.scan { try await controller.pairBrick() } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.scanning)
                }

                setupRow(
                    number: 3,
                    title: "Choose what it blocks",
                    detail: controller.state.blocklist.summary,
                    done: !controller.state.blocklist.isEmpty,
                    enabled: controller.state.isPaired
                ) {
                    NavigationLink {
                        BlocklistView()
                    } label: {
                        Text("Choose")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        // The picker is presented from a NavigationLink, so this page needs a stack.
        .modifier(WrapInNavigationStack())
    }

    private func setupRow(
        number: Int,
        title: String,
        detail: String,
        done: Bool,
        enabled: Bool = true,
        @ViewBuilder action: () -> some View
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Theme.accent : Color.primary.opacity(0.08))
                    .frame(width: 30, height: 30)
                if done {
                    Image(systemName: "checkmark")
                        .font(.footnote.bold())
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.footnote.bold())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }

            Spacer()

            if !done { action() }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
        .opacity(enabled || done ? 1 : 0.4)
        .disabled(!enabled && !done)
    }
}

private struct WrapInNavigationStack: ViewModifier {
    func body(content: Content) -> some View {
        NavigationStack { content }
    }
}
