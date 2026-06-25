import FamilyControls
import SwiftUI

/// Lets the user authorize, pick apps/categories, and set a daily threshold.
/// Presented inside the dashboard's navigation stack, so it has no `NavigationStack`
/// of its own. Screen Time is optional — the rest of the app works without it.
struct ScreenTimeView: View {
    @State private var service = ScreenTimeService()
    @State private var showingPicker = false

    var body: some View {
        Form {
            if !service.isAuthorized {
                Section {
                    Text("Habit awareness uses Apple's Screen Time API. Precise "
                        + "per-app numbers stay private to the system — the app only "
                        + "learns whether you crossed your own limit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Authorize Screen Time") {
                        Task { await service.requestAuthorization() }
                    }
                }
            } else {
                Section("Apps & categories to watch") {
                    Button("Choose apps") { showingPicker = true }
                }
                Section("Daily limit") {
                    Stepper(
                        "\(service.thresholdMinutes) minutes",
                        value: $service.thresholdMinutes,
                        in: 15...480,
                        step: 15
                    )
                    Button("Start monitoring") {
                        try? service.startMonitoring()
                    }
                }
                Section("Today") {
                    Label(
                        service.todaysExceededLimit() ? "Limit exceeded" : "Within limit",
                        systemImage: service.todaysExceededLimit()
                            ? "exclamationmark.triangle" : "checkmark.circle"
                    )
                }
            }
        }
        .navigationTitle("Habits")
        .familyActivityPicker(isPresented: $showingPicker, selection: $service.selection)
    }
}
