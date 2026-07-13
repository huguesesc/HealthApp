import SwiftUI

/// Product-level brand constants. Keep visible naming here so screens do not
/// independently hard-code the product name or descriptor.
enum NellBrand {
    static let productName = "Nell"
    static let descriptor = "Your personal health companion"
    static let appStoreTitle = "Nell: AI Health & Fitness Coach"
    static let coachName = "Coach"

    static let accessibilityDescription =
        "Nell, your personal health companion"

    /// The tortoise remains a supporting companion rather than the product logo.
    static let mascotAccessibilityLabel = "Nell's tortoise companion"
}

/// Semantic aliases for the approved visual system. Existing Theme tokens remain
/// the source of truth while older screens are migrated incrementally.
enum NellPalette {
    static let forest = Theme.ColorToken.brandPrimaryPressed
    static let primary = Theme.ColorToken.brandPrimary
    static let moss = Theme.ColorToken.nutrition
    static let cream = Theme.ColorToken.surfaceSecondary
    static let amber = Theme.ColorToken.brandSecondary

    static let background = Theme.ColorToken.backgroundPrimary
    static let groupedBackground = Theme.ColorToken.backgroundSecondary
    static let surface = Theme.ColorToken.surfacePrimary
    static let elevatedSurface = Theme.ColorToken.surfaceSecondary
    static let border = Theme.ColorToken.border

    static let textPrimary = Theme.ColorToken.textPrimary
    static let textSecondary = Theme.ColorToken.textSecondary
    static let textTertiary = Theme.ColorToken.textTertiary

    static let nutrition = Theme.ColorToken.nutrition
    static let training = Theme.ColorToken.training
    static let sleep = Theme.ColorToken.sleep
    static let warning = Theme.ColorToken.warning
    static let destructive = Theme.ColorToken.destructive
}

/// Shared layout constants specific to the Nell component layer.
enum NellLayout {
    static let screenPadding = Theme.Spacing.screen
    static let sectionSpacing = Theme.Spacing.section
    static let cardPadding = Theme.Spacing.md
    static let compactSpacing = Theme.Spacing.xs

    static let cardRadius = Theme.Radius.medium
    static let featuredRadius = Theme.Radius.large
    static let buttonRadius = Theme.Radius.button

    static let minimumTouchTarget = Theme.Size.minimumTouchTarget
    static let primaryButtonHeight = Theme.Size.buttonHeight
}
