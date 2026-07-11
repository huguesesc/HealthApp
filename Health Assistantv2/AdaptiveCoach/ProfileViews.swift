import Foundation
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthProfile.createdAt, order: .forward) private var profiles: [HealthProfile]

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Group {
            if let profile = profiles.first {
                ProfileForm(profile: profile)
            } else {
                ProgressView("Preparing your profile…")
                    .task { _ = repo.currentProfile() }
            }
        }
        .navigationTitle("Profile & coaching")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileForm: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: HealthProfile
    @State private var savedMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section {
                Picker("Units", selection: $profile.unitSystemRaw) {
                    ForEach(CoachUnitSystem.allCases) { unit in
                        Text(unit.displayName).tag(unit.rawValue)
                    }
                }

                Picker("Primary goal", selection: $profile.primaryGoalRaw) {
                    ForEach(CoachGoal.allCases) { goal in
                        Text(goal.displayName).tag(goal.rawValue)
                    }
                }

                if profile.primaryGoal == .custom || profile.primaryGoal == .returnToSport {
                    TextField("Goal details", text: goalDetailBinding, axis: .vertical)
                        .lineLimit(2...4)
                }

                Picker("Experience", selection: $profile.experienceLevelRaw) {
                    ForEach(CoachExperienceLevel.allCases) { level in
                        Text(level.displayName).tag(level.rawValue)
                    }
                }
            } header: {
                Text("Training profile")
            } footer: {
                Text("These details help the assistant make realistic suggestions. You remain in control of every saved plan or change.")
            }

            Section("Availability") {
                Stepper(
                    "Training days per week: \(profile.weeklyTrainingDays ?? 3)",
                    value: weeklyDaysBinding,
                    in: 1...7
                )
                Stepper(
                    "Preferred session: \(profile.preferredSessionMinutes ?? 45) min",
                    value: sessionMinutesBinding,
                    in: 10...180,
                    step: 5
                )
            }

            Section("Preferences") {
                TextField(
                    "Preferred activities, separated by commas",
                    text: activitiesBinding,
                    axis: .vertical
                )
                .lineLimit(2...4)

                TextField(
                    "General preferences",
                    text: preferencesBinding,
                    axis: .vertical
                )
                .lineLimit(2...5)

                TextField("Private notes", text: notesBinding, axis: .vertical)
                    .lineLimit(2...5)
            }

            Section("Your information") {
                NavigationLink {
                    HealthConsiderationsView()
                } label: {
                    Label("Movement considerations", systemImage: "figure.mind.and.body")
                }

                NavigationLink {
                    BodyMetricsView()
                } label: {
                    Label("Body measurements", systemImage: "scalemass")
                }

                NavigationLink {
                    WorkoutLocationsView()
                } label: {
                    Label("Workout locations & equipment", systemImage: "mappin.and.ellipse")
                }
            }

            if let savedMessage {
                Section {
                    Label(savedMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.moss)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    repo.profileDidChange(profile)
                    savedMessage = "Profile saved on this device."
                }
            }
        }
    }

    private var weeklyDaysBinding: Binding<Int> {
        Binding(
            get: { profile.weeklyTrainingDays ?? 3 },
            set: { profile.weeklyTrainingDays = $0 }
        )
    }

    private var sessionMinutesBinding: Binding<Int> {
        Binding(
            get: { profile.preferredSessionMinutes ?? 45 },
            set: { profile.preferredSessionMinutes = $0 }
        )
    }

    private var goalDetailBinding: Binding<String> {
        optionalStringBinding(\.goalDetail)
    }

    private var activitiesBinding: Binding<String> {
        optionalStringBinding(\.preferredActivitiesText)
    }

    private var preferencesBinding: Binding<String> {
        optionalStringBinding(\.generalPreferences)
    }

    private var notesBinding: Binding<String> {
        optionalStringBinding(\.notes)
    }

    private func optionalStringBinding(
        _ keyPath: ReferenceWritableKeyPath<HealthProfile, String?>
    ) -> Binding<String> {
        Binding(
            get: { profile[keyPath: keyPath] ?? "" },
            set: { profile[keyPath: keyPath] = $0.nilIfBlank }
        )
    }
}

// MARK: - Health considerations

