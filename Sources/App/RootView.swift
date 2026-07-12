import SwiftUI

/// App root using Nell's five-destination product navigation.
struct RootView: View {
    var body: some View {
        NellAppShellView()
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview.container)
}
