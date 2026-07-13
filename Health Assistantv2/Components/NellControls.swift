import SwiftUI

struct NellPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.FontToken.button)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: NellLayout.primaryButtonHeight)
            .padding(.horizontal, Theme.Spacing.md)
            .background(
                isEnabled
                    ? (configuration.isPressed
                        ? Theme.ColorToken.brandPrimaryPressed
                        : Theme.ColorToken.brandPrimary)
                    : Theme.ColorToken.brandPrimary.opacity(Theme.Opacity.disabled),
                in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
            )
            .scaleEffect(reduceMotion || !configuration.isPressed
                ? 1
                : Theme.Motion.buttonPressedScale)
            .animation(
                reduceMotion ? nil : .easeOut(duration: Theme.Motion.buttonPress),
                value: configuration.isPressed
            )
    }
}

struct NellSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.FontToken.button)
            .foregroundStyle(isEnabled
                ? Theme.ColorToken.brandPrimary
                : Theme.ColorToken.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: NellLayout.primaryButtonHeight)
            .padding(.horizontal, Theme.Spacing.md)
            .background(
                configuration.isPressed
                    ? Theme.ColorToken.surfaceSecondary
                    : Theme.ColorToken.surfacePrimary,
                in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
                    .stroke(Theme.ColorToken.border, lineWidth: Theme.Border.standard)
            }
            .opacity(isEnabled ? 1 : Theme.Opacity.disabled)
            .scaleEffect(reduceMotion || !configuration.isPressed
                ? 1
                : Theme.Motion.buttonPressedScale)
            .animation(
                reduceMotion ? nil : .easeOut(duration: Theme.Motion.buttonPress),
                value: configuration.isPressed
            )
    }
}

struct NellDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.FontToken.button)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: NellLayout.primaryButtonHeight)
            .padding(.horizontal, Theme.Spacing.md)
            .background(
                Theme.ColorToken.destructive.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
            )
            .opacity(isEnabled ? 1 : Theme.Opacity.disabled)
    }
}

struct NellTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String?
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.FontToken.caption)
                .foregroundStyle(NellPalette.textSecondary)

            TextField(prompt ?? title, text: $text, axis: axis)
                .lineLimit(lineLimit)
                .font(Theme.FontToken.body)
                .foregroundStyle(NellPalette.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .frame(minHeight: NellLayout.minimumTouchTarget)
                .background(
                    NellPalette.surface,
                    in: RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: NellLayout.buttonRadius, style: .continuous)
                        .stroke(NellPalette.border, lineWidth: Theme.Border.standard)
                }
        }
    }
}

enum NellStatusTone: Sendable {
    case neutral
    case positive
    case attention
    case destructive
    case informational

    var colour: Color {
        switch self {
        case .neutral: return NellPalette.textSecondary
        case .positive: return NellPalette.nutrition
        case .attention: return NellPalette.warning
        case .destructive: return NellPalette.destructive
        case .informational: return NellPalette.sleep
        }
    }

    var symbol: String {
        switch self {
        case .neutral: return "circle.fill"
        case .positive: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .destructive: return "xmark.octagon.fill"
        case .informational: return "info.circle.fill"
        }
    }
}

struct NellStatusChip: View {
    let title: String
    var tone: NellStatusTone = .neutral
    var showsSymbol = true

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if showsSymbol {
                Image(systemName: tone.symbol)
                    .font(.caption2)
            }
            Text(title)
                .font(Theme.FontToken.caption)
                .lineLimit(1)
        }
        .foregroundStyle(tone.colour)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            tone.colour.opacity(0.10),
            in: Capsule(style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

extension ButtonStyle where Self == NellPrimaryButtonStyle {
    static var nellPrimary: NellPrimaryButtonStyle { NellPrimaryButtonStyle() }
}

extension ButtonStyle where Self == NellSecondaryButtonStyle {
    static var nellSecondary: NellSecondaryButtonStyle { NellSecondaryButtonStyle() }
}

extension ButtonStyle where Self == NellDestructiveButtonStyle {
    static var nellDestructive: NellDestructiveButtonStyle { NellDestructiveButtonStyle() }
}
