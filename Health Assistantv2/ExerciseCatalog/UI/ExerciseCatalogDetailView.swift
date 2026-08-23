import SwiftUI

struct ExerciseCatalogDetailView: View {
    let definition: ExerciseDefinition
    let plannedStep: WorkoutStep?
    private let mediaResolver: any ExerciseMediaResolving

    init(
        definition: ExerciseDefinition,
        plannedStep: WorkoutStep? = nil,
        mediaResolver: (any ExerciseMediaResolving)? = nil
    ) {
        self.definition = definition
        self.plannedStep = plannedStep
        self.mediaResolver = mediaResolver ?? Self.productionMediaResolver()
    }

    var body: some View {
        NellScreen {
            header
            instructions

            if definition.media?.isEmpty == false {
                NellSectionHeader(
                    title: "Movement guide",
                    subtitle: "Written instructions remain the primary guide."
                )
                ExerciseMediaView(
                    media: definition.media,
                    fallbackTitle: definition.displayName,
                    resolver: mediaResolver
                )
            }

            if let plannedStep {
                plannedTarget(plannedStep)
            }

            requirements

            if let guidance = definition.guidance, !guidance.isEmpty {
                NellSectionHeader(title: "Additional guidance")
                NellCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(Array(guidance.enumerated()), id: \.offset) { _, item in
                            Label(item, systemImage: "checkmark.circle")
                                .font(Theme.FontToken.secondaryBody)
                                .foregroundStyle(NellPalette.textSecondary)
                        }
                    }
                }
            }

            NellCoachSuggestionCard(
                title: "Movement note",
                message: "This catalogue entry is a general movement guide, not a diagnosis or a guarantee that the exercise is suitable for a specific injury."
            )
        }
        .navigationTitle(definition.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        NellFeaturedCard(tint: lifecycleTint) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(definition.displayName)
                            .font(Theme.FontToken.navigationTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(definition.id.rawValue)
                            .font(Theme.FontToken.caption.monospaced())
                            .foregroundStyle(NellPalette.textTertiary)
                            .textSelection(.enabled)
                    }
                    Spacer(minLength: 0)
                    NellStatusChip(
                        title: ExerciseCatalogLabel.text(definition.lifecycle.status.rawValue),
                        tone: lifecycleTone
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Spacing.md) { metadataLabels }
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) { metadataLabels }
                }
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)

                if definition.lifecycle.status == .deprecated {
                    Text(deprecatedMessage)
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.warning)
                } else if definition.lifecycle.status == .disabled {
                    Text("This catalogue entry is disabled and cannot be used in newly generated workouts.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.destructive)
                }
            }
        }
    }

    @ViewBuilder
    private var metadataLabels: some View {
        Label(ExerciseCatalogLabel.text(definition.category.rawValue), systemImage: "square.grid.2x2")
        Label(ExerciseCatalogLabel.text(definition.movementPattern.rawValue), systemImage: "figure.mixed.cardio")
        Label(ExerciseCatalogLabel.text(definition.trackingMode.rawValue), systemImage: "chart.bar.doc.horizontal")
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "How to do it")
            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(Array(definition.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Text("\(index + 1)")
                                .font(Theme.FontToken.caption.monospacedDigit())
                                .foregroundStyle(Color.white)
                                .frame(width: 24, height: 24)
                                .background(NellPalette.primary, in: Circle())
                                .accessibilityHidden(true)
                            Text(instruction)
                                .font(Theme.FontToken.body)
                                .foregroundStyle(NellPalette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Step \(index + 1). \(instruction)")
                    }
                }
            }
        }
    }

    private var requirements: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Requirements")
            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label(equipmentDescription, systemImage: "dumbbell")
                    Label(environmentDescription, systemImage: "mappin.and.ellipse")
                }
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
            }
        }
    }

    private func plannedTarget(_ step: WorkoutStep) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Planned target")
            NellCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if let instruction = step.instruction?.trimmed, !instruction.isEmpty {
                        Label(instruction, systemImage: "text.alignleft")
                    }
                    if let sets = step.sets { Label("\(sets) sets", systemImage: "repeat") }
                    if let reps = step.reps { Label("\(reps) reps", systemImage: "number") }
                    if let duration = step.durationSeconds {
                        Label(durationLabel(duration), systemImage: "timer")
                    }
                    if let weight = step.targetWeightKilograms {
                        Label("\(String(format: "%g", weight)) kg", systemImage: "scalemass")
                    }
                    if let rest = step.restSeconds {
                        Label("Rest \(durationLabel(rest))", systemImage: "pause")
                    }
                    if step.side != .none {
                        Label(step.side.displayName, systemImage: "arrow.left.and.right")
                    }
                    if let equipment = step.equipmentNameSnapshot {
                        Label(equipment, systemImage: "dumbbell")
                    }
                }
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
            }
        }
    }

    private var equipmentDescription: String {
        let required = clausesDescription(definition.equipment.required)
        let alternatives = definition.equipment.alternatives.map(clausesDescription)
        guard !alternatives.isEmpty else { return required }
        return ([required] + alternatives).joined(separator: " or ")
    }

    private func clausesDescription(_ clauses: [ExerciseEquipmentClause]) -> String {
        clauses.map { clause in
            if clause.id.rawValue == "none" { return "No equipment" }
            let name = ExerciseCatalogLabel.text(clause.id.rawValue)
            return clause.quantity > 1 ? "\(clause.quantity) × \(name)" : name
        }.joined(separator: " + ")
    }

    private var environmentDescription: String {
        let required = definition.environmentRequirements?.required.map {
            ExerciseCatalogLabel.text($0.rawValue)
        } ?? []
        let prohibited = definition.environmentRequirements?.prohibited?.map {
            "No \(ExerciseCatalogLabel.text($0.rawValue).lowercased())"
        } ?? []
        let descriptions = required + prohibited
        return descriptions.isEmpty
            ? "No additional location requirements"
            : descriptions.joined(separator: " · ")
    }

    private var lifecycleTone: NellStatusTone {
        switch definition.lifecycle.status {
        case .active: .positive
        case .deprecated: .attention
        case .disabled: .destructive
        }
    }

    private var lifecycleTint: Color {
        switch definition.lifecycle.status {
        case .active: NellPalette.primary
        case .deprecated: NellPalette.warning
        case .disabled: NellPalette.destructive
        }
    }

    private var deprecatedMessage: String {
        guard let replacement = definition.lifecycle.replacementExerciseID else {
            return "This exercise is deprecated and remains visible for saved-workout compatibility."
        }
        return "This exercise is deprecated. Current catalogue replacement: \(replacement.rawValue)."
    }

    private func durationLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) sec" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes) min" : "\(minutes)m \(remainder)s"
    }

    static func productionMediaResolver() -> any ExerciseMediaResolving {
        (try? BundledExerciseMediaResolver(bundle: .main))
            ?? DictionaryExerciseMediaResolver(assetNamesByKey: [:])
    }
}

#if DEBUG
#Preview("Long name, no media") {
    NavigationStack {
        ExerciseCatalogDetailView(
            definition: ExerciseCatalogPreviewFixture.longName,
            mediaResolver: DictionaryExerciseMediaResolver(assetNamesByKey: [:])
        )
    }
}

#Preview("Deprecated") {
    NavigationStack {
        ExerciseCatalogDetailView(
            definition: ExerciseCatalogPreviewFixture.deprecated,
            mediaResolver: DictionaryExerciseMediaResolver(assetNamesByKey: [:])
        )
    }
    .preferredColorScheme(.dark)
}
#endif
