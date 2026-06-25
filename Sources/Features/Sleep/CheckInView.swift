import SwiftData
import SwiftUI

/// Short daily self-report: energy, mood, soreness, focus, stress, plus a note.
struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]

    @State private var energy = 3
    @State private var mood = 3
    @State private var soreness = 3
    @State private var focus = 3
    @State private var stress = 3
    @State private var note = ""

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("How do you feel today?") {
                Stepper("Energy: \(energy)/5", value: $energy, in: 1...5)
                Stepper("Mood: \(mood)/5", value: $mood, in: 1...5)
                Stepper("Soreness: \(soreness)/5", value: $soreness, in: 1...5)
                Stepper("Focus: \(focus)/5", value: $focus, in: 1...5)
                Stepper("Stress: \(stress)/5", value: $stress, in: 1...5)
            }

            Section("Note") {
                TextField("Anything worth remembering", text: $note, axis: .vertical)
            }

            Section {
                Button("Save check-in", action: save)
            }

            Section("History") {
                if checkIns.isEmpty {
                    Text("No check-ins yet.").foregroundStyle(.secondary)
                }
                ForEach(checkIns) { checkIn in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(checkIn.date, style: .date)
                        Text(detail(checkIn))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let note = checkIn.note, !note.isEmpty {
                            Text(note).font(.caption).italic()
                        }
                    }
                }
            }
        }
        .navigationTitle("Check-in")
    }

    private func detail(_ checkIn: DailyCheckIn) -> String {
        var parts: [String] = []
        if let energy = checkIn.energy { parts.append("energy \(energy)") }
        if let mood = checkIn.mood { parts.append("mood \(mood)") }
        if let stress = checkIn.stress { parts.append("stress \(stress)") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    private func save() {
        let checkIn = DailyCheckIn(
            energy: energy,
            mood: mood,
            soreness: soreness,
            focus: focus,
            stress: stress,
            note: note.trimmed.isEmpty ? nil : note.trimmed
        )
        repo.addCheckIn(checkIn)
        note = ""
    }
}

#Preview {
    NavigationStack { CheckInView() }
        .modelContainer(PersistenceController.preview.container)
}
