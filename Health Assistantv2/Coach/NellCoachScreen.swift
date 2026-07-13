import SwiftUI

struct NellCoachScreen: View {
    var body: some View {
        VStack(spacing: 0) {
            coachHeader
            Divider()
            ChatView()
                .toolbar(.hidden, for: .navigationBar)
        }
        .background(NellPalette.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Coach settings")
            }
        }
    }

    private var coachHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            NellMascotView(pose: .wave)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    NellCoachMark()
                        .foregroundStyle(NellPalette.primary)
                        .frame(width: 24, height: 24)

                    Text("Coach")
                        .font(Theme.FontToken.navigationTitle)
                        .foregroundStyle(NellPalette.textPrimary)
                }

                Text("Guidance grounded in your confirmed profile and logs.")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, NellLayout.screenPadding)
        .padding(.vertical, Theme.Spacing.sm)
        .background(NellPalette.surface)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { NellCoachScreen() }
        .modelContainer(PersistenceController.preview.container)
}
