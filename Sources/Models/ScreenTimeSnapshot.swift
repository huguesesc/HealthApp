import Foundation
import SwiftData

/// A coarse screen-time signal for a given day.
///
/// Apple's Screen Time API does not expose precise per-app durations to the main
/// app — raw data stays inside the DeviceActivity extension sandbox. This snapshot
/// holds only the coarse signal the extension is able to share via the App Group.
@Model
final class ScreenTimeSnapshot {
    var date: Date
    /// Whether the user crossed their configured threshold on selected apps today.
    var exceededLimit: Bool
    /// The threshold that was configured, in minutes (for context).
    var thresholdMinutes: Int?

    init(date: Date = .now, exceededLimit: Bool, thresholdMinutes: Int? = nil) {
        self.date = date
        self.exceededLimit = exceededLimit
        self.thresholdMinutes = thresholdMinutes
    }
}
