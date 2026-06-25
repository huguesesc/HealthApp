import Foundation

/// Shared constants for the App Group that bridges the main app and the
/// DeviceActivityMonitor extension. Create this group in your Apple Developer
/// account and add the capability to both targets before the Screen Time bridge
/// works.
enum AppGroup {
    /// Must match the App Group identifier configured on both targets.
    static let identifier = "group.com.example.healthassistant"

    /// Keys written by the extension and read by the app.
    enum Key {
        static let exceededLimit = "screenTime.exceededLimit"
        static let thresholdMinutes = "screenTime.thresholdMinutes"
        static let lastUpdated = "screenTime.lastUpdated"
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    static var isConfigured: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }
}
