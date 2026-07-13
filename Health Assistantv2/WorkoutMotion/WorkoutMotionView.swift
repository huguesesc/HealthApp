import SwiftUI

enum WorkoutMotionPresentation: Sendable {
    case compact
    case pair
    case hero
}

struct WorkoutMotionView: View {
    let definition: WorkoutMotionDefinition
    var presentation: WorkoutMotionPresentation = .pair
    var showsLabels = false

    init(
        movementID: String,
        presentation: WorkoutMotionPresentation = .pair,
        showsLabels: Bool = false
    ) {
        self.definition = WorkoutMotionRegistry.definition(movementID: movementID)
            ?? WorkoutMotionRegistry.definition(for: movementID)
        self.presentation = presentation
        self.showsLabels = showsLabels
    }

    init(
        title: String,
        type: WorkoutStepType? = nil,
        presentation: WorkoutMotionPresentation = .pair,
        showsLabels: Bool = false
    ) {
        self.definition = WorkoutMotionRegistry.definition(for: title, type: type)
        self.presentation = presentation
        self.showsLabels = showsLabels
    }

    var body: some View {
        Group {
            switch presentation {
            case .compact:
                compact
            case .pair:
                pair
            case .hero:
                hero
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var style: WorkoutAvatarStyle {
        WorkoutAvatarStyleRegistry.style(id: definition.characterStyleID)
    }

    private var compact: some View {
        WorkoutAvatarFigure(
            pose: definition.endPose ?? definition.startPose,
            style: style,
            equipment: definition.equipment
        )
        .frame(width: 54, height: 70)
    }

    private var pair: some View {
        HStack(spacing: Theme.Spacing.xs) {
            poseColumn(definition.startPose, label: "Start")

            if let endPose = definition.endPose {
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NellPalette.primary)
                    .accessibilityHidden(true)
                poseColumn(endPose, label: "Finish")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.sm) {
            pair
            Text(definition.displayName)
                .font(Theme.FontToken.cardTitle)
                .foregroundStyle(NellPalette.textPrimary)
        }
        .padding(Theme.Spacing.md)
        .background(
            NellPalette.elevatedSurface,
            in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
        }
    }

    private func poseColumn(_ pose: WorkoutAvatarPose, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            WorkoutAvatarFigure(
                pose: pose,
                style: style,
                equipment: definition.equipment
            )
            .frame(maxWidth: .infinity)
            .frame(height: presentation == .hero ? 180 : 120)

            if showsLabels {
                Text(label)
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textTertiary)
            }
        }
    }

    private var accessibilityLabel: String {
        if definition.hasTwoPoses {
            return "\(definition.displayName), start and finish movement guide"
        }
        return "\(definition.displayName) movement guide"
    }
}

struct WorkoutMotionRow: View {
    let title: String
    var type: WorkoutStepType? = nil
    var detail: String?
    var status: NellStatusTone = .neutral

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            WorkoutMotionView(title: title, type: type, presentation: .compact)
                .frame(width: 58)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                    .lineLimit(2)

                if let detail {
                    Text(detail)
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: Theme.Spacing.xs)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NellPalette.textTertiary)
        }
        .contentShape(Rectangle())
    }
}

#Preview("Workout motion") {
    ScrollView {
        VStack(spacing: 20) {
            WorkoutMotionView(movementID: "goblet_squat", presentation: .hero, showsLabels: true)
            WorkoutMotionView(movementID: "bent_over_row", showsLabels: true)
            WorkoutMotionRow(title: "Overhead Press", detail: "3 sets · 8 reps")
        }
        .padding()
    }
    .background(NellPalette.background)
}
