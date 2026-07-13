import SwiftUI

/// Small-size, single-colour Care Companion mark used for the Coach tab,
/// confirmations, loading, and compact brand moments.
struct NellCoachMark: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .frame(width: size * 0.22, height: size * 0.22)
                    .offset(y: -size * 0.28)

                HStack(spacing: size * 0.03) {
                    NellCompanionLeaf()
                    NellCompanionLeaf()
                        .scaleEffect(x: -1, y: 1)
                }
                .frame(width: size * 0.72, height: size * 0.48)
                .offset(y: size * 0.13)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

private struct NellCompanionLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY * 0.72),
            control1: CGPoint(x: rect.maxX * 0.72, y: rect.minY),
            control2: CGPoint(x: rect.minX, y: rect.maxY * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control1: CGPoint(x: rect.maxX * 0.12, y: rect.maxY),
            control2: CGPoint(x: rect.maxX * 0.90, y: rect.maxY * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

/// Flat SwiftUI reconstruction of the Shell Bowl mark. Production raster artwork
/// can replace it in marketing and the app icon, while this version remains useful
/// for small UI states and missing-asset fallbacks.
struct NellShellBowlMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                ringSegment(from: 0.03, to: 0.20, colour: NellPalette.primary)
                ringSegment(from: 0.23, to: 0.43, colour: NellPalette.moss.opacity(0.86))
                ringSegment(from: 0.47, to: 0.62, colour: NellPalette.amber)
                ringSegment(from: 0.66, to: 0.82, colour: NellPalette.moss.opacity(0.72))
                ringSegment(from: 0.85, to: 0.98, colour: NellPalette.primary.opacity(0.80))

                Ellipse()
                    .fill(colorScheme == .dark ? NellPalette.forest : NellPalette.forest)
                    .frame(width: size * 0.46, height: size * 0.34)
                    .offset(y: -size * 0.03)

                RoundedRectangle(cornerRadius: size * 0.11, style: .continuous)
                    .fill(colorScheme == .dark ? Theme.ColorToken.textPrimary : NellPalette.cream)
                    .frame(width: size * 0.43, height: size * 0.36)
                    .offset(y: size * 0.22)

                Ellipse()
                    .fill(NellPalette.primary.opacity(0.88))
                    .frame(width: size * 0.35, height: size * 0.14)
                    .offset(y: size * 0.07)

                NellCoachMark()
                    .foregroundStyle(NellPalette.primary)
                    .frame(width: size * 0.15, height: size * 0.15)
                    .offset(y: size * 0.26)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NellBrand.accessibilityDescription)
    }

    private func ringSegment(from: CGFloat, to: CGFloat, colour: Color) -> some View {
        Circle()
            .trim(from: from, to: to)
            .stroke(
                colour,
                style: StrokeStyle(lineWidth: 18, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .padding(12)
    }
}

struct NellBrandLockup: View {
    var compact = false
    var showsDescriptor = true

    var body: some View {
        HStack(spacing: compact ? Theme.Spacing.sm : Theme.Spacing.md) {
            NellShellBowlMark()
                .frame(width: compact ? 42 : 64, height: compact ? 42 : 64)

            VStack(alignment: .leading, spacing: compact ? 0 : 2) {
                Text(NellBrand.productName)
                    .font(.system(
                        size: compact ? 28 : 42,
                        weight: .semibold,
                        design: .serif
                    ))
                    .foregroundStyle(NellPalette.forest)
                    .lineLimit(1)

                if showsDescriptor {
                    Text(NellBrand.descriptor)
                        .font(compact ? Theme.FontToken.caption : Theme.FontToken.secondaryBody)
                        .foregroundStyle(NellPalette.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(NellBrand.accessibilityDescription)
    }
}

#Preview("Nell marks") {
    VStack(spacing: 32) {
        NellBrandLockup()
        NellShellBowlMark()
            .frame(width: 120, height: 120)
        NellCoachMark()
            .foregroundStyle(NellPalette.primary)
            .frame(width: 52, height: 52)
    }
    .padding()
    .background(NellPalette.background)
}
