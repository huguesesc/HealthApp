import SwiftUI

/// App root using Nell's first-run experience and five-destination navigation.
struct RootView: View {
    @AppStorage("nell.onboarding.completed") private var onboardingComplete = false
    @AppStorage("nell.appearance") private var appearance = NellAppearancePreference.system.rawValue

    var body: some View {
        Group {
            if onboardingComplete {
                NellAppShellView()
            } else {
                NellOnboardingView(isComplete: $onboardingComplete)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        NellAppearancePreference(rawValue: appearance)?.colorScheme
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview.container)
}
