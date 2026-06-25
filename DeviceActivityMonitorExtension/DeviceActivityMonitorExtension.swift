import DeviceActivity
import Foundation

/// Runs in its own sandbox. iOS calls these methods as monitored usage crosses the
/// schedule and event thresholds configured by the main app. The only thing this
/// extension shares back is a coarse boolean via the App Group — raw per-app
/// durations never leave the system.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    private let defaults = UserDefaults(suiteName: AppGroupID.identifier)

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // New day window — reset the signal.
        defaults?.set(false, forKey: AppGroupID.Key.exceededLimit)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        // The user passed their configured limit on the selected apps today.
        defaults?.set(true, forKey: AppGroupID.Key.exceededLimit)
        defaults?.set(Date(), forKey: AppGroupID.Key.lastUpdated)
    }
}

/// The extension target can't see the app's `AppGroup`; keep the identifiers in
/// sync with `Sources/Shared/AppGroup.swift`.
enum AppGroupID {
    static let identifier = "group.com.example.healthassistant"
    enum Key {
        static let exceededLimit = "screenTime.exceededLimit"
        static let thresholdMinutes = "screenTime.thresholdMinutes"
        static let lastUpdated = "screenTime.lastUpdated"
    }
}
