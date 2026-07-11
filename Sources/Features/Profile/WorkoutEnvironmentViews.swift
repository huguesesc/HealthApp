import Foundation
import SwiftData
import SwiftUI

struct WorkoutLocationsView: View {
    @Query(sort: \WorkoutLocation.updatedAt, order: .reverse) private var locations: [WorkoutLocation]
    @State private var showingNewLocation = false

    var body: some View {
        List {
            Section {
                if activeLocations.isEmpty {
                    ContentUnavailableView(
                        "No workout locations",
                        systemImage: "mappin.and.ellipse",
                        description: Text("Add Home, a gym, or another place so plans can use only equipment you actually have.")
                    )
                } else {
                    ForEach(activeLocations, id: \.id) { location in
                        NavigationLink {
                            WorkoutLocationEditorView(location: location)
                        } label: {
                            locationRow(location)
                        }
                    }
                }
            } header: {
                Text("Active locations")
            } footer: {
                Text("Locations and equipment are stored on this device and can be shared with the assistant as compact context.")
            }

            if !archivedLocations.isEmpty {
                Section("Archived") {
                    ForEach(archivedLocations, id: \.id) { location in
                        NavigationLink {
                            WorkoutLocationEditorView(location: location)
                        } label: {
                            locationRow(location)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout locations")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewLocation = true
                } label: {
                    Label("Add location", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewLocation) {
            NavigationStack { NewWorkoutLocationView() }
        }
    }

    private var activeLocations: [WorkoutLocation] {
        locations.filter(\.isActive)
    }

    private var archivedLocations: [WorkoutLocation] {
        locations.filter { !$0.isActive }
    }

    private func locationRow(_ location: WorkoutLocation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: location.category.systemImage)
                .foregroundStyle(location.isActive ? Theme.evergreen : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.headline)
                Text("\(location.equipment.filter(\.isAvailable).count) available item(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct NewWorkoutLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var categoryRaw = WorkoutLocationCategory.home.rawValue
    @State private var notes = ""
    @State private var spaceLimitations = ""

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("Location") {
                TextField("Name, e.g. Home", text: $name)
                Picker("Type", selection: $categoryRaw) {
                    ForEach(WorkoutLocationCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.systemImage)
                            .tag(category.rawValue)
                    }
                }
            }

            Section("Optional context") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Space or setup limitations", text: $spaceLimitations, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
        .navigationTitle("Add location")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmed.isEmpty)
            }
        }
    }

    private func save() {
        repo.addLocation(
            WorkoutLocation(
                name: name.trimmed,
                category: WorkoutLocationCategory(rawValue: categoryRaw) ?? .custom,
                notes: notes.optionalTrimmed,
                spaceLimitations: spaceLimitations.optionalTrimmed
            )
        )
        dismiss()
    }
}

struct WorkoutLocationEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var location: WorkoutLocation

    @State private var showingEquipmentEditor = false
    @State private var editingEquipment: EquipmentItem?
    @State private var savedMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("Location") {
                TextField("Name", text: $location.name)
                Picker("Type", selection: $location.categoryRaw) {
                    ForEach(WorkoutLocationCategory.allCases) { category in
                        Text(category.displayName).tag(category.rawValue)
                    }
                }
                TextField("Notes", text: notesBinding, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Space or setup limitations", text: limitationsBinding, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section {
                if sortedEquipment.isEmpty {
                    Text("No equipment added yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedEquipment, id: \.id) { item in
                        equipmentRow(item)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", role: .destructive) {
                                    repo.removeEquipment(item)
                                }
                            }
                    }
                }

