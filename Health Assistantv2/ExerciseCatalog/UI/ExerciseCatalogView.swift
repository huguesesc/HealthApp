import Foundation
import SwiftUI

struct ExerciseCatalogContent: Equatable, Sendable {
    let exercises: [ExerciseDefinition]
    let equipmentTaxonomy: EquipmentTaxonomy
    let environmentTaxonomy: ExerciseEnvironmentTaxonomy
}

struct ExerciseCatalogFilter: Equatable, Sendable {
    var query = ""
    var categoryID: String?
    var equipmentID: String?
    var environmentID: String?

    func results(in content: ExerciseCatalogContent) -> [ExerciseDefinition] {
        content.exercises
            .filter(matchesQuery)
            .filter { categoryID == nil || $0.category.rawValue == categoryID }
            .filter {
                guard let equipmentID else { return true }
                return $0.catalogEquipmentIDs.contains(equipmentID)
            }
            .filter {
                guard let environmentID else { return true }
                return Self.supports(
                    $0,
                    environmentID: environmentID,
                    taxonomy: content.environmentTaxonomy
                )
            }
            .sorted(by: Self.catalogOrder)
    }

    private func matchesQuery(_ exercise: ExerciseDefinition) -> Bool {
        let needle = Self.normalized(query)
        guard !needle.isEmpty else { return true }
        return ([exercise.displayName] + (exercise.aliases ?? []))
            .contains { Self.normalized($0).contains(needle) }
    }

    private static func supports(
        _ exercise: ExerciseDefinition,
        environmentID: String,
        taxonomy: ExerciseEnvironmentTaxonomy
    ) -> Bool {
        guard let environment = taxonomy.definition(
            for: ExerciseEnvironmentID(rawValue: environmentID)
        ) else {
            return false
        }
        let capabilities = Set(environment.defaultCapabilities.map(\.rawValue))
        let required = Set(exercise.environmentRequirements?.required.map(\.rawValue) ?? [])
        let prohibited = Set(exercise.environmentRequirements?.prohibited?.map(\.rawValue) ?? [])
        return required.isSubset(of: capabilities) && prohibited.isDisjoint(with: capabilities)
    }

    private static func catalogOrder(
        _ lhs: ExerciseDefinition,
        _ rhs: ExerciseDefinition
    ) -> Bool {
        let lhsLifecycle = lifecycleOrder(lhs.lifecycle.status)
        let rhsLifecycle = lifecycleOrder(rhs.lifecycle.status)
        if lhsLifecycle != rhsLifecycle { return lhsLifecycle < rhsLifecycle }
        let comparison = lhs.displayName.compare(
            rhs.displayName,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: nil,
            locale: Locale(identifier: "en_US_POSIX")
        )
        if comparison != .orderedSame { return comparison == .orderedAscending }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private static func lifecycleOrder(_ status: ExerciseLifecycleStatus) -> Int {
        switch status {
        case .active: 0
        case .deprecated: 1
        case .disabled: 2
        }
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
    }
}

private enum ExerciseCatalogScreenState: Equatable {
    case loading
    case available(ExerciseCatalogContent)
    case unavailable(String)
}

@MainActor
struct ExerciseCatalogView: View {
    private let repository: any ExerciseCatalogRepositoryProviding
    private let taxonomyLoader: @Sendable () throws -> BundledExerciseCandidateTaxonomies
    private let mediaResolver: any ExerciseMediaResolving

    @State private var state: ExerciseCatalogScreenState = .loading
    @State private var filter = ExerciseCatalogFilter()
    @State private var reloadID = 0

