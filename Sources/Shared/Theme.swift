import SwiftUI
import UIKit

/// Implementation tokens for the current Health Assistant visual-identity cycle.
/// Colours are dynamic and match the approved light/dark specification.
enum Theme {
    enum ColorToken {
        static let brandPrimary = dynamic(light: 0x2E5C47, dark: 0x8FB39B)
        static let brandPrimaryPressed = dynamic(light: 0x1F3A2E, dark: 0x6A8F72)
        static let brandSecondary = dynamic(light: 0xE6C07A, dark: 0xE6C07A)
        static let nutrition = dynamic(light: 0x557F60, dark: 0x8EAE82)
        static let training = dynamic(light: 0xA9552C, dark: 0xD98A58)
        static let sleep = dynamic(light: 0x5D5A8E, dark: 0x9A95C6)
        static let warning = dynamic(light: 0x9A6500, dark: 0xE1AE53)
        static let destructive = dynamic(light: 0xB84A4A, dark: 0xE07272)
        static let backgroundPrimary = dynamic(light: 0xF7F3EC, dark: 0x0E1511)
        static let backgroundSecondary = dynamic(light: 0xEFE9DE, dark: 0x131D17)
        static let surfacePrimary = dynamic(light: 0xFFFFFF, dark: 0x18231D)
        static let surfaceSecondary = dynamic(light: 0xF2E9DB, dark: 0x1F2C24)
        static let border = dynamic(light: 0xD8D2C7, dark: 0x314238)
        static let textPrimary = dynamic(light: 0x16231C, dark: 0xF7F3EC)
        static let textSecondary = dynamic(light: 0x4F5C55, dark: 0xC7D0CA)
        static let textTertiary = dynamic(light: 0x7B857F, dark: 0x8F9B94)

        private static func dynamic(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }

    enum FontToken {
        static let largeScreenTitle = Font.system(size: 34, weight: .bold)
        static let navigationTitle = Font.system(size: 28, weight: .semibold)
        static let sectionTitle = Font.system(size: 22, weight: .semibold)
        static let cardTitle = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let secondaryBody = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 12, weight: .medium)
        static let metric = Font.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit()
        static let button = Font.system(size: 17, weight: .semibold)
        static let tabLabel = Font.system(size: 10, weight: .medium)
        static let coachResponse = Font.system(size: 17, weight: .regular)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let screen: CGFloat = 20
        static let section: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
        static let button: CGFloat = 14
    }

    enum Size {
        static let minimumTouchTarget: CGFloat = 44
        static let buttonHeight: CGFloat = 50
        static let compactButtonHeight: CGFloat = 36
        static let icon: CGFloat = 20
        static let tabIcon: CGFloat = 22
        static let prominentIcon: CGFloat = 28
        static let coachIcon: CGFloat = 26
        static let tabBarHeight: CGFloat = 74
        static let coachTabDiameter: CGFloat = 60
        static let coachTabVerticalOffset: CGFloat = -10
    }

    enum Border {
        static let standard: CGFloat = 1
        static let focused: CGFloat = 2
        static let coachKeyline: CGFloat = 3
    }

    enum Motion {
        static let tabTransition: Double = 0.20
        static let buttonPress: Double = 0.08
        static let buttonRelease: Double = 0.14
        static let buttonPressedScale: CGFloat = 0.98
        static let coachPressedScale: CGFloat = 0.96
    }

    enum Opacity {
        static let disabled: Double = 0.45
        static let subtleTint: Double = 0.10
        static let lightShadow: Double = 0.14
        static let darkShadow: Double = 0.24
    }

    // Compatibility aliases used by existing screens while they are migrated.
    static let evergreen = ColorToken.brandPrimary
    static let moss = ColorToken.nutrition
    static let clay = ColorToken.training
    static let honey = ColorToken.brandSecondary

    static func statFont(size: CGFloat = 28) -> Font {
        .system(size: size, weight: .semibold, design: .rounded).monospacedDigit()
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.ColorToken.surfacePrimary,
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .stroke(Theme.ColorToken.border, lineWidth: Theme.Border.standard)
            }
    }
}

extension View {
    func card() -> some View {
        modifier(CardBackground())
    }
}