                Button {
                    editingEquipment = nil
                    showingEquipmentEditor = true
                } label: {
                    Label("Add equipment", systemImage: "plus")
                }
            } header: {
                Text("Equipment")
            } footer: {
                Text("Unavailable items stay in your inventory but are omitted from normal assistant context.")
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.category.rawValue) { suggestion in
                            Button {
                                addSuggestion(suggestion)
                            } label: {
                                Label(suggestion.name, systemImage: "plus.circle")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        Color(.tertiarySystemGroupedBackground),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(hasSuggestion(suggestion))
                        }
                    }
                }
            } header: {
                Text("Quick suggestions")
            } footer: {
                Text("Suggestions are saved only when you tap them.")
            }

            Section {
                Button(location.isActive ? "Archive location" : "Restore location") {
                    if location.isActive {
                        repo.archiveLocation(location)
                    } else {
                        repo.restoreLocation(location)
                    }
                }
                .foregroundStyle(location.isActive ? Theme.clay : Theme.evergreen)
            }

            if let savedMessage {
                Section {
                    Label(savedMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.moss)
                }
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    location.name = location.name.trimmed
                    repo.locationDidChange(location)
                    savedMessage = "Location saved."
                }
                .disabled(location.name.trimmed.isEmpty)
            }
        }
        .sheet(isPresented: $showingEquipmentEditor) {
            NavigationStack {
                EquipmentEditorView(location: location, equipment: editingEquipment)
            }
        }
    }

    private var sortedEquipment: [EquipmentItem] {
        location.equipment.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { location.notes ?? "" },
            set: { location.notes = $0.optionalTrimmed }
        )
    }

    private var limitationsBinding: Binding<String> {
        Binding(
            get: { location.spaceLimitations ?? "" },
            set: { location.spaceLimitations = $0.optionalTrimmed }
        )
    }

    private func equipmentRow(_ item: EquipmentItem) -> some View {
        Button {
            editingEquipment = item
            showingEquipmentEditor = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isAvailable ? "checkmark.circle.fill" : "circle.slash")
                    .foregroundStyle(item.isAvailable ? Theme.moss : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Text(equipmentDetail(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func equipmentDetail(_ item: EquipmentItem) -> String {
        var parts = [item.category.displayName]
        if let min = item.minWeightKilograms, let max = item.maxWeightKilograms {
            parts.append(String(format: "%.0f–%.0f kg", min, max))
        } else if let max = item.maxWeightKilograms {
            parts.append(String(format: "up to %.0f kg", max))
        }
        if let resistance = item.resistanceDescription, !resistance.isEmpty {
            parts.append(resistance)
        }
        return parts.joined(separator: " · ")
    }

    private var suggestions: [EquipmentSuggestion] {
        switch location.category {
        case .home:
            EquipmentSuggestion.home
        case .gym:
            EquipmentSuggestion.gym
        default:
            EquipmentSuggestion.general
        }
    }

    private func hasSuggestion(_ suggestion: EquipmentSuggestion) -> Bool {
        location.equipment.contains {
            $0.categoryRaw == suggestion.category.rawValue
                || $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame
        }
    }

    private func addSuggestion(_ suggestion: EquipmentSuggestion) {
        guard !hasSuggestion(suggestion) else { return }
        repo.addEquipment(
            EquipmentItem(name: suggestion.name, category: suggestion.category),
            to: location
        )
    }
}

private struct EquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let location: WorkoutLocation
    let equipment: EquipmentItem?

    @State private var categoryRaw: String
    @State private var name: String
    @State private var quantity: Int
    @State private var minimumWeight: String
    @State private var maximumWeight: String
    @State private var resistance: String
    @State private var isAvailable: Bool
    @State private var notes: String
    @State private var validationMessage: String?

    init(location: WorkoutLocation, equipment: EquipmentItem?) {
        self.location = location
        self.equipment = equipment
        _categoryRaw = State(initialValue: equipment?.categoryRaw ?? EquipmentCategory.custom.rawValue)
        _name = State(initialValue: equipment?.name ?? "")
        _quantity = State(initialValue: equipment?.quantity ?? 1)
        _minimumWeight = State(initialValue: equipment?.minWeightKilograms.map { String(format: "%.1f", $0) } ?? "")
        _maximumWeight = State(initialValue: equipment?.maxWeightKilograms.map { String(format: "%.1f", $0) } ?? "")
        _resistance = State(initialValue: equipment?.resistanceDescription ?? "")
        _isAvailable = State(initialValue: equipment?.isAvailable ?? true)
        _notes = State(initialValue: equipment?.notes ?? "")
    }

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Form {
            Section("Equipment") {
                Picker("Type", selection: $categoryRaw) {
                    ForEach(EquipmentCategory.allCases) { category in
                        Text(category.displayName).tag(category.rawValue)
                    }
                }
                .onChange(of: categoryRaw) { _, newValue in
                    guard name.trimmed.isEmpty,
                          let category = EquipmentCategory(rawValue: newValue),
                          category != .custom else { return }
                    name = category.displayName
                }

                TextField("Name", text: $name)
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                Toggle("Currently available", isOn: $isAvailable)
            }

            Section("Load or resistance") {
                TextField("Minimum weight (kg)", text: $minimumWeight)
                    .keyboardType(.decimalPad)
                TextField("Maximum weight (kg)", text: $maximumWeight)
                    .keyboardType(.decimalPad)
                TextField("Resistance details, e.g. light and medium bands", text: $resistance, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Notes") {
                TextField("Setup, condition, or limitations", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(Theme.clay)
                }
            }
        }
        .navigationTitle(equipment == nil ? "Add equipment" : "Edit equipment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmed.isEmpty)
            }
        }
    }

    private func save() {
        let minWeight = parseNumber(minimumWeight)
        let maxWeight = parseNumber(maximumWeight)
        if let minWeight, let maxWeight, minWeight > maxWeight {
            validationMessage = "Minimum weight cannot be greater than maximum weight."
            return
        }

        let category = EquipmentCategory(rawValue: categoryRaw) ?? .custom
        if let equipment {
            equipment.name = name.trimmed
            equipment.categoryRaw = category.rawValue
            equipment.quantity = quantity
            equipment.minWeightKilograms = minWeight
            equipment.maxWeightKilograms = maxWeight
            equipment.resistanceDescription = resistance.optionalTrimmed
            equipment.isAvailable = isAvailable
            equipment.notes = notes.optionalTrimmed
            repo.equipmentDidChange(equipment)
        } else {
            repo.addEquipment(
                EquipmentItem(
                    name: name.trimmed,
                    category: category,
                    quantity: quantity,
                    minWeightKilograms: minWeight,
                    maxWeightKilograms: maxWeight,
                    resistanceDescription: resistance.optionalTrimmed,
                    isAvailable: isAvailable,
                    notes: notes.optionalTrimmed
                ),
                to: location
            )
        }
        dismiss()
    }

    private func parseNumber(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmed)
    }
}

