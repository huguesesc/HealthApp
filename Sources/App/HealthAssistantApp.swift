import SwiftData
import SwiftUI

@main
struct HealthAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.demoOrSharedContainer())
    }

    /// Screenshot CI runs against a disposable in-memory store so real user
    /// data is never touched; production always uses the shared store.
    private static func demoOrSharedContainer() -> ModelContainer {
        #if DEBUG
        if NellScreenshotDemo.isActive {
            return NellScreenshotDemo.makeContainer()
        }
        #endif
        return PersistenceController.shared.container
    }
}
