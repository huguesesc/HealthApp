import SwiftUI

struct NellOnboardingView: View {
    @Binding var isComplete: Bool

    @AppStorage("nell.profile.displayName") private var storedDisplayName = ""
    @AppStorage("nell.profile.goals") private var storedGoals = ""
    @AppStorage("nell.profile.trainingContext") private var storedTrainingContext = ""
    @AppStorage("nell.profile.movementNotes") private var storedMovementNotes = ""

    @State private var step = 0
    @State private var displayName = ""
    @State private var selectedGoals: Set<NellOnboardingGoal> = []
    @State private var trainingContext: NellTrainingContext = .mixed
    @State private var movementNotes = ""

    private let finalStep = 4

    var body: some View {
        VStack(spacing: 0) {
            onboardingProgress

            TabView(selection: $step) {
                WelcomeOnboardingPage()
                    .tag(0)

                GoalsOnboardingPage(selectedGoals: $selectedGoals)
                    .tag(1)

                TrainingOnboardingPage(
                    displayName: $displayName,
                    trainingContext: $trainingContext
                )
                .tag(2)

                MovementOnboardingPage(notes: $movementNotes)
                    .tag(3)

                IntegrationsOnboardingPage()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: Theme.Motion.tabTransition), value: step)

            onboardingControls
        }
        .background(NellPalette.background.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onAppear(perform: loadStoredProfile)
    }

    private var onboardingProgress: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text("Set up Nell")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
                Spacer()
                Text("\(step + 1) of \(finalStep + 1)")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textTertiary)
            }

            ProgressView(value: Double(step + 1), total: Double(finalStep + 1))
                .tint(NellPalette.primary)
                .accessibilityLabel("Onboarding progress")
        }
        .padding(.horizontal, NellLayout.screenPadding)
        .padding(.top, Theme.Spacing.sm)
    }

    private var onboardingControls: some View {
        HStack(spacing: Theme.Spacing.sm) {
            if step > 0 {
                Button("Back", action: goBack)
                    .buttonStyle(.nellSecondary)
            }

            Button(step == finalStep ? "Start using Nell" : "Continue", action: continueOnboarding)
                .buttonStyle(.nellPrimary)
                .disabled(step == 1 && selectedGoals.isEmpty)
        }
        .padding(NellLayout.screenPadding)
        .background(NellPalette.surface)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func goBack() {
        step = max(step - 1, 0)
    }

    private func continueOnboarding() {
        guard step < finalStep else {
            saveProfile()
            isComplete = true
            return
        }
        step += 1
    }

    private func loadStoredProfile() {
        displayName = storedDisplayName
        movementNotes = storedMovementNotes
        if let context = NellTrainingContext(rawValue: storedTrainingContext) {
            trainingContext = context
        }
        selectedGoals = Set(
            storedGoals
                .split(separator: ",")
                .compactMap { NellOnboardingGoal(rawValue: String($0)) }
        )
    }

    private func saveProfile() {
        storedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        storedGoals = selectedGoals.map(\.rawValue).sorted().joined(separator: ",")
        storedTrainingContext = trainingContext.rawValue
        storedMovementNotes = movementNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct WelcomeOnboardingPage: View {
    var body: some View {
        OnboardingPageContainer {
            VStack(spacing: NellLayout.sectionSpacing) {
                NellBrandLockup(showsDescriptor: true)

                NellMascotView(pose: .wave)
                    .frame(width: 184, height: 184)

                VStack(spacing: Theme.Spacing.sm) {
                    Text("Health guidance that starts with your context")
                        .font(Theme.FontToken.largeScreenTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Nell brings your training, nutrition, check-ins and optional Apple Health summaries into one calm daily companion.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Label("You can use Nell without connecting external services.", systemImage: "lock.shield")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
            }
        }
    }
}

private struct GoalsOnboardingPage: View {
    @Binding var selectedGoals: Set<NellOnboardingGoal>

    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                OnboardingTitle(
                    title: "What would you like help with?",
                    subtitle: "Choose one or more. These preferences guide organisation and Coach context; they are not medical targets."
                )

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(NellOnboardingGoal.allCases) { goal in
                        Button {
                            toggle(goal)
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: goal.symbol)
                                    .font(.title3)
                                    .foregroundStyle(NellPalette.primary)
                                    .frame(width: 34)

                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(goal.title)
                                        .font(Theme.FontToken.cardTitle)
                                        .foregroundStyle(NellPalette.textPrimary)
                                    Text(goal.detail)
                                        .font(Theme.FontToken.caption)
                                        .foregroundStyle(NellPalette.textSecondary)
                                }

                                Spacer()

                                Image(systemName: selectedGoals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedGoals.contains(goal) ? NellPalette.primary : NellPalette.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(
                                selectedGoals.contains(goal) ? NellPalette.primary.opacity(0.10) : NellPalette.surface,
                                in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                                    .stroke(
                                        selectedGoals.contains(goal) ? NellPalette.primary : NellPalette.border,
                                        lineWidth: Theme.Border.standard
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedGoals.contains(goal) ? .isSelected : [])
                    }
                }
            }
        }
    }

    private func toggle(_ goal: NellOnboardingGoal) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }
}

