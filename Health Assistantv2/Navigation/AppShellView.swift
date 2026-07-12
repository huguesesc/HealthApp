import SwiftUI

/// Five-destination Nell shell. Log is an action sheet rather than a persistent tab.
struct AppShellView: View {
    @State private var selection: AppSection = .today
    @State private var showingLog = false

    var body: some View {
        ZStack(alignment: .bottom) {
            NellPalette.background
                .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: Theme.Size.tabBarHeight + 12)
                }

            NellTabBar(
                selection: $selection,
                onLog: { showingLog = true }
            )
        }
        .tint(NellPalette.primary)
        .animation(.easeInOut(duration: Theme.Motion.tabTransition), value: selection)
        .sheet(isPresented: $showingLog) {
            NellLogSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NellPalette.groupedBackground)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .today:
            NavigationStack { NellTodayView() }
        case .log:
            NavigationStack { NellTodayView() }
        case .coach:
            NavigationStack { NellCoachRootView() }
        case .nutrition:
            NavigationStack { NellNutritionHomeView() }
        case .train:
            NavigationStack { NellTrainHomeView() }
        }
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case log = "Log"
    case coach = "Coach"
    case nutrition = "Nutrition"
    case train = "Train"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .today: return "house"
        case .log: return "plus.circle"
        case .coach: return ""
        case .nutrition: return "fork.knife"
        case .train: return "dumbbell"
        }
    }

    var selectedIcon: String {
        switch self {
        case .today: return "house.fill"
        case .log: return "plus.circle.fill"
        case .coach: return ""
        case .nutrition: return "fork.knife"
        case .train: return "dumbbell.fill"
        }
    }
}

private struct NellTabBar: View {
    @Binding var selection: AppSection
    let onLog: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tab(.today)
            tab(.log)
            coachTab
            tab(.nutrition)
            tab(.train)
        }
        .frame(height: Theme.Size.tabBarHeight)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .background(NellPalette.surface.opacity(colorScheme == .dark ? 0.97 : 0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NellPalette.border)
                .frame(height: 1)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func tab(_ section: AppSection) -> some View {
        Button {
            if section == .log {
                onLog()
            } else {
                selection = section
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == section ? section.selectedIcon : section.icon)
                    .font(.system(size: Theme.Size.tabIcon, weight: .medium))
                    .frame(height: 26)
                Text(section.rawValue)
                    .font(Theme.FontToken.tabLabel)
                    .lineLimit(1)
            }
            .foregroundStyle(selection == section ? NellPalette.primary : NellPalette.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: NellLayout.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.rawValue)
    }

    private var coachTab: some View {
        Button {
            selection = .coach
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(NellPalette.primary)
                    Circle()
                        .stroke(NellPalette.surface, lineWidth: Theme.Border.coachKeyline)
                    NellCoachMark()
                        .foregroundStyle(colorScheme == .dark ? NellPalette.background : Color.white)
                        .frame(width: Theme.Size.coachIcon, height: Theme.Size.coachIcon)
                }
                .frame(width: Theme.Size.coachTabDiameter, height: Theme.Size.coachTabDiameter)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark
                        ? Theme.Opacity.darkShadow
                        : Theme.Opacity.lightShadow),
                    radius: 12,
                    y: 4
                )
                .offset(y: Theme.Size.coachTabVerticalOffset)

                Text(AppSection.coach.rawValue)
                    .font(Theme.FontToken.tabLabel)
                    .foregroundStyle(selection == .coach ? NellPalette.primary : NellPalette.textTertiary)
                    .offset(y: Theme.Size.coachTabVerticalOffset)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(NellCoachTabButtonStyle())
        .accessibilityLabel("Coach")
    }
}

private struct NellCoachTabButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                reduceMotion || !configuration.isPressed
                    ? 1
                    : Theme.Motion.coachPressedScale
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: configuration.isPressed
                        ? Theme.Motion.buttonPress
                        : Theme.Motion.buttonRelease),
                value: configuration.isPressed
            )
    }
}

// MARK: - Log sheet

