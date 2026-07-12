import SwiftUI

/// Five-destination product shell for Nell.
/// Log is intentionally presented as a compact action sheet rather than a blank tab.
struct AppShellView: View {
    @State private var selection: AppSection = .today
    @State private var previousSelection: AppSection = .today
    @State private var showingLog = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.ColorToken.backgroundPrimary
                .ignoresSafeArea()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: Theme.Size.tabBarHeight + 12)
                }

            BrandedTabBar(
                selection: $selection,
                onLog: {
                    previousSelection = selection
                    showingLog = true
                }
            )
        }
        .tint(Theme.ColorToken.brandPrimary)
        .animation(.easeInOut(duration: Theme.Motion.tabTransition), value: selection)
        .sheet(isPresented: $showingLog) {
            LogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.ColorToken.backgroundSecondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .today:
            NavigationStack { DashboardView() }
        case .log:
            NavigationStack { DashboardView() }
        case .coach:
            NavigationStack { ChatView() }
        case .nutrition:
            NavigationStack { MealEntryView() }
        case .train:
            NavigationStack { TrainHomeView() }
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

private struct BrandedTabBar: View {
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
        .background(Theme.ColorToken.surfacePrimary.opacity(colorScheme == .dark ? 0.96 : 0.94))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.ColorToken.border)
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
            .foregroundStyle(selection == section
                ? Theme.ColorToken.brandPrimary
                : Theme.ColorToken.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Size.minimumTouchTarget)
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
                        .fill(Theme.ColorToken.brandPrimary)
                    Circle()
                        .stroke(Theme.ColorToken.surfacePrimary, lineWidth: Theme.Border.coachKeyline)
                    NellCoachMark()
                        .foregroundStyle(colorScheme == .dark
                            ? Theme.ColorToken.backgroundPrimary
                            : Color.white)
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
                    .foregroundStyle(selection == .coach
                        ? Theme.ColorToken.brandPrimary
                        : Theme.ColorToken.textTertiary)
                    .offset(y: Theme.Size.coachTabVerticalOffset)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(CoachTabButtonStyle())
        .accessibilityLabel("Coach")
    }
}

private struct CoachTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Motion.coachPressedScale : 1)
            .animation(.easeOut(duration: configuration.isPressed
                ? Theme.Motion.buttonPress
                : Theme.Motion.buttonRelease), value: configuration.isPressed)
    }
}

private struct LogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var path: [LogDestination] = []
    @State private var naturalText = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Log")
                            .font(Theme.FontToken.largeScreenTitle)
                            .foregroundStyle(Theme.ColorToken.textPrimary)
                        Text("Describe something naturally or choose a category.")
                            .font(Theme.FontToken.secondaryBody)
                            .foregroundStyle(Theme.ColorToken.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        TextField("e.g. chicken, rice and vegetables", text: $naturalText, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(Theme.ColorToken.surfacePrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                                    .stroke(Theme.ColorToken.border, lineWidth: 1)
                            }

                        Button {
                            path.append(.meal(prefill: naturalText))
                        } label: {
                            Label("Interpret as meal", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                                .frame(height: Theme.Size.buttonHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.ColorToken.brandPrimary)
                        .disabled(naturalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                        quickAction("Meal", icon: "fork.knife", color: Theme.ColorToken.nutrition) {
                            path.append(.meal(prefill: ""))
                        }
                        quickAction("Workout", icon: "dumbbell", color: Theme.ColorToken.training) {
                            path.append(.workout)
                        }
                        quickAction("Sleep", icon: "moon.zzz", color: Theme.ColorToken.sleep) {
                            path.append(.sleep)
                        }
                        quickAction("Check-in", icon: "checkmark.circle", color: Theme.ColorToken.brandSecondary) {
                            path.append(.checkIn)
                        }
                    }
                }
                .padding(Theme.Spacing.screen)
            }
            .background(Theme.ColorToken.backgroundSecondary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: LogDestination.self) { destination in
                switch destination {
                case .meal:
                    MealEntryView()
                case .workout:
                    WorkoutLogView()
                case .sleep:
                    SleepEntryView()
                case .checkIn:
                    CheckInView()
                }
            }
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
                    .foregroundStyle(Theme.ColorToken.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Theme.ColorToken.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .stroke(Theme.ColorToken.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum LogDestination: Hashable {
    case meal(prefill: String)
    case workout
    case sleep
    case checkIn
}

struct TrainHomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Train")
                        .font(Theme.FontToken.largeScreenTitle)
                    Text("Plans, active sessions, history and movement feedback.")
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(Theme.ColorToken.textSecondary)
                }

                NavigationLink {
                    WorkoutStartView()
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "figure.run.circle.fill")
                            .font(.system(size: 34))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start or continue workout")
                                .font(Theme.FontToken.cardTitle)
                            Text("Resume an active session or choose a plan.")
                                .font(Theme.FontToken.secondaryBody)
                                .opacity(0.82)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(Theme.Spacing.screen)
                    .foregroundStyle(Color.white)
                    .background(Theme.ColorToken.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(spacing: 0) {
                    trainLink("Structured workout plans", icon: "list.clipboard") { WorkoutPlansView() }
                    Divider().padding(.leading, 52)
                    trainLink("Workout log", icon: "dumbbell") { WorkoutLogView() }
                    Divider().padding(.leading, 52)
                    trainLink("Execution history", icon: "clock.arrow.circlepath") { ActiveWorkoutsView() }
                    Divider().padding(.leading, 52)
                    trainLink("Movement feedback", icon: "slider.horizontal.3") { MovementFeedbackHistoryView() }
                }
                .background(Theme.ColorToken.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .stroke(Theme.ColorToken.border, lineWidth: 1)
                }
            }
            .padding(Theme.Spacing.screen)
        }
        .background(Theme.ColorToken.backgroundPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "person.crop.circle")
                }
            }
        }
    }

    private func trainLink<Destination: View>(
        _ title: String,
        icon: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(Theme.ColorToken.training)
                    .frame(width: 28)
                Text(title)
                    .foregroundStyle(Theme.ColorToken.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.ColorToken.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AppShellView()
        .modelContainer(PersistenceController.preview.container)
}