private struct EquipmentSuggestion {
    let name: String
    let category: EquipmentCategory

    static let home: [EquipmentSuggestion] = [
        .init(name: "Yoga mat", category: .yogaMat),
        .init(name: "Stability ball", category: .stabilityBall),
        .init(name: "Mini resistance bands", category: .miniResistanceBands),
        .init(name: "Long resistance bands", category: .longResistanceBands),
        .init(name: "Foam balance pad", category: .foamBalancePad),
        .init(name: "Wobble board", category: .wobbleBoard),
        .init(name: "Dumbbells", category: .dumbbells),
    ]

    static let gym: [EquipmentSuggestion] = [
        .init(name: "Squat rack", category: .squatRack),
        .init(name: "Cable station", category: .cableStation),
        .init(name: "Leg press", category: .legPress),
        .init(name: "Hamstring curl", category: .hamstringCurl),
        .init(name: "Stationary bike", category: .stationaryBike),
        .init(name: "Treadmill", category: .treadmill),
    ]

    static let general: [EquipmentSuggestion] = [
        .init(name: "Bodyweight", category: .bodyweight),
        .init(name: "Yoga mat", category: .yogaMat),
        .init(name: "Resistance bands", category: .longResistanceBands),
    ]
}

private extension String {
    var optionalTrimmed: String? {
        let cleaned = trimmed
        return cleaned.isEmpty ? nil : cleaned
    }
}

#Preview {
    NavigationStack { WorkoutLocationsView() }
        .modelContainer(PersistenceController.preview.container)
}
