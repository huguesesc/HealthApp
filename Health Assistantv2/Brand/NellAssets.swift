import SwiftUI
import UIKit

/// Asset names are centralised so artwork can be replaced without changing views.
/// The asset catalogue may be populated incrementally; every asset has a safe
/// fallback while production exports are being prepared.
enum NellAsset: String, CaseIterable, Identifiable, Sendable {
    case logoFullColor = "NellLogoFullColor"
    case logoMonochrome = "NellLogoMonochrome"
    case appIconReference = "NellAppIconReference"
    case coachMark = "NellCoachMark"

    case mascotThoughtful = "NellMascotThoughtful"
    case mascotWave = "NellMascotWave"
    case mascotNutrition = "NellMascotNutrition"
    case mascotTraining = "NellMascotTraining"
    case mascotRecovery = "NellMascotRecovery"
    case mascotProgress = "NellMascotProgress"
    case mascotBalance = "NellMascotBalance"
    case mascotSuccess = "NellMascotSuccess"

    var id: String { rawValue }

    var fallbackSymbol: String {
        switch self {
        case .logoFullColor, .logoMonochrome, .appIconReference:
            return "circle.hexagongrid.fill"
        case .coachMark:
            return "heart.circle.fill"
        case .mascotThoughtful:
            return "lightbulb.fill"
        case .mascotWave:
            return "hand.wave.fill"
        case .mascotNutrition:
            return "fork.knife"
        case .mascotTraining:
            return "figure.strengthtraining.traditional"
        case .mascotRecovery:
            return "leaf.fill"
        case .mascotProgress:
            return "chart.line.uptrend.xyaxis"
        case .mascotBalance:
            return "figure.mind.and.body"
        case .mascotSuccess:
            return "checkmark.seal.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .logoFullColor, .logoMonochrome, .appIconReference:
            return NellBrand.accessibilityDescription
        case .coachMark:
            return "Nell Coach"
        default:
            return NellBrand.mascotAccessibilityLabel
        }
    }

    var isMascot: Bool {
        switch self {
        case .mascotThoughtful, .mascotWave, .mascotNutrition, .mascotTraining,
             .mascotRecovery, .mascotProgress, .mascotBalance, .mascotSuccess:
            return true
        default:
            return false
        }
    }
}

enum NellMascotPose: String, CaseIterable, Identifiable, Sendable {
    case thoughtful
    case wave
    case nutrition
    case training
    case recovery
    case progress
    case balance
    case success

    var id: String { rawValue }

    var asset: NellAsset {
        switch self {
        case .thoughtful: return .mascotThoughtful
        case .wave: return .mascotWave
        case .nutrition: return .mascotNutrition
        case .training: return .mascotTraining
        case .recovery: return .mascotRecovery
        case .progress: return .mascotProgress
        case .balance: return .mascotBalance
        case .success: return .mascotSuccess
        }
    }
}

struct NellAssetImage: View {
    let asset: NellAsset
    var contentMode: ContentMode = .fit
    var accessibilityLabel: String?

    var body: some View {
        Group {
            if let image = UIImage(named: asset.rawValue) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                fallback
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel ?? asset.accessibilityLabel)
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: NellLayout.cardRadius, style: .continuous)
                .fill(NellPalette.elevatedSurface)

            if asset.isMascot {
                NellShellBowlMark()
                    .frame(width: 54, height: 54)
            } else if asset == .coachMark {
                NellCoachMark()
                    .foregroundStyle(NellPalette.primary)
                    .padding(18)
            } else {
                Image(systemName: asset.fallbackSymbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(NellPalette.primary)
                    .padding(20)
            }
        }
    }
}

struct NellMascotView: View {
    let pose: NellMascotPose
    var contentMode: ContentMode = .fit

    var body: some View {
        NellAssetImage(
            asset: pose.asset,
            contentMode: contentMode,
            accessibilityLabel: "\(NellBrand.mascotAccessibilityLabel), \(pose.rawValue) pose"
        )
    }
}
