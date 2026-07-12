import SwiftData
import SwiftUI

/// App root using Nell's first-run experience and five-destination navigation.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("nell.onboarding.completed") private var onboardingComplete = false
    @AppStorage("nell.appearance") private var appearance = NellAppearancePreference.system.rawValue

    var body: some View {
        Group {
            if onboardingComplete {
                NellAppShellView()
                    .task {
                        NellOnboardingProfileSynchronizer.synchronize(
                            context: modelContext,
                            force: false
                        )
                    }
            } else {
                NellOnboardingView(isComplete: onboardingBinding)
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }

    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { onboardingComplete },
            set: { completed in
                if completed {
                    NellOnboardingProfileSynchronizer.synchronize(
                        context: modelContext,
                        force: true
                    )
                }
                onboardingComplete = completed
            }
        )
    }

    private var preferredColorScheme: ColorScheme? {
        NellAppearancePreference(rawValue: appearance)?.colorScheme
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.preview.container)
}
