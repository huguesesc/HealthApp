import Foundation
import Testing
@testable import Health_Assistantv2

/// Drives every historical/fixture exercise string recorded in
/// `legacy-name-compatibility.json` through the real production catalogue and
/// resolver. If normalization or catalogue data changes and a historical name
/// stops behaving as recorded, these tests fail immediately.
struct LegacyCompatibilityFixtureTests {
    private struct Fixture: Decodable {
        let schemaVersion: Int
        let entries: [Entry]

        struct Entry: Decodable {
            let raw: String
            let expectedResolution: String
            let expectedExerciseID: String?
        }
    }

    private static func loadFixture() throws -> Fixture {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring"
            )
        return try JSONDecoder().decode(
            Fixture.self,
            from: Data(contentsOf: base.appendingPathComponent("legacy-name-compatibility.json"))
        )
    }

    private static func loadResolver() throws -> LegacyExerciseResolver {
        let base = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json"
            )
        let manifest = try JSONDecoder().decode(
            ExerciseCatalogManifest.self,
            from: Data(contentsOf: base)
        )
        return LegacyExerciseResolver(definitions: manifest.exercises)
    }

    private let fixture: Fixture
    private let resolver: LegacyExerciseResolver

    init() throws {
        fixture = try Self.loadFixture()
        resolver = try Self.loadResolver()
    }

    private func resolvedID(_ raw: String) -> String? {
        if case .resolved(let definition, _) = resolver.resolve(raw) {
            return definition.id.rawValue
        }
        return nil
    }

    @Test func fixtureSchemaIsCurrent() {
        #expect(fixture.schemaVersion == 1)
    }

    @Test func canonicalExpectationsResolveToTheirRecordedExercise() {
        for entry in fixture.entries where entry.expectedResolution == "canonical" {
            #expect(
                resolvedID(entry.raw) == entry.expectedExerciseID,
                "'\(entry.raw)' must resolve to \(entry.expectedExerciseID ?? "nil")"
            )
        }
    }

    @Test func freeFormExpectationsStayUnresolved() {
        for entry in fixture.entries where entry.expectedResolution == "free-form" {
            #expect(
                resolvedID(entry.raw) == nil,
                "'\(entry.raw)' was expected to stay free-form but resolved to \(resolvedID(entry.raw) ?? "nil")"
            )
        }
    }

    @Test func noEntryIsLeftWithoutAnExplicitExpectation() {
        let supported = Set(["canonical", "free-form", "ambiguous", "deprecated"])
        for entry in fixture.entries {
            #expect(
                supported.contains(entry.expectedResolution),
                "unsupported expectedResolution '\(entry.expectedResolution)' for raw '\(entry.raw)'"
            )
        }
    }
}
