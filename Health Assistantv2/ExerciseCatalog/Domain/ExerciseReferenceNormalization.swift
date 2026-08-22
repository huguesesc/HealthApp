import Foundation

/// The single canonical normalization for exercise display names, aliases,
/// hidden legacy names, and user-supplied references on the exact-resolution
/// path. Deliberately bounded: case and diacritic folding followed by removal
/// of separators and punctuation. No stemming, no edit-distance matching, no
/// substring behavior. Every consumer must resolve through this helper so a
/// change in normalization semantics happens in exactly one place.
enum ExerciseReferenceNormalization {
    static func normalized(_ value: String) -> String? {
        let locale = Locale(identifier: "en_US_POSIX")
        let folded = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .lowercased(with: locale)
        let normalized = folded.unicodeScalars.reduce(into: "") { result, scalar in
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
            }
        }
        return normalized.isEmpty ? nil : normalized
    }

    /// All resolvable name strings of one definition, in stable order.
    static func references(for definition: ExerciseDefinition) -> [String] {
        [definition.displayName] + (definition.aliases ?? []) + (definition.legacyNames ?? [])
    }
}
