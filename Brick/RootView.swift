import BrickKit
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model

        Group {
            if model.needsSetup {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .animation(.snappy, value: model.needsSetup)
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: alert.message.isEmpty ? nil : Text(alert.message))
        }
        .onChange(of: scenePhase) { _, phase in
            // A shield must never outlive its planned end, even if the monitor
            // extension never fired.
            if phase == .active { model.refreshEnforcement() }
        }
        .task { model.refreshEnforcement() }
    }
}
