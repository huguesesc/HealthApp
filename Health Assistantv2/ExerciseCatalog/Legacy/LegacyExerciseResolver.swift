import Foundation
import OSLog

enum LegacyExerciseMatch: Hashable, Sendable {
    case stableID
    case legacyID
    case normalizedReference
}

enum LegacyExerciseResolution: Hashable, Sendable {
    case resolved(ExerciseDefinition, match: LegacyExerciseMatch)
    case ambiguous(reference: String, candidateIDs: [ExerciseID])
    case unresolved(reference: String)
}

enum LegacyExerciseDiagnostic: Hashable, Sendable {
    case ambiguous(reference: String, candidateIDs: [ExerciseID])
    case unresolved(reference: String)
}

struct LegacyExerciseResolver {
    private static let logger = Logger(
        subsystem: "Health_Assistantv2",
        category: "LegacyExerciseResolver"
    )

    private let stableIDClaims: [String: [ExerciseDefinition]]
    private let legacyIDClaims: [String: [ExerciseDefinition]]
    private let normalizedReferenceClaims: [String: [ExerciseDefinition]]
    private let diagnosticHandler: (LegacyExerciseDiagnostic) -> Void

    init(
        definitions: [ExerciseDefinition],
        diagnosticHandler: @escaping (LegacyExerciseDiagnostic) -> Void = Self.log
    ) {
        stableIDClaims = Dictionary(grouping: definitions) { $0.id.rawValue }

        var legacyClaims: [String: [ExerciseDefinition]] = [:]
        var referenceClaims: [String: [ExerciseID: ExerciseDefinition]] = [:]
        for definition in definitions {
            for legacyID in definition.legacyIDs ?? [] {
                legacyClaims[legacyID.rawValue, default: []].append(definition)
            }
            for reference in [definition.displayName] + (definition.aliases ?? []) {
                guard let normalized = Self.normalizedReference(reference) else {
                    continue
                }
                referenceClaims[normalized, default: [:]][definition.id] = definition
            }
        }
        legacyIDClaims = legacyClaims
        normalizedReferenceClaims = referenceClaims.mapValues { claimsByID in
            claimsByID.values.sorted { $0.id.rawValue < $1.id.rawValue }
        }
        self.diagnosticHandler = diagnosticHandler
    }

    func resolve(_ reference: String) -> LegacyExerciseResolution {
        if let claims = stableIDClaims[reference] {
            return resolution(
                for: reference,
                claims: claims,
                match: .stableID
            )
        }
        if let claims = legacyIDClaims[reference] {
            return resolution(
                for: reference,
                claims: claims,
                match: .legacyID
            )
        }
        if let normalized = Self.normalizedReference(reference),
           let claims = normalizedReferenceClaims[normalized] {
            return resolution(
                for: reference,
                claims: claims,
                match: .normalizedReference
            )
        }

        let diagnostic = LegacyExerciseDiagnostic.unresolved(reference: reference)
        diagnosticHandler(diagnostic)
        return .unresolved(reference: reference)
    }

    private func resolution(
        for reference: String,
        claims: [ExerciseDefinition],
        match: LegacyExerciseMatch
    ) -> LegacyExerciseResolution {
        let definitionsByID = Dictionary(
            claims.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let definitions = definitionsByID.values.sorted {
            $0.id.rawValue < $1.id.rawValue
        }
        if definitions.count == 1, let definition = definitions.first {
            return .resolved(definition, match: match)
        }

        let candidateIDs = definitions.map(\.id)
        let diagnostic = LegacyExerciseDiagnostic.ambiguous(
            reference: reference,
            candidateIDs: candidateIDs
        )
        diagnosticHandler(diagnostic)
        return .ambiguous(reference: reference, candidateIDs: candidateIDs)
    }

    private static func normalizedReference(_ reference: String) -> String? {
        let locale = Locale(identifier: "en_US_POSIX")
        let folded = reference
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .lowercased(with: locale)
        let normalized = folded.unicodeScalars.reduce(into: "") { result, scalar in
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
            }
        }
        return normalized.isEmpty ? nil : normalized
    }

    static func log(_ diagnostic: LegacyExerciseDiagnostic) {
        switch diagnostic {
        case .ambiguous(let reference, let candidateIDs):
            let candidates = candidateIDs.map(\.rawValue).joined(separator: ",")
            logger.warning(
                "Ambiguous legacy exercise reference: \(reference, privacy: .private(mask: .hash)); candidates: \(candidates, privacy: .public)"
            )
        case .unresolved(let reference):
            logger.notice(
                "Unresolved legacy exercise reference: \(reference, privacy: .private(mask: .hash))"
            )
        }
    }
}
