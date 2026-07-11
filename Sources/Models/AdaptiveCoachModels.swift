import Foundation
import SwiftData

// MARK: - Profile enums

enum CoachUnitSystem: String, CaseIterable, Codable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var displayName: String { self == .metric ? "Metric" : "Imperial" }
}

enum CoachGoal: String, CaseIterable, Codable, Identifiable {
    case generalHealth = "general_health"
    case buildStrength = "build_strength"
    case buildMuscle = "build_muscle"
    case loseFat = "lose_fat"
    case improveEndurance = "improve_endurance"
    case improveMobility = "improve_mobility"
    case returnToSport = "return_to_sport"
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalHealth: "General health"
        case .buildStrength: "Build strength"
        case .buildMuscle: "Build muscle"
        case .loseFat: "Lose fat"
        case .improveEndurance: "Improve endurance"
        case .improveMobility: "Improve mobility"
        case .returnToSport: "Return to sport"
        case .custom: "Custom"
        }
    }
}

enum CoachExperienceLevel: String, CaseIterable, Codable, Identifiable {
    case beginner
    case intermediate
    case advanced
    case returning = "returning_after_break"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        case .returning: "Returning after a break"
        }
    }
}

enum BodySide: String, CaseIterable, Codable, Identifiable {
    case left
    case right
    case both
    case central
    case unspecified

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum HealthBodyArea: String, CaseIterable, Codable, Identifiable {
    case neck
    case shoulder
    case elbow
    case wrist
    case hand
    case upperBack = "upper_back"
    case lowerBack = "lower_back"
    case hip
    case knee
    case ankle
    case foot
    case core
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upperBack: "Upper back"
        case .lowerBack: "Lower back"
        default: rawValue.capitalized
        }
    }
}

enum HealthConsiderationCategory: String, CaseIterable, Codable, Identifiable {
    case previousSurgery = "previous_surgery"
    case previousInjury = "previous_injury"
    case weakness
    case instability
    case uncomfortableMovement = "uncomfortable_movement"
    case clinicianGuidance = "clinician_guidance"
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previousSurgery: "Previous surgery"
        case .previousInjury: "Previous injury"
        case .weakness: "Feels weaker"
        case .instability: "Feels less stable"
        case .uncomfortableMovement: "Uncomfortable movement"
        case .clinicianGuidance: "Clinician guidance"
        case .custom: "Other consideration"
        }
    }
}

enum HealthConsiderationStatus: String, CaseIterable, Codable, Identifiable {
    case active
    case monitoring
    case archived

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum HealthConsiderationSource: String, Codable {
    case userEntered = "user_entered"
}

enum BodyMetricSource: String, Codable {
    case manual
    case healthKit = "health_kit"
}

// MARK: - Workout environment enums

enum WorkoutLocationCategory: String, CaseIterable, Codable, Identifiable {
    case home
    case gym
    case outdoors
    case travel
    case sportVenue = "sport_venue"
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sportVenue: "Sport venue"
        default: rawValue.capitalized
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .gym: "dumbbell"
        case .outdoors: "leaf"
        case .travel: "suitcase"
        case .sportVenue: "sportscourt"
        case .custom: "mappin"
        }
    }
}

enum EquipmentCapability: String, Codable {
    case strength
    case cardio
    case balance
    case mobility
    case support
}

enum EquipmentCategory: String, CaseIterable, Codable, Identifiable {
    case bodyweight
    case yogaMat = "yoga_mat"
    case stabilityBall = "stability_ball"
    case miniResistanceBands = "mini_resistance_bands"
    case longResistanceBands = "long_resistance_bands"
    case foamBalancePad = "foam_balance_pad"
    case wobbleBoard = "wobble_board"
    case balanceDisc = "balance_disc"
    case bosuTrainer = "bosu_trainer"
    case slantBoard = "slant_board"
    case dumbbells
    case kettlebells
    case barbell
    case squatRack = "squat_rack"
    case cableStation = "cable_station"
    case legPress = "leg_press"
    case hamstringCurl = "hamstring_curl"
    case stationaryBike = "stationary_bike"
    case treadmill
    case rowingMachine = "rowing_machine"
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyweight: "Bodyweight"
        case .yogaMat: "Yoga mat"
        case .stabilityBall: "Stability ball"
        case .miniResistanceBands: "Mini resistance bands"
        case .longResistanceBands: "Long resistance bands"
        case .foamBalancePad: "Foam balance pad"
        case .wobbleBoard: "Wobble board"
        case .balanceDisc: "Balance disc"
        case .bosuTrainer: "BOSU-style trainer"
        case .slantBoard: "Slant board"
        case .dumbbells: "Dumbbells"
        case .kettlebells: "Kettlebells"
        case .barbell: "Barbell"
        case .squatRack: "Squat rack"
        case .cableStation: "Cable station"
        case .legPress: "Leg press"
        case .hamstringCurl: "Hamstring curl"
        case .stationaryBike: "Stationary bike"
        case .treadmill: "Treadmill"
        case .rowingMachine: "Rowing machine"
        case .custom: "Custom equipment"
        }
    }

    var defaultCapability: EquipmentCapability {
        switch self {
        case .stationaryBike, .treadmill, .rowingMachine:
            .cardio
        case .foamBalancePad, .wobbleBoard, .balanceDisc, .bosuTrainer:
            .balance
        case .yogaMat, .stabilityBall, .slantBoard:
            .mobility
        case .bodyweight:
            .support
        default:
            .strength
        }
    }
}

