import BrickKit
import FamilyControls
import SwiftUI

/// One occasion: what it blocks, how long it runs, and which bricks it belongs
/// to. The only place the app touches `FamilyActivitySelection` — it is encoded
/// to bytes immediately and handed to BrickKit, which never decodes it.
struct SetupDetailView: View {
    @Environment(AppModel.self) private var model
    let setupID: UUID

    // `includeEntireCategory: true` is load-bearing. With the default `false`,
    // picking a category hands back a token that shields nothing: the apps
    // inside it are never covered, and a session blocks absolutely nothing
    // while the UI claims "1 category". Verified on device.
    @State private var selection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var pickerShown = false
    @State private var loaded = false
    @State private var name = ""

    private var controller: BrickController { model.controller }

    /// A setup deleted from under this screen leaves it showing a blank; the
    /// fallback keeps the bindings valid until the pop happens.
    private var setup: BlockProfile {
        controller.state.profile(id: setupID) ?? BlockProfile()
    }

    private var isRunning: Bool {
        controller.activeSession != nil
            && controller.activeProfile.id == setupID
    }

    private var bricks: [BrickTag] {
        controller.state.tags.filter { $0.profileID == setupID }
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name, prompt: Text("Deep work"))
                    .foregroundStyle(Theme.chalk)
                    .onSubmit { rename() }

                Button {
                    pickerShown = true
                } label: {
                    HStack {
                        Text("Apps, categories and sites")
                            .foregroundStyle(Theme.chalk)
                        Spacer()
                        Text(setup.summary)
                            .foregroundStyle(Theme.ash)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.graphite)
                    }
                }
                .disabled(isRunning)
            } footer: {
                Text("Changes apply to your next session, not the one running.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                durationPicker(
                    title: "Default",
                    value: setup.defaultDuration,
                    options: [15, 30, 45, 60, 90, 120, 180, 240, 360, 480]
                ) { newValue in
                    var updated = setup
                    updated.defaultDuration = max(.brickMinimumSession, newValue)
                    controller.updateProfile(updated)
                }

                durationPicker(
                    title: "Locked for at least",
                    value: setup.minimumDuration,
                    options: [0, 5, 15, 30, 45, 60, 90, 180, 360]
                ) { newValue in
                    var updated = setup
                    updated.minimumDuration = max(0, newValue)
                    controller.updateProfile(updated)
                }
            } header: {
                InkSectionHeader(text: "Session length")
            } footer: {
                Text("Until the minimum has passed, tapping the brick won't end the session — that's what makes it a commitment rather than a switch. Emergency unlocks still work.")
                    .foregroundStyle(Theme.ash)
            }

            Section {
                if bricks.isEmpty {
                    Text("No brick starts this one yet.")
                        .foregroundStyle(Theme.ash)
                } else {
                    ForEach(bricks) { brick in
                        LabeledContent {
                            Text(String(brick.uid.suffix(6)))
                                .monospaced()
                                .foregroundStyle(Theme.ash)
                        } label: {
                            Text(brick.displayName).foregroundStyle(Theme.chalk)
                        }
                    }
                }
            } header: {
                InkSectionHeader(text: "Started by")
            } footer: {
                Text("Tapping one of these bricks starts this setup. Assign them under Bricks.")
                    .foregroundStyle(Theme.ash)
            }
        }
        .inkList(setup.name.isEmpty ? "Setup" : setup.name)
        .familyActivityPicker(isPresented: $pickerShown, selection: $selection)
        .onChange(of: selection) { _, newValue in
            guard loaded else { return }
            persist(newValue)
        }
        .task {
            name = setup.name
            if let existing = try? SelectionCoder.decode(setup.selectionData) {
                selection = SelectionCoder.wholeCategories(existing)
            }
            loaded = true
        }
        .onChange(of: name) { _, _ in rename() }
    }

    private func rename() {
        var updated = setup
        updated.name = name
        controller.updateProfile(updated)
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
        var updated = setup
        updated.selectionData = try? SelectionCoder.encode(newValue)
        updated.appCount = newValue.applicationTokens.count
        updated.categoryCount = newValue.categoryTokens.count
        updated.webDomainCount = newValue.webDomainTokens.count
        controller.updateProfile(updated)
    }
}
