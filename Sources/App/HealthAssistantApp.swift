import SwiftData
import SwiftUI

@main
struct HealthAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PersistenceController.shared.container)
    }
}