    init(
        repository: any ExerciseCatalogRepositoryProviding = BundledExerciseCatalogRepository(),
        taxonomyLoader: @escaping @Sendable () throws -> BundledExerciseCandidateTaxonomies = {
            try BundledExerciseCandidateTaxonomies.load()
        },
        mediaResolver: (any ExerciseMediaResolving)? = nil
    ) {
        self.repository = repository
        self.taxonomyLoader = taxonomyLoader
        self.mediaResolver = mediaResolver ?? ExerciseCatalogDetailView.productionMediaResolver()
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                loadingContent
            case .available(let content):
                loadedContent(content)
            case .unavailable(let message):
                errorContent(message)
            }
        }
        .navigationTitle("Exercise Catalogue")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $filter.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search exercises or aliases"
        )
        .task(id: reloadID) {
            await load()
        }
    }

    private var loadingContent: some View {
        NellScreen {
            heading
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<4, id: \.self) { _ in
                    ExerciseCatalogPlaceholderRow()
                }
            }
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func loadedContent(_ content: ExerciseCatalogContent) -> some View {
        let results = filter.results(in: content)
        NellScreen {
            heading
            filterControls(content)

            if content.exercises.isEmpty {
                NellEmptyState(
                    title: "No catalogue entries",
                    message: "The exercise catalogue loaded successfully but contains no exercises.",
                    systemImage: "books.vertical"
                )
            } else if results.isEmpty {
                NellEmptyState(
                    title: "No matching exercises",
                    message: "Try another search or clear one of the filters.",
                    systemImage: "magnifyingglass"
                )
            } else {
                NellSectionHeader(
                    title: "Exercises",
                    subtitle: "\(results.count) of \(content.exercises.count) shown"
                )
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(results, id: \.id) { exercise in
                        NavigationLink {
                            ExerciseCatalogDetailView(
                                definition: exercise,
                                mediaResolver: mediaResolver
                            )
                        } label: {
                            ExerciseCatalogRow(
                                exercise: exercise,
                                content: content,
                                mediaResolver: mediaResolver
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        NellScreen {
            heading
            NellErrorState(
                title: "Catalogue unavailable",
                message: message,
                retry: {
                    state = .loading
                    reloadID += 1
                }
            )
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Exercise Catalogue")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)
            Text("Search the written movement library and review equipment, location and tracking details.")
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private func filterControls(_ content: ExerciseCatalogContent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                catalogFilterMenu(
                    title: filter.categoryID.map(ExerciseCatalogLabel.text) ?? "Category",
                    systemImage: "square.grid.2x2",
                    selected: filter.categoryID != nil
                ) {
                    Button("All categories") { filter.categoryID = nil }
                    ForEach(categoryIDs(in: content), id: \.self) { id in
                        Button(ExerciseCatalogLabel.text(id)) { filter.categoryID = id }
                    }
                }

                catalogFilterMenu(
                    title: equipmentName(filter.equipmentID, content: content) ?? "Equipment",
                    systemImage: "dumbbell",
                    selected: filter.equipmentID != nil
                ) {
                    Button("All equipment") { filter.equipmentID = nil }
                    ForEach(equipmentIDs(in: content), id: \.self) { id in
                        Button(equipmentName(id, content: content) ?? ExerciseCatalogLabel.text(id)) {
                            filter.equipmentID = id
                        }
                    }
                }

                catalogFilterMenu(
                    title: environmentName(filter.environmentID, content: content) ?? "Location",
                    systemImage: "mappin.and.ellipse",
                    selected: filter.environmentID != nil
                ) {
                    Button("All locations") { filter.environmentID = nil }
                    ForEach(activeEnvironments(in: content), id: \.id) { environment in
                        Button(environment.displayName) { filter.environmentID = environment.id.rawValue }
                    }
                }

                if hasFilters {
                    Button("Clear") {
                        filter.categoryID = nil
                        filter.equipmentID = nil
                        filter.environmentID = nil
                    }
                    .font(Theme.FontToken.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.primary)
                    .frame(minHeight: NellLayout.minimumTouchTarget)
                }
            }
        }
        .accessibilityLabel("Catalogue filters")
    }

    private func catalogFilterMenu<Content: View>(
        title: String,
        systemImage: String,
        selected: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            Label(title, systemImage: systemImage)
                .font(Theme.FontToken.caption.weight(.semibold))
                .foregroundStyle(selected ? NellPalette.primary : NellPalette.textSecondary)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(minHeight: NellLayout.minimumTouchTarget)
                .background(
                    (selected ? NellPalette.primary.opacity(0.10) : NellPalette.surface),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(selected ? NellPalette.primary.opacity(0.35) : NellPalette.border)
                }
        }
        .accessibilityLabel("\(title) filter")
    }

    private var hasFilters: Bool {
        filter.categoryID != nil || filter.equipmentID != nil || filter.environmentID != nil
    }

    private func categoryIDs(in content: ExerciseCatalogContent) -> [String] {
        Set(content.exercises.map(\.category.rawValue)).sorted()
    }

    private func equipmentIDs(in content: ExerciseCatalogContent) -> [String] {
        Set(content.exercises.flatMap(\.catalogEquipmentIDs)).sorted {
            (equipmentName($0, content: content) ?? $0)
                .localizedCaseInsensitiveCompare(equipmentName($1, content: content) ?? $1)
                == .orderedAscending
        }
    }

    private func activeEnvironments(
        in content: ExerciseCatalogContent
    ) -> [ExerciseEnvironmentDefinition] {
        content.environmentTaxonomy.environments
            .filter { $0.lifecycle.status == .active }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func equipmentName(_ id: String?, content: ExerciseCatalogContent) -> String? {
        guard let id else { return nil }
        return content.equipmentTaxonomy.definition(
            for: ExerciseEquipmentID(rawValue: id)
        )?.displayName
    }

    private func environmentName(_ id: String?, content: ExerciseCatalogContent) -> String? {
        guard let id else { return nil }
        return content.environmentTaxonomy.definition(
            for: ExerciseEnvironmentID(rawValue: id)
        )?.displayName
    }

    private func load() async {
        let catalogState = await repository.loadState()
        guard !Task.isCancelled else { return }

        switch catalogState {
        case .available(let manifest):
            do {
                let taxonomyLoader = taxonomyLoader
                let taxonomies = try await Task.detached {
                    try taxonomyLoader()
                }.value
                guard !Task.isCancelled else { return }
                state = .available(
                    ExerciseCatalogContent(
                        exercises: manifest.exercises,
                        equipmentTaxonomy: taxonomies.equipment,
                        environmentTaxonomy: taxonomies.environments
                    )
                )
            } catch {
                state = .unavailable(
                    "The exercise filters could not be loaded. Try again without changing your saved workouts."
                )
            }
        case .unavailable(let error):
            state = .unavailable(error.catalogueDisplayMessage)
        }
    }
}

private struct ExerciseCatalogRow: View {
    let exercise: ExerciseDefinition
    let content: ExerciseCatalogContent
    let mediaResolver: any ExerciseMediaResolving

    var body: some View {
        NellCard {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                ExerciseMediaView(
                    media: exercise.media,
                    fallbackTitle: exercise.displayName,
                    presentation: .compact,
                    resolver: mediaResolver
                )
                .frame(width: 92, height: 96)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(exercise.displayName)
                        .font(Theme.FontToken.cardTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(summary)
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if exercise.lifecycle.status != .active {
                        NellStatusChip(
                            title: ExerciseCatalogLabel.text(exercise.lifecycle.status.rawValue),
                            tone: exercise.lifecycle.status == .disabled ? .destructive : .attention
                        )
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.textTertiary)
                    .padding(.top, Theme.Spacing.xs)
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens canonical exercise details")
        }
    }

    private var summary: String {
        let equipmentNames = exercise.catalogEquipmentIDs.compactMap { id in
            content.equipmentTaxonomy.definition(
                for: ExerciseEquipmentID(rawValue: id)
            )?.displayName
        }
        let equipment = equipmentNames.isEmpty
            ? "Equipment not specified"
            : equipmentNames.joined(separator: ", ")
        return "\(ExerciseCatalogLabel.text(exercise.category.rawValue)) · \(equipment)"
    }
}

private struct ExerciseCatalogPlaceholderRow: View {
    var body: some View {
        NellCard {
            HStack(spacing: Theme.Spacing.md) {
                RoundedRectangle(cornerRadius: NellLayout.buttonRadius)
                    .fill(NellPalette.elevatedSurface)
                    .frame(width: 92, height: 88)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Exercise movement")
                        .font(Theme.FontToken.cardTitle)
                    Text("Category · Equipment")
                        .font(Theme.FontToken.caption)
                }
            }
        }
    }
}

enum ExerciseCatalogLabel {
    static func text(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

extension ExerciseDefinition {
    var catalogEquipmentIDs: [String] {
        let clauses = equipment.required + equipment.alternatives.flatMap { $0 }
        return Array(Set(clauses.map(\.id.rawValue))).sorted()
    }
}

private extension ExerciseCatalogError {
    var catalogueDisplayMessage: String {
        switch self {
        case .resourceNotFound:
            "The bundled exercise catalogue could not be found."
        case .decodingFailed:
            "The exercise catalogue could not be read safely."
        case .unsupportedSchemaVersion:
            "This exercise catalogue version is not supported by the app."
        case .validationFailed:
            "The exercise catalogue did not pass validation."
        }
    }
}

#if DEBUG
private struct ExerciseCatalogPreviewRepository: ExerciseCatalogRepositoryProviding {
    let state: ExerciseCatalogLoadState

    func loadState() async -> ExerciseCatalogLoadState { state }

    func resolve(reference: String) async -> ExerciseDefinition? {
        guard case .available(let manifest) = state else { return nil }
        return manifest.exercises.first { $0.id.rawValue == reference }
    }
}

enum ExerciseCatalogPreviewFixture {
    static let longName = ExerciseDefinition(
        id: ExerciseID(rawValue: "bodyweight.single_leg_balance_reach")!,
        schemaVersion: 1,
        displayName: "Single-leg balance with alternating overhead reach",
        category: ExerciseCategory(rawValue: "mobility"),
        movementPattern: ExerciseMovementPattern(rawValue: "balance"),
        exerciseType: ExerciseType(rawValue: "duration"),
        equipment: ExerciseEquipmentRequirements(required: [
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "none"), quantity: 1),
        ]),
        trackingMode: ExerciseTrackingMode(rawValue: "duration"),
        instructions: [
            "Stand tall and shift your weight onto one foot near a stable support.",
            "Reach the opposite arm overhead without rushing or holding your breath.",
        ],
        lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
        media: nil,
        aliases: ["Balance reach"],
        legacyIDs: nil,
        guidance: ["Use a wall or chair when additional balance support is helpful."],
        environmentRequirements: ExerciseEnvironmentRequirements(
            required: [ExerciseEnvironmentRequirement(rawValue: "standing_space")],
            prohibited: nil
        ),
        legacyNames: nil
    )

    static let deprecated = ExerciseDefinition(
        id: ExerciseID(rawValue: "bodyweight.retired_reach")!,
        schemaVersion: 1,
        displayName: "Retired standing reach",
        category: ExerciseCategory(rawValue: "mobility"),
        movementPattern: ExerciseMovementPattern(rawValue: "balance"),
        exerciseType: ExerciseType(rawValue: "duration"),
        equipment: ExerciseEquipmentRequirements(required: [
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "none"), quantity: 1),
        ]),
        trackingMode: ExerciseTrackingMode(rawValue: "duration"),
        instructions: ["Stand tall and reach upward with control."],
        lifecycle: ExerciseLifecycle(
            status: .deprecated,
            replacementExerciseID: longName.id
        ),
        media: nil,
        aliases: nil,
        legacyIDs: nil,
        guidance: nil,
        environmentRequirements: nil,
        legacyNames: nil
    )

    static let manifest = ExerciseCatalogManifest(
        catalogSchemaVersion: 1,
        exercises: [longName, deprecated]
    )

    static let taxonomies = BundledExerciseCandidateTaxonomies(
        equipment: EquipmentTaxonomy(
            schemaVersion: 1,
            equipment: [
                EquipmentDefinition(
                    id: ExerciseEquipmentID(rawValue: "none"),
                    displayName: "No equipment",
                    category: ExerciseEquipmentCategory(rawValue: "none"),
                    lifecycle: EquipmentLifecycle(status: .active)
                ),
            ]
        ),
        environments: ExerciseEnvironmentTaxonomy(
            schemaVersion: 1,
            environments: [
                ExerciseEnvironmentDefinition(
                    id: ExerciseEnvironmentID(rawValue: "home"),
                    displayName: "Home",
                    defaultCapabilities: [
                        ExerciseEnvironmentCapabilityID(rawValue: "standing_space"),
                    ],
                    rankingTags: ["home"],
                    lifecycle: ExerciseEnvironmentLifecycle(status: .active)
                ),
            ]
        )
    )
}

#Preview("Loaded, long name and deprecated") {
    NavigationStack {
        ExerciseCatalogView(
            repository: ExerciseCatalogPreviewRepository(state: .available(ExerciseCatalogPreviewFixture.manifest)),
            taxonomyLoader: { ExerciseCatalogPreviewFixture.taxonomies },
            mediaResolver: DictionaryExerciseMediaResolver(assetNamesByKey: [:])
        )
    }
}

#Preview("Unavailable with retry") {
    NavigationStack {
        ExerciseCatalogView(
            repository: ExerciseCatalogPreviewRepository(
                state: .unavailable(.resourceNotFound(name: "catalog.json"))
            ),
            taxonomyLoader: { ExerciseCatalogPreviewFixture.taxonomies }
        )
    }
}
#endif
