import BrickKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startSheetShown = false
    @State private var tick = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var controller: BrickController { model.controller }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.ink.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if let warning = warningText {
                        notice(warning.0, detail: warning.1)
                    }

                    Spacer(minLength: 0)

                    if controller.activeSession != nil {
                        instrument
                    } else {
                        object
                    }

                    Spacer(minLength: 0)

                    if controller.activeSession != nil {
                        runningControls
                    } else {
                        idleControls
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: settingsPreviewBinding) { SettingsView() }
        }
        .task {
            #if DEBUG
            if model.uiPreview == "start" { startSheetShown = true }
            #endif
        }
        .sheet(isPresented: $startSheetShown) {
            StartSessionSheet(defaultDuration: controller.activeProfile.defaultDuration)
                .environment(model)
        }
        .onReceive(ticker) { now in
            tick = now
            // Doubles as the safety net: if the planned end has passed and the
            // monitor extension never fired, this clears the shield.
            controller.reconcile()
        }
    }

    private var settingsPreviewBinding: Binding<Bool> {
        #if DEBUG
        // "blocklist" lives one push deeper, so Settings has to open first.
        Binding(get: {
            ["settings", "blocklist", "bricks", "setups", "brick"].contains(model.uiPreview ?? "")
        }, set: { _ in })
        #else
        .constant(false)
        #endif
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Text(controller.activeSession != nil ? "Bricked" : "Brick")
                .engraved(Theme.chalk)

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Theme.ash)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.leading, 26)
        .padding(.trailing, 12)
        .padding(.top, 8)
    }

    private var warningText: (String, String)? {
        if model.authorizationLost {
            return ("Screen Time is off", "Nothing is being blocked. Turn it back on in Settings.")
        }
        if model.enforcementBroken {
            return ("Not actually blocking", "The apps couldn't be applied. Choose them again.")
        }
        return nil
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).engraved(Theme.oxide)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Theme.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.oxide.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    // MARK: Running

    @ViewBuilder
    private var instrument: some View {
        if let session = controller.activeSession {
            SessionBezel(
                progress: progress(of: session),
                gate: gate(of: session),
                remaining: session.remaining(at: controller.now),
                caption: "until \(Format.clockTime(session.plannedEnd))",
                isOpen: controller.canEndWithKey
            )
            .animation(reduceMotion ? nil : .linear(duration: 1), value: tick)
        }
    }

    private var runningControls: some View {
        PaperCard {
            Text(controller.keyDescription)
                .font(.system(size: 15))
                .foregroundStyle(Theme.ashOnPaper)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    Task { await model.scan { try await controller.endSessionUsingKey() } }
                } label: {
                    Text(endButtonTitle)
                }
                .buttonStyle(SolidPill())
                .disabled(!controller.canEndWithKey || model.scanning)

                if !controller.canEndWithKey, let opensAt = controller.keyExitOpensAt {
                    Text(gateText(opensAt))
                        .engraved(Theme.ashOnPaper)
                }
            }

            EmergencyUnlockButton(remainingAllowance: controller.emergencyRemaining) {
                Task { await model.scan { try await controller.endSessionByEmergency() } }
            }
        }
    }

    private var endButtonTitle: String {
        guard controller.canEndWithKey else { return "Locked" }
        switch controller.unlockMethod {
        case .brick:
            return model.scanning ? "Hold near your brick" : "Tap your brick to end"
        case .biometric:
            return "End with \(controller.biometricName)"
        }
    }

    private func gateText(_ opensAt: Date) -> String {
        let subject = controller.unlockMethod == .brick ? "The brick" : controller.biometricName
        return "\(subject) opens at \(Format.clockTime(opensAt))"
    }

    private func progress(of session: Session) -> Double {
        guard session.plannedDuration > 0 else { return 1 }
        return min(1, session.elapsed(at: controller.now) / session.plannedDuration)
    }

    /// Where on the bezel the brick starts working.
    private func gate(of session: Session) -> Double? {
        let minimum = controller.activeProfile.minimumDuration
        guard minimum > 0, session.plannedDuration > 0 else { return nil }
        let fraction = minimum / session.plannedDuration
        return fraction < 1 ? fraction : nil
    }

    // MARK: Idle

    private var object: some View {
        VStack(spacing: 30) {
            BrickBlock(width: 196)

            VStack(spacing: 8) {
                Text("Ready")
                    .readout(size: 40)
                    .foregroundStyle(Theme.chalk)
                Text(controller.activeProfile.summary)
                    .engraved()
            }
        }
    }

    private var idleControls: some View {
        PaperCard {
            if let last = controller.state.history.last {
                lastSession(last)
            }

            Button("Start a session") { startSheetShown = true }
                .buttonStyle(SolidPill())
        }
    }

    private func lastSession(_ session: Session) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Last")
                .engraved(Theme.ashOnPaper)
            Spacer()
            Text(Format.duration(session.elapsed(at: session.endedAt ?? session.plannedEnd)))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkOnPaper)
            Text("·")
                .foregroundStyle(Theme.ashOnPaper)
            Text(endedDescription(session))
                .font(.system(size: 15))
                .foregroundStyle(Theme.ashOnPaper)
        }
    }

    private func endedDescription(_ session: Session) -> String {
        switch session.endReason {
        case .scheduled: return "ran out"
        case .tappedBrick: return "ended at the brick"
        case .biometrics: return "ended with \(controller.biometricName)"
        case .emergency: return "emergency unlock"
        case .none: return ""
        }
    }
}
