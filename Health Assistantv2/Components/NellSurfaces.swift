import SwiftUI

struct NellScreen<Content: View>: View {
    private let content: Content
    private let showsScrollIndicators: Bool

    init(
        showsScrollIndicators: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.showsScrollIndicators = showsScrollIndicators
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: showsScrollIndicators) {
            VStack(alignment: .leading, spacing: NellLayout.sectionSpacing) {
                content
            }
            .padding(.horizontal, NellLayout.screenPadding)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Size.tabBarHeight + Theme.Spacing.xl)
        }
        .background(NellPalette.background)
    }
}

struct NellCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(
        padding: CGFloat = NellLayout.cardPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NellPalette.surface,
                in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                    .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
            }
    }
}

struct NellFeaturedCard<Content: View>: View {
    let tint: Color
    private let content: Content

    init(
        tint: Color = NellPalette.primary,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.Spacing.screen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    NellPalette.surface
                    tint.opacity(Theme.Opacity.subtleTint)
                },
                in: RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NellLayout.featuredRadius, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: Theme.Border.standard)
            }
    }
}

struct NellSectionHeader: View {
    let title: String
    var subtitle: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.FontToken.sectionTitle)
                    .foregroundStyle(NellPalette.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Theme.FontToken.secondaryBody.weight(.semibold))
                    .foregroundStyle(NellPalette.primary)
            }
        }
    }
}

struct NellMetricTile: View {
    let title: String
    let value: String
    var detail: String?
    var systemImage: String?
    var tint: Color = NellPalette.primary

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textSecondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(Theme.FontToken.metric)
                .foregroundStyle(NellPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            if let detail {
                Text(detail)
                    .font(Theme.FontToken.caption)
                    .foregroundStyle(NellPalette.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(
            NellPalette.surface,
            in: RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
        }
        .accessibilityElement(children: .combine)
    }
}

struct NellProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = NellPalette.primary
    var centreText: String?

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(NellPalette.border.opacity(0.65), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if let centreText {
                Text(centreText)
                    .font(Theme.FontToken.cardTitle)
                    .foregroundStyle(NellPalette.textPrimary)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(clampedProgress * 100)) percent")
    }
}

struct NellMiniBarChart: View {
    let values: [Double]
    var tint: Color = NellPalette.primary

    private var maximum: Double {
        max(values.max() ?? 1, 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.xxs) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(tint.opacity(value <= 0 ? 0.16 : 0.86))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(4, 44 * max(value, 0) / maximum))
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trend chart")
    }
}
