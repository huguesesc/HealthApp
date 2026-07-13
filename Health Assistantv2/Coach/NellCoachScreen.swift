import SwiftUI

struct NellCoachScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            coachHeader
            Divider()
            ChatView()
                .padding(.bottom, Theme.Size.tabBarHeight + Theme.Spacing.sm)
                .toolbar(.hidden, for: .navigationBar)
        }
        .background(NellPalette.background)
    }

    private var coachHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            NellMascotView(pose: .thoughtful)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    NellAssetImage(asset: .coachMark)
                        .frame(width: 28, height: 28)

                    Text("Nell")
                        .font(Theme.FontToken.navigationTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                }

                Text("Guidance grounded in your confirmed profile and logs.")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
            NellSettingsLogoButton()
        }
        .padding(.horizontal, NellLayout.screenPadding)
        .padding(.vertical, Theme.Spacing.sm)
        .background(NellPalette.surface)
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack { NellCoachScreen() }
        .modelContainer(PersistenceController.preview.container)
}
