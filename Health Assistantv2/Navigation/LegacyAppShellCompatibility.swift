import SwiftUI

/// Compatibility wrappers for the older `AppShellView`. The application root uses
/// `NellAppShellView`; these aliases keep the legacy shell buildable until it is removed.
struct NellCoachRootView: View {
    var body: some View {
        NellCoachScreen()
    }
}

struct NellNutritionHomeView: View {
    var body: some View {
        NellNutritionView()
    }
}
