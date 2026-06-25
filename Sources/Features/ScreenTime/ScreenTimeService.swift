import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Coordinates Family Controls authorization, app selection, and the activity
/// schedule. The actual usage monitoring runs in the DeviceActivityMonitor
/// extension; this service sets it up and reads back the coarse signal.
///
/// Requires: the Family Controls entitlement (Apple approval) and a real device.
/// These APIs do nothing useful in the simulator.
@MainActor
@Observable
final class ScreenTimeService {
    var isAuthorized = false
    var selection = FamilyActivitySelection()
    var thresholdMinutes = 90

    private let center = AuthorizationCenter.shared
    private let activityName = DeviceActivityName("daily.habit.window")
    private let eventName = DeviceActivityEvent.Name("threshold.reached")

    /// Ask the user for individual (self-monitoring) authorization.
    func requestAuthorization() async {
        do {
            try await center.requestAuthorization(for: .individual)
            isAuthorized = center.authorizationStatus == .approved
        } catch {
            isAuthorized = false
        }
    }

    /// Schedule a daily window that fires the extension's `eventDidReachThreshold`
    /// callback once total usage of the selected apps passes `thresholdMinutes`.
    func startMonitoring() throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            threshold: DateComponents(minute: thresholdMinutes)
        )
        let monitor = DeviceActivityCenter()
        try monitor.startMonitoring(
            activityName,
            during: schedule,
            events: [eventName: event]
        )
    }

    /// The coarse signal the extension wrote to the shared App Group.
    func todaysExceededLimit() -> Bool {
        AppGroup.sharedDefaults?.bool(forKey: AppGroup.Key.exceededLimit) ?? false
    }
}
