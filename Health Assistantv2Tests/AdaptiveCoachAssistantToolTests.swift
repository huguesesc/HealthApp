import Foundation
import Testing
@testable import Health_Assistantv2

@MainActor
struct AdaptiveCoachAssistantToolTests {
    @Test func readOnlyCoachToolsAreRegistered() {
        let names = Set(ChatEngine.tools.map(\.name))

        #expect(names.contains("get_health_profile"))
        #expect(names.contains("get_workout_locations"))
        #expect(names.contains("get_exercise_candidates"))
        #expect(names.contains("propose_meal"))
        #expect(names.contains("propose_workout"))
        #expect(names.contains("get_recent_summaries"))
    }

    @Test func candidateToolRequiresAnExactLocationAndPromptRequiresFiltering() throws {
        let tool = try #require(
            ChatEngine.tools.first { $0.name == "get_exercise_candidates" }
        )
        let schema = try #require(
            try JSONSerialization.jsonObject(with: Data(tool.inputSchemaJSON.utf8))
                as? [String: Any]
        )

        #expect(schema["required"] as? [String] == ["location"])
        #expect(ChatEngine.systemPrompt.contains("call get_exercise_candidates"))
        #expect(ChatEngine.systemPrompt.contains("Use only the returned catalogue candidates"))
        #expect(ChatEngine.systemPrompt.contains("never invent a catalogue ID"))
    }

    @Test func workoutPlanProposalRequiresCandidatesForTheExactLocation() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        let repository = HealthDataRepository(context: context)
        repository.addLocation(WorkoutLocation(name: "Home", category: .home))
        let engine = ChatEngine(
            modelContext: context,
            exerciseCatalogRepository: CandidateCatalogStub(
                manifest: ExerciseCatalogManifest(
                    catalogSchemaVersion: 1,
                    exercises: [Self.bodyweightSquat]
                )
            )
        )
        let proposal = ChatToolCall(
            id: "proposal",
            name: "propose_workout_plan",
            inputJSON: """
            {
              "title": "Filtered home plan",
              "location": "Home",
              "steps": [{
                "type": "exercise",
                "exercise_id": "bodyweight.squat",
                "title": "Bodyweight squat",
                "instruction": "Squat with control.",
                "sets": 3,
                "reps": 8
              }]
            }
            """
        )

        let blocked = await engine.execute(proposal)
        #expect(blocked.contains("call get_exercise_candidates"))
        #expect(!engine.items.contains { if case .proposal = $0 { true } else { false } })

        let candidateResult = await engine.execute(
            ChatToolCall(
                id: "candidates",
                name: "get_exercise_candidates",
                inputJSON: """
                {"location": "Home", "goal": "Build strength", "duration_minutes": 20}
                """
            )
        )
        let payload = try JSONDecoder().decode(
            ExerciseCandidatePayload.self,
            from: Data(candidateResult.utf8)
        )
        #expect(payload.candidates.map(\.id) == ["bodyweight.squat"])

        let accepted = await engine.execute(proposal)
        #expect(accepted.contains("Drafted a structured workout plan"))
        #expect(engine.items.contains { if case .proposal = $0 { true } else { false } })

        let proposalCard = try #require(engine.items.compactMap { item -> ChatProposal? in
            if case .proposal(let proposal) = item { return proposal }
            return nil
        }.first)
        engine.confirm(proposalCard)
        let saved = try #require(repository.activeWorkoutPlans().first)
        #expect(saved.orderedSteps.first?.exerciseIDSnapshot == "bodyweight.squat")
        #expect(saved.orderedSteps.first?.title == "Bodyweight squat")
    }

    @Test func coachToolsHaveEmptyReadOnlyInputSchemas() throws {
        let profileTool = try #require(
            ChatEngine.tools.first { $0.name == "get_health_profile" }
        )
        let locationsTool = try #require(
            ChatEngine.tools.first { $0.name == "get_workout_locations" }
        )

        let profileSchema = try #require(
            try JSONSerialization.jsonObject(with: Data(profileTool.inputSchemaJSON.utf8))
                as? [String: Any]
        )
        let locationsSchema = try #require(
            try JSONSerialization.jsonObject(with: Data(locationsTool.inputSchemaJSON.utf8))
                as? [String: Any]
        )

        #expect(profileSchema["type"] as? String == "object")
        #expect(locationsSchema["type"] as? String == "object")
        #expect((profileSchema["properties"] as? [String: Any])?.isEmpty == true)
        #expect((locationsSchema["properties"] as? [String: Any])?.isEmpty == true)
    }

    @Test func systemPromptKeepsUserReportsSeparateFromDiagnosis() {
        #expect(ChatEngine.systemPrompt.contains("user's own reports"))
        #expect(ChatEngine.systemPrompt.contains("never diagnose"))
        #expect(ChatEngine.systemPrompt.contains("never infer a condition"))
    }

    private static let bodyweightSquat = ExerciseDefinition(
        id: ExerciseID(rawValue: "bodyweight.squat")!,
        schemaVersion: 1,
        displayName: "Bodyweight squat",
        category: ExerciseCategory(rawValue: "strength"),
        movementPattern: ExerciseMovementPattern(rawValue: "squat"),
        exerciseType: ExerciseType(rawValue: "repetition"),
        equipment: ExerciseEquipmentRequirements(required: [
            ExerciseEquipmentClause(id: ExerciseEquipmentID(rawValue: "none"), quantity: 1),
        ]),
        trackingMode: ExerciseTrackingMode(rawValue: "reps"),
        instructions: ["Squat with control."],
        lifecycle: ExerciseLifecycle(status: .active, replacementExerciseID: nil),
        media: nil,
        aliases: nil,
        legacyIDs: nil,
        guidance: nil,
        environmentRequirements: nil,
            legacyNames: nil
    )
}

private actor CandidateCatalogStub: ExerciseCatalogRepositoryProviding {
    let manifest: ExerciseCatalogManifest

    init(manifest: ExerciseCatalogManifest) {
        self.manifest = manifest
    }

    func loadState() async -> ExerciseCatalogLoadState {
        .available(manifest)
    }

    func resolve(reference: String) async -> ExerciseDefinition? {
        manifest.exercises.first { $0.id.rawValue == reference }
    }
}
