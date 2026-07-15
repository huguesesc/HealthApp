import Foundation
import Testing
import UIKit
@testable import Health_Assistantv2

struct ExerciseCatalogBundleTests {
    @Test func productionCatalogueAndTaxonomiesLoadFromTheApplicationBundle() async throws {
        let bundle = Bundle.main
        let catalogURL = try requiredResourceURL(named: "catalog", in: bundle)
        let equipmentURL = try requiredResourceURL(named: "equipment", in: bundle)
        let environmentsURL = try requiredResourceURL(named: "environments", in: bundle)
        let mediaIndexURL = try requiredResourceURL(named: "media-index", in: bundle)

        let catalog = try decode(ExerciseCatalogManifest.self, at: catalogURL)
        let equipment = try decode(EquipmentTaxonomy.self, at: equipmentURL)
        let environments = try decode(ExerciseEnvironmentTaxonomy.self, at: environmentsURL)
        let mediaIndex = try decode(BundledMediaIndex.self, at: mediaIndexURL)

        #expect(catalog.exercises.count == 20)
        #expect(!equipment.equipment.isEmpty)
        #expect(!environments.environments.isEmpty)
        #expect(mediaIndex.schemaVersion == 1)
        #expect(mediaIndex.media.count == 20)

        let repository = BundledExerciseCatalogRepository()
        switch await repository.loadState() {
        case .available(let manifest):
            #expect(manifest.exercises.count == 20)
        case .unavailable(let error):
            Issue.record("Production catalogue unavailable: \(error)")
        }

        let squatMedia = try #require(mediaIndex.media.first {
            $0.key == "bodyweight.squat__composite"
        })
        #expect(
            UIImage(
                named: squatMedia.assetName,
                in: bundle,
                compatibleWith: nil
            ) != nil
        )
    }

    @Test func applicationBundleExcludesTheAuthoringOnlyMediaImportMap() throws {
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: Bundle.main.bundleURL,
                includingPropertiesForKeys: nil
            )
        )
        let matchingURLs = enumerator.compactMap { $0 as? URL }.filter {
            $0.lastPathComponent == "media-import-map.json"
        }

        #expect(matchingURLs.isEmpty)
    }

    @Test func missingAndMalformedBundledCataloguesAreSafelyUnavailable() async {
        let missingRepository = BundledExerciseCatalogRepository(
            resourceName: "missing-exercise-catalogue"
        )
        switch await missingRepository.loadState() {
        case .unavailable(.resourceNotFound(let name)):
            #expect(name == "catalog.json")
        default:
            Issue.record("A missing bundled catalogue did not report unavailable.")
        }

        let malformedRepository = BundledExerciseCatalogRepository(resourceName: "media-index")
        switch await malformedRepository.loadState() {
        case .unavailable(.decodingFailed):
            break
        default:
            Issue.record("A malformed bundled catalogue did not report unavailable.")
        }
    }

    private func requiredResourceURL(named name: String, in bundle: Bundle) throws -> URL {
        try #require(bundle.url(forResource: name, withExtension: "json"))
    }

    private func decode<Value: Decodable>(_ type: Value.Type, at url: URL) throws -> Value {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
}

private struct BundledMediaIndex: Decodable {
    let media: [BundledMediaIndexEntry]
    let schemaVersion: Int
}

private struct BundledMediaIndexEntry: Decodable {
    let assetName: String
    let key: String
}
