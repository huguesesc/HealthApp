import SwiftUI

/// Keeps the existing Coach engine and confirmation behaviour while giving the
/// destination a stable Nell identity. ChatView remains responsible for messages,
/// Markdown rendering, tool proposals and write confirmations.
struct NellCoachHomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(NellPalette.border)
            ChatView()
        }
        .background(NellPalette.background)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Coach settings")
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(NellPalette.primary)
                NellCoachMark()
                    .foregroundStyle(Color.white)
                    .padding(10)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Coach")
                    .font(Theme.FontToken.sectionTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Text("Guidance based on the context you choose to share")
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: Theme.Spacing.sm)
        }
        .padding(.horizontal, NellLayout.screenPadding)
        .padding(.vertical, Theme.Spacing.sm)
        .background(NellPalette.surface)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        NellCoachHomeView()
    }
    .modelContainer(PersistenceController.preview.container)
}
