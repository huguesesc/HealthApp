import Foundation

enum ExerciseMediaRole: String, Codable, Hashable, Sendable {
    case thumbnail
    case setup
    case start
    case mid
    case end
    case alternate
    case mistake
    case correct
    // A composite is one complete semantic artifact; it is never an inferred endpoint.
    case composite
}

enum ExerciseMediaAppearance: String, Codable, Hashable, Sendable {
    case light
    case dark
}

struct ExerciseMediaDefinition: Codable, Hashable, Sendable {
    let key: String
    let role: ExerciseMediaRole
    let sequence: Int?
    let variant: String?
    let appearance: ExerciseMediaAppearance?
    let accessibilityDescription: String
}

enum ExerciseMediaSequenceNamespace: Hashable, Sendable {
    case primary
    case alternate(variant: String?)
}

enum ExerciseMediaValidationError: Error, Hashable, Sendable {
    case blankKey(key: String)
    case keyContainsLeadingOrTrailingWhitespace(key: String)
    case duplicateKey(key: String)
    case blankAccessibilityDescription(key: String)
    case missingPairedRole(role: ExerciseMediaRole)
    case missingEndpointSequence(role: ExerciseMediaRole)
    case invalidEndpointOrder(startSequence: Int, endSequence: Int)
    case nonPositiveSequence(key: String, sequence: Int)
    case duplicateSequence(namespace: ExerciseMediaSequenceNamespace, sequence: Int)
    case nonContiguousSequence(
        namespace: ExerciseMediaSequenceNamespace,
        expected: [Int],
        actual: [Int]
    )
}

extension Array where Element == ExerciseMediaDefinition {
    func validationErrors() -> [ExerciseMediaValidationError] {
        var errors: [ExerciseMediaValidationError] = []

        for item in self {
            let normalizedKey = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedKey.isEmpty {
                errors.append(.blankKey(key: item.key))
            }
            if normalizedKey != item.key {
                errors.append(.keyContainsLeadingOrTrailingWhitespace(key: item.key))
            }
            let trimmedDescription = item.accessibilityDescription.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmedDescription.isEmpty {
                errors.append(.blankAccessibilityDescription(key: normalizedKey))
            }
        }

        let mediaByNormalizedKey = Dictionary(grouping: self) {
            $0.key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for key in mediaByNormalizedKey.keys.sorted()
            where !key.isEmpty && (mediaByNormalizedKey[key]?.count ?? 0) > 1 {
            errors.append(.duplicateKey(key: key))
        }

        let containsStart = contains { $0.role == .start }
        let containsEnd = contains { $0.role == .end }
        if containsStart != containsEnd {
            errors.append(.missingPairedRole(role: containsStart ? .end : .start))
        }
        errors.append(contentsOf: endpointSequenceErrors())

        errors.append(contentsOf: sequenceValidationErrors())
        return errors
    }

    private func endpointSequenceErrors() -> [ExerciseMediaValidationError] {
        let starts = filter { $0.role == .start }
        let ends = filter { $0.role == .end }
        guard !starts.isEmpty, !ends.isEmpty else {
            return []
        }

        var errors: [ExerciseMediaValidationError] = []
        if starts.contains(where: { $0.sequence == nil }) {
            errors.append(.missingEndpointSequence(role: .start))
        }
        if ends.contains(where: { $0.sequence == nil }) {
            errors.append(.missingEndpointSequence(role: .end))
        }

        let startSequences = starts.compactMap(\.sequence)
        let endSequences = ends.compactMap(\.sequence)
        guard startSequences.count == starts.count,
              endSequences.count == ends.count,
              startSequences.allSatisfy({ $0 > 0 }),
              endSequences.allSatisfy({ $0 > 0 }),
              let latestStart = startSequences.max(),
              let earliestEnd = endSequences.min(),
              latestStart >= earliestEnd else {
            return errors
        }
        errors.append(
            .invalidEndpointOrder(startSequence: latestStart, endSequence: earliestEnd)
        )
        return errors
    }

    private func sequenceValidationErrors() -> [ExerciseMediaValidationError] {
        let sequencedItems = compactMap { item -> (ExerciseMediaDefinition, Int)? in
            guard let sequence = item.sequence else {
                return nil
            }
            return (item, sequence)
        }
        var errors: [ExerciseMediaValidationError] = []

        for (item, sequence) in sequencedItems where sequence <= 0 {
            errors.append(.nonPositiveSequence(key: item.key, sequence: sequence))
        }

        let sequencesByNamespace = Dictionary(grouping: sequencedItems) { entry in
            sequenceNamespace(for: entry.0)
        }
        for namespace in sequencesByNamespace.keys.sorted(by: namespaceOrder) {
            guard let namespaceItems = sequencesByNamespace[namespace] else {
                continue
            }
            let positiveSequences = namespaceItems.map(\.1).filter { $0 > 0 }
            let uniqueSequences = Set(positiveSequences).sorted()

            let duplicateSequences = uniqueSequences.filter { sequence in
                positiveSequences.filter { $0 == sequence }.count > 1
            }
            for sequence in duplicateSequences {
                errors.append(.duplicateSequence(namespace: namespace, sequence: sequence))
            }

            guard let lastSequence = uniqueSequences.last else {
                continue
            }
            let expected = Array<Int>(1...lastSequence)
            if uniqueSequences != expected {
                errors.append(
                    .nonContiguousSequence(
                        namespace: namespace,
                        expected: expected,
                        actual: uniqueSequences
                    )
                )
            }
        }
        return errors
    }

    private func sequenceNamespace(
        for item: ExerciseMediaDefinition
    ) -> ExerciseMediaSequenceNamespace {
        item.role == .alternate ? .alternate(variant: item.variant) : .primary
    }

    private func namespaceOrder(
        _ lhs: ExerciseMediaSequenceNamespace,
        _ rhs: ExerciseMediaSequenceNamespace
    ) -> Bool {
        namespaceSortKey(lhs) < namespaceSortKey(rhs)
    }

    private func namespaceSortKey(_ namespace: ExerciseMediaSequenceNamespace) -> String {
        switch namespace {
        case .primary:
            return "0"
        case .alternate(let variant):
            return "1:\(variant ?? "")"
        }
    }
}
