import BrickKit
import FamilyControls
import SwiftUI

/// The one place the app touches `FamilyActivitySelection`. It is encoded to
/// bytes immediately and handed to BrickKit, which never decodes it.
struct BlocklistView: View {
    @Environment(AppModel.self) private var model
    // `includeEntireCategory: true` is load-bearing. With the default `false`,
    // picking a category hands back a token that shields nothing: the apps
    // inside it are never covered, and a session blocks absolutely nothing
    // while the UI claims "1 category". Verified on device.
    @State private var selection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pickerShown = false
    @State private var loaded = false

    private var controller: BrickController { model.controller }
    private var blocklist: BlocklistConfig { controller.state.blocklist }

    var body: some View {
        List {
            Section {
                Button {
                    pickerShown = true
                } label: {
                    HStack {
                        Text("Apps, categories and sites")
                            .foregroundStyle(Theme.chalk)
                        Spacer()
                        Text(blocklist.summary)
                            .foregroundStyle(Theme.ash)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.graphite)
                    }
                }
                .disabled(controller.activeSession != nil)
            } footer: {
                Text("Changes apply to your next session, not the one running.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                durationPicker(
                    title: "Default",
                    value: blocklist.defaultDuration,
                    options: [15, 30, 45, 60, 90, 120, 180, 240]
                ) { newValue in
                    controller.updateDurations(default: newValue, minimum: blocklist.minimumDuration)
                }


                durationPicker(
                    title: "Locked for at least",
                    value: blocklist.minimumDuration,
                    options: [0, 5, 15, 30, 45, 60, 90]
                ) { newValue in
                    controller.updateDurations(default: blocklist.defaultDuration, minimum: newValue)
                }
            } header: {
                InkSectionHeader(text: "Session length")
            }

            Section {
                EmptyView()
            } footer: {
                Text("Until the minimum has passed, tapping the brick won't end the session — that's what makes it a commitment rather than a switch. Emergency unlocks still work.")
                    .foregroundStyle(Theme.ash)
            }
        }
        .inkList("What it blocks")
        .familyActivityPicker(isPresented: $pickerShown, selection: $selection)
        .onChange(of: selection) { _, newValue in
            guard loaded else { return }
            persist(newValue)
        }
        .task {
            if let existing = try? SelectionCoder.decode(blocklist.selectionData) {
                selection = SelectionCoder.wholeCategories(existing)
            }
            loaded = true
        }
    }

    private func durationPicker(
        title: String,
        value: TimeInterval,
        options: [Double],
        onChange: @escaping (TimeInterval) -> Void
    ) -> some View {
        Picker(selection: Binding(get: { value }, set: onChange)) {
            ForEach(options, id: \.self) { minutes in
                Text(minutes == 0 ? "No minimum" : Format.duration(.brickMinutes(minutes)))
                    .tag(TimeInterval.brickMinutes(minutes))
            }
        } label: {
            Text(title).foregroundStyle(Theme.chalk)
        }
    }

    private func persist(_ newValue: FamilyActivitySelection) {
        let data = try? SelectionCoder.encode(newValue)
        controller.updateBlocklist(
            selectionData: data,
            appCount: newValue.applicationTokens.count,
            categoryCount: newValue.categoryTokens.count,
            webDomainCount: newValue.webDomainTokens.count
        )
    }
}
