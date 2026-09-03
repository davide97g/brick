import SwiftUI

/// The settings screens keep a plain grouped list — a machined instrument is
/// still a native iOS app — but on the ink surface rather than system grey.
extension View {
    func inkList(_ title: String) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.ink)
            // These screens are ink whichever way the home field is facing.
            // `listRowBackground` alone was never doing this: the system's dark
            // grouped background simply matched, which reverse mode exposed.
            .environment(\.colorScheme, .dark)
            .listRowBackground(Theme.inkRaised)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

/// Section header in the engraved hardware voice.
struct InkSectionHeader: View {
    let text: String
    var body: some View {
        Text(text).engraved()
    }
}
