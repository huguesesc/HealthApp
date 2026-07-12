import SwiftUI

/// App root using the approved five-destination product navigation.
struct RootView: View {
    var body: some View {
        AppShellView()
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview.container)
}
