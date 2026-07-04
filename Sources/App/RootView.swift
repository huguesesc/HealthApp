import SwiftUI

/// App root. A single navigation stack with the dashboard as home; every module is
/// reached as an entry point from the dashboard. Simple and clean for the MVP — no
/// tab bar to manage as features grow.
struct RootView: View {
    var body: some View {
        NavigationStack {
            DashboardView()
        }
        .tint(Theme.evergreen)
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview.container)
}
