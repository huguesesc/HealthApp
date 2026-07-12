import SwiftData
import SwiftUI

/// Nell entry point for active workouts. The durable execution screen remains the
/// source of truth for timers, persistence and exactly-once workout conversion.
struct NellActiveWorkoutContainerView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var session: ActiveWorkoutSession

    private var isComplete: Bool {
        session.progressFraction >= 0.999 && session.currentStep == nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                focusedHeader

                if let step = session.currentStep,
                   session.status == .inProgress || session.status == .paused {
                    motionGuide(for: step)
                    Divider()
                }

                ActiveWorkoutView(session: session)
            }
            .background(NellPalette.background)

            if isComplete {
                completionOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: Theme.Motion.tabTransition), value: isComplete)
        .toolbar(.hidden, for: .tabBar)
    }

    private var focusedHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(session.titleSnapshot)
                        .font(Theme.FontToken.navigationTitle)
                        .foregroundStyle(Color.white)
                        .lineLimit(2)

                    Text(session.status.displayName)
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text("\(Int(session.progressFraction * 100))%")
                    .font(Theme.FontToken.metric)
                    .foregroundStyle(Color.white)
                    .monospacedDigit()
            }

            ProgressView(value: session.progressFraction)
                .tint(Color.white)
                .accessibilityLabel("Workout progress")
                .accessibilityValue("\(Int(session.progressFraction * 100)) percent")
        }
        .padding(.horizontal, NellLayout.screenPadding)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.md)
        .background(NellPalette.forest)
    }

    private func motionGuide(for step: ActiveWorkoutStep) -> some View {
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

    private var completionOverlay: some View {
        ZStack {
            NellPalette.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: NellLayout.sectionSpacing) {
                    NellMascotView(pose: .success)
                        .frame(width: 132, height: 132)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("Workout complete")
                            .font(Theme.FontToken.largeScreenTitle)
                            .foregroundStyle(NellPalette.textPrimary)

                        Text(session.titleSnapshot)
                            .font(Theme.FontToken.sectionTitle)
                            .foregroundStyle(NellPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    NellCard {
                        VStack(spacing: Theme.Spacing.md) {
                            completionMetric(
                                title: "Duration",
                                value: elapsedLabel(session.elapsedSeconds()),
                                symbol: "clock"
                            )

                            Divider()

                            completionMetric(
                                title: "Progress",
                                value: "100%",
                                symbol: "checkmark.circle.fill"
                            )
                        }
                    }

                    Text("The completed session is stored locally and will appear in Progress.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("Done", action: dismiss.callAsFunction)
                        .buttonStyle(.nellPrimary)
                }
                .padding(NellLayout.screenPadding)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func completionMetric(title: String, value: String, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .font(Theme.FontToken.body)
                .foregroundStyle(NellPalette.textSecondary)
            Spacer()
            Text(value)
                .font(Theme.FontToken.cardTitle)
                .foregroundStyle(NellPalette.textPrimary)
                .monospacedDigit()
        }
    }

    private func elapsedLabel(_ seconds: Int) -> String {
        let minutes = max(seconds, 0) / 60
        return minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
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
