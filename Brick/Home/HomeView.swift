import BrickKit
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startSheetShown = false
    @State private var tick = Date()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var controller: BrickController { model.controller }

    /// Reverse mode reads upside down: paper field, machined card. Nothing
    /// else about the instrument changes.
    private var surface: Surface { controller.isArmed ? .reversed : .standard }

    var body: some View {
        NavigationStack {
            ZStack {
                surface.field.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if let warning = warningText {
                        notice(warning.0, detail: warning.1)
                    }

                    Spacer(minLength: 0)

                    if controller.isPermitRunning {
                        permitInstrument
                    } else if controller.activeSession != nil {
                        instrument
                    } else {
                        object
                    }

                    Spacer(minLength: 0)

                    if controller.isPermitRunning {
                        permitControls
                    } else if controller.activeSession != nil {
                        runningControls
                    } else if controller.isArmed {
                        armedControls
                    } else {
                        idleControls
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: settingsBinding) { SettingsView() }
        }
        .task {
            #if DEBUG
            if model.uiPreview == "start" { startSheetShown = true }
            // Everything but Home lives behind Settings, so the hooks open it
            // the same way a tap does — including for the status bar.
            if ["settings", "blocklist", "bricks", "setups", "brick", "route"]
                .contains(model.uiPreview ?? "") {
                model.settingsOpen = true
            }
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

    private var settingsBinding: Binding<Bool> {
        @Bindable var model = model
        return $model.settingsOpen
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Text(headerTitle)
                .engraved(surface.fieldText)

            Spacer()

            Button {
                model.settingsOpen = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(surface.fieldMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.leading, 26)
        .padding(.trailing, 12)
        .padding(.top, 8)
    }

    private var headerTitle: String {
        if controller.isPermitRunning { return "Open" }
        if controller.isArmed { return "Standing" }
        return controller.activeSession != nil ? "Bricked" : "Brick"
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
                isOpen: controller.canEndWithKey,
                surface: surface
            )
            .animation(reduceMotion ? nil : .linear(duration: 1), value: tick)
        }
    }

    // MARK: Reverse

    /// The same bezel, counting an open window down rather than a shut one.
    @ViewBuilder
    private var permitInstrument: some View {
        if let session = controller.activeSession {
            SessionBezel(
                progress: progress(of: session),
                gate: nil,
                remaining: session.remaining(at: controller.now),
                caption: "open until \(Format.clockTime(session.plannedEnd))",
                isOpen: true,
                surface: surface
            )
            .animation(reduceMotion ? nil : .linear(duration: 1), value: tick)
        }
    }

    private var permitControls: some View {
        PaperCard(surface: surface) {
            Text("It goes back up by itself.")
                .font(.system(size: 15))
                .foregroundStyle(surface.cardMuted)

            Button("Put it back now") { controller.closePermitEarly() }
                .buttonStyle(SolidPill(surface: surface))
        }
    }

    private var armedControls: some View {
        PaperCard(surface: surface) {
            Text(controller.armedProfile.map { "\($0.name) is standing." } ?? "Standing.")
                .font(.system(size: 15))
                .foregroundStyle(surface.cardMuted)

            VStack(spacing: 10) {
                Button {
                    Task { await model.scan { try await controller.grantPermit() } }
                } label: {
                    Text(openButtonTitle)
                }
                .buttonStyle(SolidPill(surface: surface))
                .disabled(model.scanning || controller.permitsRemaining == 0)

                Text(openingsText)
                    .engraved(surface.cardMuted)

                Button("Take it down") {
                    Task { await model.scan { try await controller.disarmReverse() } }
                }
                .font(.system(size: 14))
                .foregroundStyle(controller.canDisarm ? surface.cardText : surface.cardMuted)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .disabled(!controller.canDisarm || model.scanning)

                // The block path says when its gate opens; this one owes the
                // same answer rather than a grey button with no reason.
                if !controller.canDisarm, let opensAt = controller.disarmOpensAt {
                    Text("it can come down at \(Format.clockTime(opensAt))")
                        .engraved(surface.cardMuted)
                }
            }

            if controller.permitsRemaining == 0 {
                EmergencyUnlockButton(
                    remainingAllowance: controller.emergencyRemaining,
                    title: "Hold for one more",
                    surface: surface
                ) {
                    Task {
                        await model.scan {
                            try await controller.grantPermit(spendingEmergency: true)
                        }
                    }
                }
            }
        }
    }

    private var openButtonTitle: String {
        if model.scanning { return "Hold near your brick" }
        guard controller.permitsRemaining > 0 else { return "Nothing left today" }
        let length = Format.duration(controller.armedProfile?.permitDuration ?? .brickMinimumSession)
        return controller.unlockMethod == .brick
            ? "Tap your brick for \(length)"
            : "Open for \(length)"
    }

    private var openingsText: String {
        let left = controller.permitsRemaining
        if left == 0, let opensAt = nextOpeningAt {
            return "next opening \(Format.clockTime(opensAt))"
        }
        return "\(left) opening\(left == 1 ? "" : "s") left today"
    }

    private var nextOpeningAt: Date? {
        guard let profile = controller.armedProfile else { return nil }
        return controller.state.permits.nextReplenishment(
            at: controller.now,
            allowance: profile.permitAllowance,
            window: profile.permitWindow
        )
    }

    private var runningControls: some View {
        PaperCard(surface: surface) {
            Text(controller.keyDescription)
                .font(.system(size: 15))
                .foregroundStyle(surface.cardMuted)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                Button {
                    Task { await model.scan { try await controller.endSessionUsingKey() } }
                } label: {
                    Text(endButtonTitle)
                }
                .buttonStyle(SolidPill(surface: surface))
                .disabled(!controller.canEndWithKey || model.scanning)

                if !controller.canEndWithKey, let opensAt = controller.keyExitOpensAt {
                    Text(gateText(opensAt))
                        .engraved(surface.cardMuted)
                } else if let route = controller.routeStatus, !route.isSingleTap {
                    Text("\(route.walked) of \(route.steps.count) taps done")
                        .engraved(surface.cardMuted)
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
            if model.scanning { return "Hold near your brick" }
            if let route = controller.routeStatus, !route.isSingleTap, let next = route.next {
                return "Tap \(next.displayName)"
            }
            return "Tap your brick to end"
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
                Text(controller.isArmed ? "Blocked" : "Ready")
                    .readout(size: 40)
                    .foregroundStyle(surface.fieldText)
                Text(controller.activeProfile.summary)
                    .engraved(surface.fieldMuted)
            }
        }
    }

    private var idleControls: some View {
        PaperCard(surface: surface) {
            if let last = controller.state.history.last {
                lastSession(last)
            }

            Button("Start a session") { startSheetShown = true }
                .buttonStyle(SolidPill(surface: surface))
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
        case .closedEarly: return "closed early"
        case .none: return ""
        }
    }
}
