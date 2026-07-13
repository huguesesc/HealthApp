import SwiftUI

struct NellEmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(NellPalette.primary)
                .frame(width: 64, height: 64)
                .background(NellPalette.primary.opacity(0.10), in: Circle())

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.nellPrimary)
            }
        }
        .padding(Theme.Spacing.screen)
        .frame(maxWidth: .infinity)
        .background(
            NellPalette.surface,
            in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NellErrorState: View {
    let title: String
    let message: String
    var retryTitle: String = "Try again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(NellPalette.destructive)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Text(message)
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retry {
                Button(retryTitle, action: retry)
                    .buttonStyle(.nellDestructive)
            }
        }
        .padding(Theme.Spacing.screen)
        .frame(maxWidth: .infinity)
        .background(
            NellPalette.surface,
            in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                .stroke(NellPalette.destructive.opacity(0.24), lineWidth: Theme.Border.standard)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NellConfirmationCard: View {
    let title: String
    let message: String
    var actionTitle: String = "Done"
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(NellPalette.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 58, height: 58)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Text(message)
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.nellPrimary)
            }
        }
        .padding(Theme.Spacing.screen)
        .frame(maxWidth: .infinity)
        .background(
            NellPalette.primary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                .stroke(NellPalette.primary.opacity(0.22), lineWidth: Theme.Border.standard)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NellCoachSuggestionCard: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            NellCoachMark()
                .foregroundStyle(NellPalette.primary)
                .frame(width: 34, height: 34)
                .padding(7)
                .background(NellPalette.primary.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                Text(message)
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(Theme.FontToken.secondaryBody.weight(.semibold))
                        .foregroundStyle(NellPalette.primary)
                        .padding(.top, Theme.Spacing.xxs)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(
            NellPalette.primary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                .stroke(NellPalette.primary.opacity(0.20), lineWidth: Theme.Border.standard)
        }
    }
}

struct NellMascotHero: View {
    let pose: NellMascotPose
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            NellMascotView(pose: pose)
                .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.FontToken.sectionTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                Text(message)
                    .font(Theme.FontToken.secondaryBody)
                    .foregroundStyle(NellPalette.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .background(
            NellPalette.elevatedSurface,
            in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
        )
    }
}

struct NellThinkingIndicator: View {
    var label = "Thinking…"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            NellCoachMark()
                .foregroundStyle(NellPalette.primary)
                .frame(width: 26, height: 26)
                .opacity(reduceMotion ? 1 : (isPulsing ? 1 : 0.55))

            Text(label)
                .font(Theme.FontToken.secondaryBody)
                .foregroundStyle(NellPalette.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(NellPalette.surface, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Nell states") {
    ScrollView {
        VStack(spacing: 20) {
            NellEmptyState(
                title: "No logs yet",
                message: "Start by logging a meal, workout, sleep, or check-in."
            )
            NellCoachSuggestionCard(
                title: "A small next step",
                message: "A ten-minute walk would add some light movement to today."
            )
            NellConfirmationCard(
                title: "Logged",
                message: "Your entry has been saved."
            )
            NellThinkingIndicator()
        }
        .padding()
    }
    .background(NellPalette.background)
}
