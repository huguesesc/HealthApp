#if DEBUG
import SwiftUI

/// DEBUG-only catalogue inspector (T24). Lists every exercise with stable ID,
/// names, equipment, capabilities, lifecycle, and media state, and exposes
/// diagnostic filters for incomplete or missing data. Compiled out of Release
/// builds entirely; never reachable from release navigation.
struct ExerciseCatalogDebugGalleryView: View {
    enum DiagnosticFilter: String, CaseIterable, Identifiable {
        case all
        case missingMedia = "Missing media"
        case inactiveLifecycle = "Deprecated/disabled"
        case hasHiddenLegacyNames = "Hidden legacy names"
        case incompleteInstructions = "Thin instructions"

        var id: String { rawValue }
    }

    @State private var state: ExerciseCatalogScreenState = .loading
    @State private var filter: DiagnosticFilter = .all
    @State private var reloadID = 0

    private let repository: any ExerciseCatalogRepositoryProviding

    init(repository: any ExerciseCatalogRepositoryProviding = BundledExerciseCatalogRepository()) {
        self.repository = repository
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Loading catalogue…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .available(let content):
                galleryList(content)
            case .unavailable(let message):
                VStack(spacing: Theme.Spacing.sm) {
                    Text(message)
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.destructive)
                    Button("Retry") {
                        state = .loading
                        reloadID += 1
                    }
                }
                .padding(NellLayout.screenPadding)
            }
        }
        .background(NellPalette.background)
        .navigationTitle("Debug Catalogue")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadID) { await load() }
    }

    private func galleryList(_ content: ExerciseCatalogContent) -> some View {
        let rows = filtered(content.exercises)
        return List {
            Section("Diagnostic filter") {
                Picker("Filter", selection: $filter) {
                    ForEach(DiagnosticFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Text("\(rows.count) of \(content.exercises.count) entries")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            Section("Entries") {
                ForEach(rows, id: \.id) { exercise in
                    NavigationLink {
                        ExerciseCatalogDebugDetailView(definition: exercise)
                    } label: {
                        debugRow(exercise)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func debugRow(_ exercise: ExerciseDefinition) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(exercise.displayName)
                .font(Theme.FontToken.cardTitle)
                .foregroundStyle(NellPalette.textPrimary)
            Text(exercise.id.rawValue)
                .font(Theme.FontToken.caption.monospaced())
                .foregroundStyle(NellPalette.textTertiary)
                .textSelection(.enabled)

            HStack(spacing: Theme.Spacing.xs) {
                NellStatusChip(
                    title: ExerciseCatalogLabel.text(exercise.lifecycle.status.rawValue),
                    tone: exercise.lifecycle.status == .active ? .positive : .attention
                )
                mediaStateChip(exercise)
                if let aliases = exercise.aliases, !aliases.isEmpty {
                    NellStatusChip(title: "\(aliases.count) aliases", tone: .neutral)
                }
                if let legacyNames = exercise.legacyNames, !legacyNames.isEmpty {
                    NellStatusChip(
                        title: "\(legacyNames.count) hidden legacy",
                        tone: .informational
                    )
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }

    @ViewBuilder
    private func mediaStateChip(_ exercise: ExerciseDefinition) -> some View {
        if (exercise.media ?? []).isEmpty {
            NellStatusChip(title: "no media", tone: .neutral)
        } else {
            NellStatusChip(title: "media declared", tone: .positive)
        }
    }

    private func filtered(_ exercises: [ExerciseDefinition]) -> [ExerciseDefinition] {
        exercises.sorted { $0.id.rawValue < $1.id.rawValue }.filter { exercise in
            switch filter {
            case .all:
                true
            case .missingMedia:
                (exercise.media ?? []).isEmpty
            case .inactiveLifecycle:
                exercise.lifecycle.status != .active
            case .hasHiddenLegacyNames:
                !(exercise.legacyNames ?? []).isEmpty
            case .incompleteInstructions:
                exercise.instructions.count < 2
                    || exercise.instructions.contains {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
            }
        }
    }

    private func load() async {
        let catalogState = await repository.loadState()
        switch catalogState {
        case .available(let manifest):
            state = .available(
                ExerciseCatalogContent(
                    exercises: manifest.exercises,
                    equipmentTaxonomy: (try? BundledExerciseCandidateTaxonomies.load())?
                        .equipment ?? EquipmentTaxonomy(schemaVersion: 1, equipment: []),
                    environmentTaxonomy: (try? BundledExerciseCandidateTaxonomies.load())?
                        .environments ?? ExerciseEnvironmentTaxonomy(
                            schemaVersion: 1,
                            environments: []
                        )
                )
            )
        case .unavailable(let error):
            state = .unavailable(String(describing: error))
        }
    }
}

private struct ExerciseCatalogDebugDetailView: View {
    let definition: ExerciseDefinition

    var body: some View {
        List {
            Section("Identity") {
                labeledRow("Stable ID", definition.id.rawValue)
                if let legacyIDs = definition.legacyIDs, !legacyIDs.isEmpty {
                    labeledRow("Legacy IDs", legacyIDs.map(\.rawValue).joined(separator: ", "))
                }
            }
            Section("Names") {
                labeledRow("Display", definition.displayName)
                labeledRow("Aliases", (definition.aliases ?? []).joined(separator: ", "))
                labeledRow(
                    "Hidden legacy names",
                    (definition.legacyNames ?? []).joined(separator: ", ")
                )
            }
            Section("Classification") {
                labeledRow("Category", definition.category.rawValue)
                labeledRow("Movement pattern", definition.movementPattern.rawValue)
                labeledRow("Type", definition.exerciseType.rawValue)
                labeledRow("Tracking", definition.trackingMode.rawValue)
                labeledRow(
                    "Lifecycle",
                    ExerciseCatalogLabel.text(definition.lifecycle.status.rawValue)
                        + (definition.lifecycle.replacementExerciseID.map {
                            " → \($0.rawValue)"
                        } ?? "")
                )
            }
            Section("Equipment & environment") {
                labeledRow(
                    "Required",
                    definition.equipment.required
                        .map { "\($0.id.rawValue)×\($0.quantity)" }
                        .joined(separator: " + ")
                )
                labeledRow(
                    "Alternatives",
                    definition.equipment.alternatives
                        .map { group in
                            group.map { "\($0.id.rawValue)×\($0.quantity)" }
                                .joined(separator: " + ")
                        }
                        .joined(separator: " OR ")
                )
                labeledRow(
                    "Capabilities required",
                    (definition.environmentRequirements?.required ?? [])
                        .map(\.rawValue)
                        .joined(separator: ", ")
                )
                labeledRow(
                    "Capabilities prohibited",
                    (definition.environmentRequirements?.prohibited ?? [])
                        .map(\.rawValue)
                        .joined(separator: ", ")
                )
            }
            Section("Media") {
                let media = definition.media ?? []
                if media.isEmpty {
                    Text("No media declared — vector fallback renders")
                        .font(Theme.FontToken.caption)
                } else {
                    ForEach(media, id: \.key) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.key)
                                .font(Theme.FontToken.caption.monospaced())
                            Text("\(item.role.rawValue)\(item.sequence.map { " · seq \($0)" } ?? "")")
                                .font(Theme.FontToken.caption)
                                .foregroundStyle(NellPalette.textSecondary)
                        }
                    }
                }
            }
            Section {
                ExerciseMediaView(
                    media: definition.media,
                    fallbackTitle: definition.displayName,
                    presentation: .hero,
                    resolver: ExerciseCatalogDetailView.productionMediaResolver()
                )
            } header: {
                Text("Rendered media / fallback preview")
            }
        }
        .navigationTitle(definition.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeledRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)
            Text(value.isEmpty ? "—" : value)
                .font(Theme.FontToken.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

#Preview("Debug catalogue gallery") {
    NavigationStack {
        ExerciseCatalogDebugGalleryView()
    }
}
#endif