private struct TrainingOnboardingPage: View {
    @Binding var displayName: String
    @Binding var trainingContext: NellTrainingContext

    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                OnboardingTitle(
                    title: "Your training context",
                    subtitle: "A name is optional. Choose the setting that most closely matches how you currently move."
                )

                NellCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("What should Nell call you?")
                            .font(Theme.FontToken.cardTitle)
                            .foregroundStyle(NellPalette.textPrimary)

                        TextField("Optional name", text: $displayName)
                            .textInputAutocapitalization(.words)
                            .padding(Theme.Spacing.sm)
                            .background(NellPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius))
                    }
                }

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(NellTrainingContext.allCases) { context in
                        Button {
                            trainingContext = context
                        } label: {
                            HStack {
                                Label(context.title, systemImage: context.symbol)
                                    .font(Theme.FontToken.body)
                                    .foregroundStyle(NellPalette.textPrimary)
                                Spacer()
                                Image(systemName: trainingContext == context ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(trainingContext == context ? NellPalette.primary : NellPalette.textTertiary)
                            }
                            .padding(Theme.Spacing.md)
                            .background(NellPalette.surface, in: RoundedRectangle(cornerRadius: NellLayout.cardRadius))
                            .overlay {
                                RoundedRectangle(cornerRadius: NellLayout.cardRadius)
                                    .stroke(trainingContext == context ? NellPalette.primary : NellPalette.border)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(trainingContext == context ? .isSelected : [])
                    }
                }
            }
        }
    }
}

private struct MovementOnboardingPage: View {
    @Binding var notes: String

    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                OnboardingTitle(
                    title: "Movement considerations",
                    subtitle: "Optionally record limitations, previous injuries or movements you prefer to avoid. This is self-reported context, not a diagnosis."
                )

                NellCard {
                    TextField(
                        "Example: avoid deep knee flexion for now",
                        text: $notes,
                        axis: .vertical
                    )
                    .lineLimit(5...10)
                }

                NellCoachSuggestionCard(
                    title: "Safety first",
                    message: "Stop when something feels unsafe and seek qualified medical or rehabilitation advice when needed."
                )
            }
        }
    }
}

private struct IntegrationsOnboardingPage: View {
    var body: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                OnboardingTitle(
                    title: "Optional connections",
                    subtitle: "You can configure these later in Settings. Manual local features remain available if you skip them."
                )

                IntegrationExplanationCard(
                    title: "Apple Health",
                    detail: "Import compact activity, workout and sleep summaries after granting permission.",
                    symbol: "heart.text.square"
                )

                IntegrationExplanationCard(
                    title: "Coach connection",
                    detail: "Add your own supported AI service key to use connected Coach responses. Keys stay in the device Keychain.",
                    symbol: "key.horizontal"
                )

                NellConfirmationCard(
                    title: "You remain in control",
                    message: "Entries are reviewed before saving, optional services can be left disconnected, and Nell does not diagnose or replace professional care."
                )
            }
        }
    }
}

private struct OnboardingPageContainer<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(NellLayout.screenPadding)
        }
    }
}

private struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.FontToken.largeScreenTitle)
                .foregroundStyle(NellPalette.textPrimary)

            Text(subtitle)
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
    }
}

private struct IntegrationExplanationCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        NellCard {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(NellPalette.primary)
                    .frame(width: 42)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.FontToken.cardTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                    Text(detail)
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                }
            }
        }
    }
}

private enum NellOnboardingGoal: String, CaseIterable, Identifiable, Hashable {
    case everydayHealth
    case strength
    case fitness
    case nutrition
    case consistency

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everydayHealth: return "Everyday health"
        case .strength: return "Build strength"
        case .fitness: return "Improve fitness"
        case .nutrition: return "Understand nutrition"
        case .consistency: return "Build consistency"
        }
    }

    var detail: String {
        switch self {
        case .everydayHealth: return "Bring daily logs and health summaries together."
        case .strength: return "Plan and record resistance training."
        case .fitness: return "Track movement and completed sessions."
        case .nutrition: return "Log meals without depending on food photography."
        case .consistency: return "Use calm reminders and factual progress."
        }
    }

    var symbol: String {
        switch self {
        case .everydayHealth: return "heart"
        case .strength: return "dumbbell"
        case .fitness: return "figure.run"
        case .nutrition: return "fork.knife"
        case .consistency: return "calendar.badge.checkmark"
        }
    }
}

private enum NellTrainingContext: String, CaseIterable, Identifiable {
    case home
    case gym
    case outdoors
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Mostly at home"
        case .gym: return "Mostly at a gym"
        case .outdoors: return "Mostly outdoors"
        case .mixed: return "A mix of settings"
        }
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .gym: return "dumbbell"
        case .outdoors: return "figure.outdoor.cycle"
        case .mixed: return "square.grid.2x2"
        }
    }
}

#Preview {
    NellOnboardingView(isComplete: .constant(false))
}
