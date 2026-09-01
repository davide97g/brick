import BrickKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var startSheetShown = false
    @State private var tick = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var controller: BrickController { model.controller }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.authorizationLost {
                    warning(
                        "Screen Time access is off",
                        detail: "Nothing is being blocked. Turn it back on in Settings → Screen Time."
                    )
                } else if model.enforcementBroken {
                    warning(
                        "Not actually blocking",
                        detail: "The blocked apps couldn't be applied. Re-pick them in Settings."
                    )
                }

                if controller.activeSession != nil {
                    activeSession
                } else {
                    idle
                }
            }
            .animation(.snappy, value: controller.activeSession?.id)
            .navigationTitle("Brick")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $startSheetShown) {
            StartSessionSheet(defaultDuration: controller.state.blocklist.defaultDuration)
                .environment(model)
        }
        .onReceive(ticker) { now in
            tick = now
            // Doubles as the safety net: if the planned end has passed and the
            // monitor extension never fired, this clears the shield.
            controller.reconcile()
        }
    }

    private func warning(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.yellow.opacity(0.18), in: .rect(cornerRadius: 14))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: Running

    @ViewBuilder
    private var activeSession: some View {
        if let session = controller.activeSession {
            ScrollView {
                VStack(spacing: 28) {
                    SessionRing(
                        progress: progress(of: session),
                        remaining: session.remaining(at: controller.now),
                        caption: "until \(Format.clockTime(session.plannedEnd))"
                    )
                    .padding(.top, 12)

                    Text(controller.state.tag?.whereItIs ?? "")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        Button {
                            Task { await model.scan { try await controller.endSessionByTap() } }
                        } label: {
                            Text(endButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!controller.canEndByTap || model.scanning)

                        if !controller.canEndByTap, let opensAt = controller.tapExitOpensAt {
                            Text("The brick can end this at \(Format.clockTime(opensAt)).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        EmergencyUnlockButton(remainingAllowance: controller.emergencyRemaining) {
                            do {
                                try controller.endSessionByEmergency()
                            } catch {
                                model.present(error)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var endButtonTitle: String {
        if model.scanning { return "Hold near your brick…" }
        return controller.canEndByTap ? "Tap your brick to end" : "Locked"
    }

    private func progress(of session: Session) -> Double {
        guard session.plannedDuration > 0 else { return 1 }
        return session.elapsed(at: controller.now) / session.plannedDuration
    }

    // MARK: Idle

    private var idle: some View {
        ScrollView {
            VStack(spacing: 28) {
                BrickGlyph(size: 160)
                    .padding(.top, 24)

                VStack(spacing: 6) {
                    Text("Ready")
                        .font(.title2.bold())
                    Text(controller.state.blocklist.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    startSheetShown = true
                } label: {
                    Text("Start a session")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 24)

                if let last = controller.state.history.last {
                    lastSessionCard(last)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func lastSessionCard(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(Format.duration(session.elapsed(at: session.endedAt ?? session.plannedEnd)))
                .font(.title3.weight(.medium))
            Text(endedDescription(session))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
    }

    private func endedDescription(_ session: Session) -> String {
        switch session.endReason {
        case .scheduled: return "Ran its full length"
        case .tappedBrick: return "Ended at the brick"
        case .emergency: return "Ended with an emergency unlock"
        case .none: return ""
        }
    }
}
