import SwiftData
import SwiftUI

/// Manual sleep logging. HealthKit / Apple Watch can populate `SleepEntry`
/// automatically in a later milestone; the model and this screen don't change.
struct SleepEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SleepEntry.date, order: .reverse) private var entries: [SleepEntry]

    @State private var bedtime = Date()
    @State private var wakeTime = Date()
    @State private var quality = 3
    @State private var naps = ""
    @State private var tiredness = 3

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("Last night") {
                DatePicker("Bedtime", selection: $bedtime)
                DatePicker("Wake time", selection: $wakeTime)
                Stepper("Quality: \(quality)/5", value: $quality, in: 1...5)
                TextField("Nap minutes (optional)", text: $naps)
                    .keyboardType(.numberPad)
                Stepper("Tiredness on waking: \(tiredness)/5", value: $tiredness, in: 1...5)
                Button("Save sleep", action: save)
            }

            Section("History") {
                if entries.isEmpty {
                    Text("No sleep logged yet.").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date, style: .date)
                        Text(detail(entry))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Sleep")
    }

    private func detail(_ entry: SleepEntry) -> String {
        var parts: [String] = []
        if let quality = entry.perceivedQuality { parts.append("quality \(quality)/5") }
        if let bedtime = entry.bedtime, let wake = entry.wakeTime {
            let hours = wake.timeIntervalSince(bedtime) / 3600
            if hours > 0 { parts.append(String(format: "%.1f h", hours)) }
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func save() {
        let entry = SleepEntry(
            date: .now,
            bedtime: bedtime,
            wakeTime: wakeTime,
            perceivedQuality: quality,
            napMinutes: Int(naps),
            tiredness: tiredness
        )
        repo.addSleep(entry)
    }
}

#Preview {
    NavigationStack { SleepEntryView() }
        .modelContainer(PersistenceController.preview.container)
}
