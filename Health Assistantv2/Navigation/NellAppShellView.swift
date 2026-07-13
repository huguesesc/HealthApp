import SwiftUI

struct NellAppShellView: View {
    @State private var selection: NellAppSection = .today
    @State private var presentedSheet: NellAppSheet?

    var body: some View {
        ZStack(alignment: .bottom) {
            NellPalette.background
                .ignoresSafeArea()

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: Theme.Size.tabBarHeight + Theme.Spacing.sm)
                }

            NellTabBar(selection: $selection) {
                presentedSheet = .log
            }
        }
        .tint(NellPalette.primary)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .log:
                NellLogSheetView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(NellPalette.groupedBackground)
            }
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selection {
        case .today:
            NavigationStack { NellTodayView() }
        case .log:
            NavigationStack { NellTodayView() }
        case .coach:
            NavigationStack { NellCoachScreen() }
        case .nutrition:
            NavigationStack { NellNutritionView() }
        case .train:
            NavigationStack { NellTrainHomeView() }
        }
    }
}

private enum NellAppSheet: String, Identifiable {
    case log
    var id: String { rawValue }
}

private enum NellAppSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case log = "Log"
    case coach = "Coach"
    case nutrition = "Nutrition"
    case train = "Train"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: return "house"
        case .log: return "square.and.pencil"
        case .coach: return ""
        case .nutrition: return "fork.knife"
        case .train: return "figure.strengthtraining.traditional"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .today: return "house.fill"
        case .log: return "square.and.pencil"
        case .coach: return ""
        case .nutrition: return "fork.knife"
        case .train: return "figure.strengthtraining.traditional"
        }
    }
}

private struct NellTabBar: View {
    @Binding var selection: NellAppSection
    let onLog: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            standardTab(.today)
            standardTab(.log)
            coachTab
            standardTab(.nutrition)
            standardTab(.train)
        }
        .frame(height: Theme.Size.tabBarHeight)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(.ultraThinMaterial)
        .background(NellPalette.surface.opacity(colorScheme == .dark ? 0.97 : 0.95))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NellPalette.border)
                .frame(height: Theme.Border.standard)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func standardTab(_ section: NellAppSection) -> some View {
        Button {
            if section == .log {
                onLog()
            } else {
                select(section)
            }
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: selection == section ? section.selectedSymbol : section.symbol)
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
            select(.coach)
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                ZStack {
                    Circle()
                        .fill(selection == .coach ? NellPalette.forest : NellPalette.primary)

                    Circle()
                        .stroke(NellPalette.surface, lineWidth: Theme.Border.coachKeyline)

                    NellCoachMark()
                        .foregroundStyle(Color.white)
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

                Text(NellAppSection.coach.rawValue)
                    .font(Theme.FontToken.tabLabel)
                    .foregroundStyle(selection == .coach ? NellPalette.primary : NellPalette.textTertiary)
                    .offset(y: Theme.Size.coachTabVerticalOffset)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Coach")
        .accessibilityHint("Open Nell Coach")
    }

    private func select(_ section: NellAppSection) {
        guard section != selection else { return }
        if reduceMotion {
            selection = section
        } else {
            withAnimation(.easeInOut(duration: Theme.Motion.tabTransition)) {
                selection = section
            }
        }
    }
}

#Preview {
    NellAppShellView()
        .modelContainer(PersistenceController.preview.container)
}
