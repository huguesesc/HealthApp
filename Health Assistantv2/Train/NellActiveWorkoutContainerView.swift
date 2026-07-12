import SwiftData
import SwiftUI

/// Nell entry point for active workouts. The existing durable execution screen
/// remains the source of truth; this container adds a compact, replaceable motion
/// guide without changing timer or persistence behaviour.
struct NellActiveWorkoutContainerView: View {
    @Bindable var session: ActiveWorkoutSession

    var body: some View {
        VStack(spacing: 0) {
            if let step = session.currentStep,
               session.status == .inProgress || session.status == .paused {
                motionGuide(for: step)
                Divider()
            }

            ActiveWorkoutView(session: session)
        }
        .background(NellPalette.background)
    }

    private func motionGuide(_ step: ActiveWorkoutStep) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            WorkoutMotionView(
                title: step.title,
                type: step.type,
                presentation: .pair,
                showsLabels: false
            )
            .frame(width: 150, height: 94)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Movement Guide")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.primary)

                Text(step.title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                    .lineLimit(2)

                Text("General start and finish positions")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NellLayout.screenPadding)
        .padding(.vertical, Theme.Spacing.xs)
        .background(NellPalette.surface)
        .accessibilityElement(children: .combine)
    }
}

/// Starts a durable session or resumes the unfinished execution for the same plan.
struct NellActiveWorkoutLauncherView: View {
    @Environment(\.modelContext) private var modelContext
    let plan: WorkoutPlan

    @State private var session: ActiveWorkoutSession?
    @State private var errorMessage: String?

    private var repo: HealthDataRepository { HealthDataRepository(context: modelContext) }

    var body: some View {
        Group {
            if let session {
                NellActiveWorkoutContainerView(session: session)
            } else if let errorMessage {
                NellErrorState(
                    title: "Cannot start workout",
                    message: errorMessage
                )
                .padding(NellLayout.screenPadding)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    NellThinkingIndicator(label: "Preparing workout…")
                    Text("Nell is creating a durable copy of the plan so later edits cannot rewrite this session.")
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(NellLayout.screenPadding)
                .task { prepare() }
            }
        }
        .background(NellPalette.background)
    }

    private func prepare() {
        if let existing = repo.resumableActiveWorkouts().first(where: {
            $0.sourcePlanIDSnapshot == plan.id
        }) {
            session = existing
            return
        }

        guard let created = repo.startActiveWorkout(from: plan) else {
            errorMessage = "Add at least one step to this plan before starting it."
            return
        }
        session = created
    }
}