struct HealthConsiderationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HealthConsideration.updatedAt, order: .reverse)
    private var considerations: [HealthConsideration]

    @State private var showingEditor = false
    @State private var editingConsideration: HealthConsideration?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        List {
            Section {
                if active.isEmpty {
                    ContentUnavailableView(
                        "No considerations yet",
                        systemImage: "figure.mind.and.body",
                        description: Text("Add anything you want future workout suggestions to account for.")
                    )
                } else {
                    ForEach(active, id: \.id) { item in
                        considerationRow(item)
                            .swipeActions(edge: .trailing) {
                                Button("Archive") { repo.archiveConsideration(item) }
                                    .tint(.secondary)
                            }
                    }
                }
            } header: {
                Text("Active")
            } footer: {
                Text("These are your own reports and preferences, not medical assessments. The assistant may use them only for conservative adjustments.")
            }

            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived, id: \.id) { item in
                        considerationRow(item)
                    }
                }
            }
        }
        .navigationTitle("Movement considerations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingConsideration = nil
                    showingEditor = true
                } label: {
                    Label("Add consideration", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                HealthConsiderationEditorView(consideration: editingConsideration)
            }
        }
    }

    private var active: [HealthConsideration] {
        considerations.filter { $0.status != .archived }
    }

    private var archived: [HealthConsideration] {
        considerations.filter { $0.status == .archived }
    }

    private func considerationRow(_ item: HealthConsideration) -> some View {
        Button {
            editingConsideration = item
            showingEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(item.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text([item.side == .unspecified ? nil : item.side.displayName, item.bodyArea.displayName, item.category.displayName]
                    .compactMap { $0 }
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.moss)
                Text(item.userDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}

private struct HealthConsiderationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let consideration: HealthConsideration?

    @State private var title: String
    @State private var bodyAreaRaw: String
    @State private var sideRaw: String
    @State private var categoryRaw: String
    @State private var descriptionText: String
    @State private var statusRaw: String
    @State private var approximateWhen: String
    @State private var guidance: String

    init(consideration: HealthConsideration?) {
        self.consideration = consideration
        _title = State(initialValue: consideration?.title ?? "")
        _bodyAreaRaw = State(initialValue: consideration?.bodyAreaRaw ?? HealthBodyArea.other.rawValue)
        _sideRaw = State(initialValue: consideration?.sideRaw ?? BodySide.unspecified.rawValue)
        _categoryRaw = State(initialValue: consideration?.categoryRaw ?? HealthConsiderationCategory.custom.rawValue)
        _descriptionText = State(initialValue: consideration?.userDescription ?? "")
        _statusRaw = State(initialValue: consideration?.statusRaw ?? HealthConsiderationStatus.active.rawValue)
        _approximateWhen = State(initialValue: consideration?.approximateWhen ?? "")
        _guidance = State(initialValue: consideration?.userGuidance ?? "")
    }

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("What should the coach account for?") {
                TextField("Short title, e.g. Left knee", text: $title)

                Picker("Body area", selection: $bodyAreaRaw) {
                    ForEach(HealthBodyArea.allCases) { area in
                        Text(area.displayName).tag(area.rawValue)
                    }
                }

                Picker("Side", selection: $sideRaw) {
                    ForEach(BodySide.allCases) { side in
                        Text(side.displayName).tag(side.rawValue)
                    }
                }

                Picker("Type", selection: $categoryRaw) {
                    ForEach(HealthConsiderationCategory.allCases) { category in
                        Text(category.displayName).tag(category.rawValue)
                    }
                }
            }

            Section {
                TextEditor(text: $descriptionText)
                    .frame(minHeight: 100)
            } header: {
                Text("Your description")
            } footer: {
                Text("Use your own words. The app stores this as a user-reported fact, not a diagnosis.")
            }

            Section("Optional context") {
                TextField("When, approximately", text: $approximateWhen)
                TextField("Guidance you were given", text: $guidance, axis: .vertical)
                    .lineLimit(2...5)
                Picker("Status", selection: $statusRaw) {
                    ForEach(HealthConsiderationStatus.allCases) { status in
                        Text(status.displayName).tag(status.rawValue)
                    }
                }
            }
        }
        .navigationTitle(consideration == nil ? "Add consideration" : "Edit consideration")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmed.isEmpty || descriptionText.trimmed.isEmpty)
            }
        }
    }

    private func save() {
        let area = HealthBodyArea(rawValue: bodyAreaRaw) ?? .other
        let side = BodySide(rawValue: sideRaw) ?? .unspecified
        let category = HealthConsiderationCategory(rawValue: categoryRaw) ?? .custom
        let status = HealthConsiderationStatus(rawValue: statusRaw) ?? .active

        if let consideration {
            consideration.title = title.trimmed
            consideration.bodyAreaRaw = area.rawValue
            consideration.sideRaw = side.rawValue
            consideration.categoryRaw = category.rawValue
            consideration.userDescription = descriptionText.trimmed
            consideration.statusRaw = status.rawValue
            consideration.approximateWhen = approximateWhen.nilIfBlank
            consideration.userGuidance = guidance.nilIfBlank
            repo.considerationDidChange(consideration)
        } else {
            repo.addConsideration(
                HealthConsideration(
                    title: title.trimmed,
                    bodyArea: area,
                    side: side,
                    category: category,
                    userDescription: descriptionText.trimmed,
                    status: status,
                    approximateWhen: approximateWhen.nilIfBlank,
                    userGuidance: guidance.nilIfBlank
                )
            )
        }
        dismiss()
    }
}

