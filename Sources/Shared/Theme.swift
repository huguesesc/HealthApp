import SwiftUI

/// The app's visual identity: a calm, botanical palette (deep evergreen, warm
/// clay, soft moss) over system grouped backgrounds so dark mode keeps working.
/// Use these instead of ad-hoc colors so every screen reads as one product.
enum Theme {
    /// Primary brand color and global tint. Deep, calm evergreen.
    static let evergreen = Color(red: 0.13, green: 0.33, blue: 0.27)
    /// Softer green for secondary fills and icons.
    static let moss = Color(red: 0.42, green: 0.56, blue: 0.45)
    /// Warm terracotta accent — streaks, highlights, the "alive" color.
    static let clay = Color(red: 0.78, green: 0.44, blue: 0.32)
    /// Muted gold for confidence / caution notes.
    static let honey = Color(red: 0.80, green: 0.62, blue: 0.29)

    /// Rounded numerals for stats so numbers feel friendly and consistent.
    static func statFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

/// Standard card container used across the dashboard and chat cards.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}
