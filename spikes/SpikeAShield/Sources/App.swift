import SwiftUI
import FamilyControls
import ManagedSettings

@main
struct SpikeAShieldApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

@MainActor
final class ShieldModel: ObservableObject {
    private let store = ManagedSettingsStore(named: .init("spike"))

    @Published var authorized = false
    @Published var selection = FamilyActivitySelection()
    @Published var shielded = false
    @Published var status = "idle"

    private let defaults = UserDefaults.standard

    init() {
        authorized = AuthorizationCenter.shared.authorizationStatus == .approved
        shielded = defaults.bool(forKey: "shielded")
        if let data = defaults.data(forKey: "selection"),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        }
    }

    func authorize() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorized = true
            status = "authorized"
        } catch {
            status = "auth failed: \(error)"
        }
    }

    func persistSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: "selection")
        }
    }

    func applyShield() {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        shielded = true
        defaults.set(true, forKey: "shielded")
        status = "shield applied (\(selection.applicationTokens.count) apps, \(selection.categoryTokens.count) categories)"
    }

    func clearShield() {
        store.clearAllSettings()
        shielded = false
        defaults.set(false, forKey: "shielded")
        status = "shield cleared"
    }
}

struct ContentView: View {
    @StateObject private var model = ShieldModel()
    @State private var pickerShown = false

    var body: some View {
        NavigationStack {
            List {
                Section("1 · authorization") {
                    LabeledContent("status", value: model.authorized ? "approved" : "not approved")
                    Button("Request authorization") {
                        Task { await model.authorize() }
                    }
                    .disabled(model.authorized)
                }

                Section("2 · selection") {
                    LabeledContent("apps", value: "\(model.selection.applicationTokens.count)")
                    LabeledContent("categories", value: "\(model.selection.categoryTokens.count)")
                    LabeledContent("web domains", value: "\(model.selection.webDomainTokens.count)")
                    Button("Pick apps") { pickerShown = true }
                        .disabled(!model.authorized)
                }

                Section("3 · shield") {
                    LabeledContent("shielded", value: model.shielded ? "YES" : "no")
                    Button("Apply shield") { model.applyShield() }
                        .disabled(!model.authorized)
                    Button("Clear shield", role: .destructive) { model.clearShield() }
                }

                Section("log") {
                    Text(model.status).font(.footnote.monospaced())
                }
            }
            .navigationTitle("Spike A")
            .familyActivityPicker(isPresented: $pickerShown, selection: $model.selection)
            .onChange(of: model.selection) { _, _ in model.persistSelection() }
        }
    }
}