// MARK: - Body metrics

struct BodyMetricsView: View {
    @Query(sort: \BodyMetricEntry.timestamp, order: .reverse) private var entries: [BodyMetricEntry]
    @Query(sort: \HealthProfile.createdAt, order: .forward) private var profiles: [HealthProfile]
    @State private var showingAdd = false

    private var unitSystem: CoachUnitSystem { profiles.first?.unitSystem ?? .metric }

    var body: some View {
        List {
            Section("Current") {
                if let latest = entries.first {
                    metricRow(latest)
                    if let trendText {
                        Label(trendText, systemImage: "chart.line.uptrend.xyaxis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView(
                        "No measurements yet",
                        systemImage: "scalemass",
                        description: Text("Add a measurement to start a private on-device trend.")
                    )
                }
            }

            if !entries.isEmpty {
                Section("History") {
                    ForEach(entries, id: \.id) { entry in
                        metricRow(entry)
                    }
                }
            }
        }
        .navigationTitle("Body measurements")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add measurement", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                BodyMetricEditorView(unitSystem: unitSystem)
            }
        }
    }

    private func metricRow(_ entry: BodyMetricEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let weight = entry.weightKilograms {
                    Text(weightText(weight))
                        .font(.headline)
                }
                if let height = entry.heightCentimeters {
                    Text(heightText(height))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(entry.timestamp, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note = entry.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var trendText: String? {
        guard let latest = entries.first,
              let latestWeight = latest.weightKilograms,
              let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: latest.timestamp),
              let earlier = entries
                .filter({ $0.timestamp <= cutoff && $0.weightKilograms != nil })
                .max(by: { $0.timestamp < $1.timestamp }),
              let earlierWeight = earlier.weightKilograms else { return nil }

        let change = latestWeight - earlierWeight
        let displayed = unitSystem == .metric ? change : change * 2.204_622_621_8
        let unit = unitSystem == .metric ? "kg" : "lb"
        if abs(displayed) < 0.05 { return "Stable over roughly 30 days" }
        return String(format: "%+.1f %@ over roughly 30 days", displayed, unit)
    }

    private func weightText(_ kilograms: Double) -> String {
        if unitSystem == .metric {
            return String(format: "%.1f kg", kilograms)
        }
        return String(format: "%.1f lb", kilograms * 2.204_622_621_8)
    }

    private func heightText(_ centimeters: Double) -> String {
        if unitSystem == .metric {
            return String(format: "%.0f cm", centimeters)
        }
        let totalInches = Int((centimeters / 2.54).rounded())
        return "\(totalInches / 12) ft \(totalInches % 12) in"
    }
}

private struct BodyMetricEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let unitSystem: CoachUnitSystem

    @State private var date = Date.now
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var note = ""
    @State private var validationMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("Measurement") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField(
                    unitSystem == .metric ? "Weight (kg)" : "Weight (lb)",
                    text: $weightText
                )
                .keyboardType(.decimalPad)

                TextField(
                    unitSystem == .metric ? "Height (cm)" : "Height (inches)",
                    text: $heightText
                )
                .keyboardType(.decimalPad)
            }

            Section {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(2...4)
            } footer: {
                Text("Measurements are stored locally. BMI is not stored; it can be derived later if you choose to view it.")
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(Theme.clay)
                }
            }
        }
        .navigationTitle("Add measurement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
    }

    private func save() {
        let parsedWeight = parseNumber(weightText)
        let parsedHeight = parseNumber(heightText)
        guard parsedWeight != nil || parsedHeight != nil else {
            validationMessage = "Enter a weight, a height, or both."
            return
        }

        let weightKilograms = parsedWeight.map {
            unitSystem == .metric ? $0 : $0 / 2.204_622_621_8
        }
        let heightCentimeters = parsedHeight.map {
            unitSystem == .metric ? $0 : $0 * 2.54
        }

        if let weightKilograms, weightKilograms <= 0 {
            validationMessage = "Weight must be greater than zero."
            return
        }
        if let heightCentimeters, heightCentimeters <= 0 {
            validationMessage = "Height must be greater than zero."
            return
        }

        repo.addBodyMetric(
            BodyMetricEntry(
                timestamp: date,
                weightKilograms: weightKilograms,
                heightCentimeters: heightCentimeters,
                note: note.nilIfBlank
            )
        )
        dismiss()
    }

    private func parseNumber(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: ".").trimmed)
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(PersistenceController.preview.container)
}