// MARK: - SwiftData entities

@Model
final class HealthProfile {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var unitSystemRaw: String
    var primaryGoalRaw: String
    var goalDetail: String?
    var experienceLevelRaw: String
    var preferredActivitiesText: String?
    var weeklyTrainingDays: Int?
    var preferredSessionMinutes: Int?
    var generalPreferences: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        unitSystem: CoachUnitSystem = .metric,
        primaryGoal: CoachGoal = .generalHealth,
        experienceLevel: CoachExperienceLevel = .beginner
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.unitSystemRaw = unitSystem.rawValue
        self.primaryGoalRaw = primaryGoal.rawValue
        self.experienceLevelRaw = experienceLevel.rawValue
    }

    var unitSystem: CoachUnitSystem {
        CoachUnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    var primaryGoal: CoachGoal {
        CoachGoal(rawValue: primaryGoalRaw) ?? .generalHealth
    }

    var experienceLevel: CoachExperienceLevel {
        CoachExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner
    }

    var preferredActivities: [String] {
        (preferredActivitiesText ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

@Model
final class HealthConsideration {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var bodyAreaRaw: String
    var sideRaw: String
    var categoryRaw: String
    var userDescription: String
    var statusRaw: String
    var sourceRaw: String
    var approximateWhen: String?
    var userGuidance: String?
    var confirmedByUser: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        title: String,
        bodyArea: HealthBodyArea = .other,
        side: BodySide = .unspecified,
        category: HealthConsiderationCategory = .custom,
        userDescription: String,
        status: HealthConsiderationStatus = .active,
        approximateWhen: String? = nil,
        userGuidance: String? = nil,
        confirmedByUser: Bool = true
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.bodyAreaRaw = bodyArea.rawValue
        self.sideRaw = side.rawValue
        self.categoryRaw = category.rawValue
        self.userDescription = userDescription
        self.statusRaw = status.rawValue
        self.sourceRaw = HealthConsiderationSource.userEntered.rawValue
        self.approximateWhen = approximateWhen
        self.userGuidance = userGuidance
        self.confirmedByUser = confirmedByUser
    }

    var bodyArea: HealthBodyArea { HealthBodyArea(rawValue: bodyAreaRaw) ?? .other }
    var side: BodySide { BodySide(rawValue: sideRaw) ?? .unspecified }
    var category: HealthConsiderationCategory {
        HealthConsiderationCategory(rawValue: categoryRaw) ?? .custom
    }
    var status: HealthConsiderationStatus {
        HealthConsiderationStatus(rawValue: statusRaw) ?? .active
    }
}

@Model
final class BodyMetricEntry {
    var id: UUID
    var timestamp: Date
    var weightKilograms: Double?
    var heightCentimeters: Double?
    var sourceRaw: String
    var note: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        weightKilograms: Double? = nil,
        heightCentimeters: Double? = nil,
        source: BodyMetricSource = .manual,
        note: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weightKilograms = weightKilograms
        self.heightCentimeters = heightCentimeters
        self.sourceRaw = source.rawValue
        self.note = note
    }
}

@Model
final class WorkoutLocation {
    var id: UUID
    var name: String
    var categoryRaw: String
    var notes: String?
    var spaceLimitations: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \EquipmentItem.location)
    var equipment: [EquipmentItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: WorkoutLocationCategory = .home,
        notes: String? = nil,
        spaceLimitations: String? = nil,
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.spaceLimitations = spaceLimitations
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: WorkoutLocationCategory {
        WorkoutLocationCategory(rawValue: categoryRaw) ?? .custom
    }
}

@Model
final class EquipmentItem {
    var id: UUID
    var name: String
    var categoryRaw: String
    var quantity: Int
    var minWeightKilograms: Double?
    var maxWeightKilograms: Double?
    var resistanceDescription: String?
    var isAvailable: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var location: WorkoutLocation?

    init(
        id: UUID = UUID(),
        name: String,
        category: EquipmentCategory = .custom,
        quantity: Int = 1,
        minWeightKilograms: Double? = nil,
        maxWeightKilograms: Double? = nil,
        resistanceDescription: String? = nil,
        isAvailable: Bool = true,
        notes: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        location: WorkoutLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.quantity = max(quantity, 1)
        self.minWeightKilograms = minWeightKilograms
        self.maxWeightKilograms = maxWeightKilograms
        self.resistanceDescription = resistanceDescription
        self.isAvailable = isAvailable
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.location = location
    }

    var category: EquipmentCategory {
        EquipmentCategory(rawValue: categoryRaw) ?? .custom
    }

    var capability: EquipmentCapability { category.defaultCapability }
}
