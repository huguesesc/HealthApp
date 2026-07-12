import SwiftUI

struct NellTrainHomeView: View {
    var body: some View {
        NellScreen {
            header
            startWorkoutCard
            trainingTools
            movementGuidePreview
            recoveryNote
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .accessibilityLabel("Profile and settings")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text("Train")
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)
            Text("Plans, workouts and movement feedback")
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }

    private var startWorkoutCard: some View {
        NavigationLink {
            WorkoutStartView()
        } label: {
            HStack(alignment: .center, spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    NellStatusChip(
                        title: "Ready when you are",
                        tone: .positive
                    )

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Start or continue a workout")
                            .font(Theme.FontToken.sectionTitle)
                            .foregroundStyle(Color.white)
                        Text("Resume an active session or choose one of your saved plans.")
                            .font(Theme.FontToken.secondaryBody)
                            .foregroundStyle(Color.white.opacity(0.84))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label("Open workout", systemImage: "play.fill")
                        .font(Theme.FontToken.button)
                        .foregroundStyle(Color.white)
                }

                Spacer(minLength: Theme.Spacing.xs)

                WorkoutMotionView(
                    movementName: "Goblet Squat",
                    presentation: .thumbnail
                )
                .frame(width: 82, height: 112)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(Theme.Spacing.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [NellPalette.forest, NellPalette.primary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens workout selection and any active session")
    }

    private var trainingTools: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(title: "Your training")

            NellCard(padding: 0) {
                VStack(spacing: 0) {
                    toolRow(
                        title: "Workout plans",
                        subtitle: "Create, edit and archive structured plans",
                        icon: "list.clipboard"
                    ) {
                        WorkoutPlansView()
                    }

                    divider

                    toolRow(
                        title: "Log a workout",
                        subtitle: "Record a completed session manually",
                        icon: "square.and.pencil"
                    ) {
                        WorkoutLogView()
                    }

                    divider

                    toolRow(
                        title: "Execution history",
                        subtitle: "Review completed and interrupted sessions",
                        icon: "clock.arrow.circlepath"
                    ) {
                        ActiveWorkoutsView()
                    }

                    divider

                    toolRow(
                        title: "Movement feedback",
                        subtitle: "Review adjustments recorded during training",
                        icon: "slider.horizontal.3"
                    ) {
                        MovementFeedbackHistoryView()
                    }
                }
            }
        }
    }

    private var movementGuidePreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            NellSectionHeader(
                title: "Movement guides",
                subtitle: "Clear start and end positions"
            )

            NavigationLink {
                WorkoutMotionGalleryView()
            } label: {
                NellCard {
                    HStack(spacing: Theme.Spacing.md) {
                        WorkoutMotionView(
                            movementName: "Bent-Over Row",
                            presentation: .compactPair
                        )
                        .frame(width: 126, height: 88)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Explore exercise guides")
                                .font(Theme.FontToken.cardTitle)
                                .foregroundStyle(NellPalette.textPrimary)
                            Text("The character pack can be expanded without changing your workout data.")
                                .font(Theme.FontToken.caption)
                                .foregroundStyle(NellPalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: Theme.Spacing.xs)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(NellPalette.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var recoveryNote: some View {
        NellCoachSuggestionCard(
            title: "Recovery remains contextual",
            message: "Use your own feedback, recent activity and professional guidance when deciding how hard to train."
        )
    }

    @ViewBuilder
    private func toolRow<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(NellPalette.training)
                    .frame(width: 42, height: 42)
                    .background(NellPalette.training.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(title)
                        .font(Theme.FontToken.body.weight(.semibold))
                        .foregroundStyle(NellPalette.textPrimary)
                    Text(subtitle)
                        .font(Theme.FontToken.caption)
                        .foregroundStyle(NellPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(NellPalette.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().padding(.leading, 70)
    }
}

#Preview {
    NavigationStack {
        NellTrainHomeView()
    }
    .modelContainer(PersistenceController.preview.container)
}