private enum NaturalLogCategory: String, CaseIterable, Identifiable {
    case meal = "Meal"
    case workout = "Workout"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .workout: return "dumbbell"
        }
    }

    var tint: Color {
        switch self {
        case .meal: return NellPalette.nutrition
        case .workout: return NellPalette.training
        }
    }
}

private enum LogDestination: Hashable {
    case meal(prefill: String)
    case workout(prefill: String)
    case sleep
    case checkIn
}

private struct NellLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var path: [LogDestination] = []
    @State private var naturalText = ""
    @State private var naturalCategory: NaturalLogCategory?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Log")
                            .font(Theme.FontToken.largeScreenTitle)
                            .foregroundStyle(NellPalette.textPrimary)
                        Text("Choose what you are logging, then describe it naturally.")
                            .font(Theme.FontToken.secondaryBody)
                            .foregroundStyle(NellPalette.textSecondary)
                    }

                    NellCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Category")
                                .font(Theme.FontToken.caption)
                                .foregroundStyle(NellPalette.textSecondary)

                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(NaturalLogCategory.allCases) { category in
                                    categoryButton(category)
                                }
                            }

                            NellTextField(
                                title: "Describe it",
                                text: $naturalText,
                                prompt: naturalCategory == .workout
                                    ? "e.g. bench press 3 × 8 at 60 kg"
                                    : "e.g. two eggs, toast and coffee",
                                axis: .vertical,
                                lineLimit: 2...5
                            )

                            Button {
                                continueWithNaturalText()
                            } label: {
                                Label("Review before saving", systemImage: "arrow.right")
                            }
                            .buttonStyle(.nellPrimary)
                            .disabled(naturalCategory == nil || naturalText.trimmed.isEmpty)
                        }
                    }

                    NellSectionHeader(
                        title: "Quick log",
                        subtitle: "Open a manual form without AI."
                    )

                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: Theme.Spacing.sm
                    ) {
                        quickAction("Meal", icon: "fork.knife", color: NellPalette.nutrition) {
                            path.append(.meal(prefill: ""))
                        }
                        quickAction("Workout", icon: "dumbbell", color: NellPalette.training) {
                            path.append(.workout(prefill: ""))
                        }
                        quickAction("Sleep", icon: "moon.zzz", color: NellPalette.sleep) {
                            path.append(.sleep)
                        }
                        quickAction("Check-in", icon: "checkmark.circle", color: NellPalette.amber) {
                            path.append(.checkIn)
                        }
                    }
                }
                .padding(NellLayout.screenPadding)
            }
            .background(NellPalette.groupedBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: LogDestination.self) { destination in
                switch destination {
                case .meal(let prefill):
                    MealEntryView(initialText: prefill)
                case .workout(let prefill):
                    WorkoutLogView(initialFreeformText: prefill)
                case .sleep:
                    SleepEntryView()
                case .checkIn:
                    CheckInView()
                }
            }
        }
    }

    private func categoryButton(_ category: NaturalLogCategory) -> some View {
        let selected = naturalCategory == category

        return Button {
            naturalCategory = category
        } label: {
            Label(category.rawValue, systemImage: category.icon)
                .font(Theme.FontToken.secondaryBody.weight(.semibold))
                .foregroundStyle(selected ? Color.white : category.tint)
                .frame(maxWidth: .infinity)
                .frame(minHeight: NellLayout.minimumTouchTarget)
                .background(
                    selected ? category.tint : category.tint.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
                        .stroke(category.tint.opacity(selected ? 0 : 0.24), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func continueWithNaturalText() {
        guard let naturalCategory else { return }
        let text = naturalText.trimmed
        guard !text.isEmpty else { return }

        switch naturalCategory {
        case .meal:
            path.append(.meal(prefill: text))
        case .workout:
            path.append(.workout(prefill: text))
        }
    }

    private func quickAction(
        _ title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Size.prominentIcon, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(
                NellPalette.surface,
                in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                    .stroke(NellPalette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppShellView()
        .modelContainer(PersistenceController.preview.container)
}
