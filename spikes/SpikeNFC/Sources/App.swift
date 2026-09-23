import SwiftUI

@main
struct SpikeNFCApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @StateObject private var lab = NFCLab()
    @State private var text = "hello from the spike"
    @State private var uri = "https://apple.com"

    /// Each one answers a different "can NFC do X" question, so they stay
    /// visible rather than hiding behind a text field.
    private let presets: [(String, String)] = [
        ("Web page", "https://apple.com"),
        ("Open Shortcuts", "shortcuts://run-shortcut?name=Test"),
        ("Open Maps", "maps://?q=home"),
        ("Call", "tel:+390000000"),
        ("Wi-Fi-ish deep link", "prefs:root=WIFI"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Read") {
                    Button("Inspect tag") { lab.run(.inspect, prompt: "Hold a tag near the top of the phone.") }
                }

                Section("Write a text record") {
                    TextField("text", text: $text)
                    Button("Write text") { lab.run(.writeText(text), prompt: "Hold the tag to write.") }
                }

                Section("Write a URI record") {
                    TextField("uri", text: $uri)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(presets, id: \.1) { label, value in
                                Button(label) { uri = value }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                    Button("Write URI") { lab.run(.writeURI(uri), prompt: "Hold the tag to write.") }
                    Button("Open it now (what a scan could trigger)") {
                        if let url = URL(string: uri) { UIApplication.shared.open(url) }
                    }
                }

                Section("Danger-free reset") {
                    Button("Erase NDEF", role: .destructive) { lab.run(.erase, prompt: "Hold the tag to erase.") }
                    Text("Never locks a tag. Locking is one-way; the Brick app does it on purpose, this doesn't.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Log") {
                    ForEach(Array(lab.log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .disabled(lab.busy)
            .navigationTitle("NFC spike")
        }
    }
}
