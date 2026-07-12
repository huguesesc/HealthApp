import Foundation

extension WorkoutAvatarEquipment: Codable {
    private enum CodingValue: String, Codable {
        case none
        case dumbbells
        case gobletWeight = "goblet_weight"
    }

    init(from decoder: Decoder) throws {
        switch try CodingValue(from: decoder) {
        case .none: self = .none
        case .dumbbells: self = .dumbbells
        case .gobletWeight: self = .gobletWeight
        }
    }

    func encode(to encoder: Encoder) throws {
        let value: CodingValue
        switch self {
        case .none: value = .none
        case .dumbbells: value = .dumbbells
        case .gobletWeight: value = .gobletWeight
        }
        try value.encode(to: encoder)
    }
}
