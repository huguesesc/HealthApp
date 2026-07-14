import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from scripts import exercise_catalog


class ExerciseCatalogValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.authoring = (
            self.root / "Health Assistantv2" / "ExerciseCatalog" / "Resources" / "Authoring"
        )
        self.source_pack = self.root / "source-pack"
        self.authoring.mkdir(parents=True)
        self.write_json("equipment.json", self.equipment_fixture())
        self.write_json("environments.json", self.environment_fixture())
        self.write_json("catalog.json", self.catalog_fixture())

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_valid_catalogue_passes_strict_validation(self):
        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])

    def test_malformed_exercise_id_reports_json_pointer_and_fix(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["id"] = "bodyweight-squat"
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        diagnostic = self.find_diagnostic(report, "E_EXERCISE_ID")
        self.assertEqual(diagnostic.pointer, "/exercises/0/id")
        self.assertIn("stable ID", diagnostic.fix)

    def test_alias_collision_is_rejected_after_normalization(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"].append(
            self.exercise_fixture(
                exercise_id="bodyweight.lunge",
                display_name="Air-Squat",
                aliases=["Lunge"],
            )
        )
        catalogue["exercises"][0]["aliases"] = ["Air squat"]
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        diagnostic = self.find_diagnostic(report, "E_ALIAS_COLLISION")
        self.assertIn("airsquat", diagnostic.value)

    def test_unknown_taxonomy_references_and_invalid_none_group_are_rejected(self):
        catalogue = self.catalog_fixture()
        exercise = catalogue["exercises"][0]
        exercise["equipment"] = {
            "required": [
                {"id": "none", "quantity": 1},
                {"id": "unknown_weight", "quantity": 1},
            ],
            "alternatives": [],
        }
        exercise["environmentRequirements"] = {"required": ["unknown_capability"]}
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_EQUIPMENT_UNKNOWN", self.error_codes(report))
        self.assertIn("E_EQUIPMENT_NONE_COMBINATION", self.error_codes(report))
        self.assertIn("E_CAPABILITY_UNKNOWN", self.error_codes(report))

    def test_equipment_parent_cycles_and_duplicate_fulfillments_are_rejected(self):
        equipment = self.equipment_fixture()
        equipment["equipment"][0]["parentID"] = "dumbbell"
        equipment["equipment"][1]["parentID"] = "none"
        equipment["equipment"][1]["fulfills"] = [
            {"id": "none", "quantityPerUnit": 1},
            {"id": "none", "quantityPerUnit": 1},
        ]
        self.write_json("equipment.json", equipment)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_EQUIPMENT_PARENT_CYCLE", self.error_codes(report))
        self.assertIn("E_EQUIPMENT_FULFILLMENT_DUPLICATE", self.error_codes(report))

    def test_replacement_cycles_and_disabled_targets_are_rejected(self):
        catalogue = self.catalog_fixture()
        first = catalogue["exercises"][0]
        first["lifecycle"] = {
            "status": "deprecated",
            "replacementExerciseID": "bodyweight.lunge",
        }
        second = self.exercise_fixture(
            exercise_id="bodyweight.lunge",
            display_name="Forward lunge",
        )
        second["lifecycle"] = {
            "status": "disabled",
            "replacementExerciseID": "bodyweight.squat",
        }
        catalogue["exercises"].append(second)
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_REPLACEMENT_CYCLE", self.error_codes(report))
        self.assertIn("E_REPLACEMENT_DISABLED", self.error_codes(report))

    def test_media_pairs_sequences_and_keys_are_validated(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [
            {
                "key": "bodyweight.squat__start",
                "role": "start",
                "sequence": 2,
                "accessibilityDescription": "Squat start",
            },
            {
                "key": "bodyweight.squat__start",
                "role": "end",
                "sequence": 1,
                "accessibilityDescription": "Squat end",
            },
        ]
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_MEDIA_KEY_DUPLICATE", self.error_codes(report))
        self.assertIn("E_MEDIA_ENDPOINT_ORDER", self.error_codes(report))

    def test_intake_asset_name_and_duplicate_content_are_rejected(self):
        intake = self.root / "exercise-assets-intake"
        intake.mkdir()
        first = intake / "bodyweight.squat__composite..png"
        second = intake / "bodyweight.lunge__composite.png"
        image = Image.new("RGBA", (16, 16), (20, 30, 40, 255))
        image.save(first)
        image.save(second)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_ASSET_NAME", self.error_codes(report))
        self.assertIn("E_ASSET_DUPLICATE_CONTENT", self.error_codes(report))

    def test_import_map_enforces_manifest_key_and_source_checksum(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [
            {
                "key": "bodyweight.squat__composite",
                "role": "composite",
                "accessibilityDescription": "Bodyweight squat composite",
            }
        ]
        self.write_json("catalog.json", catalogue)
        source = self.source_pack / "workout_avatar" / "bodyweight_squat.png"
        source.parent.mkdir(parents=True)
        Image.new("RGBA", (16, 16), (20, 30, 40, 255)).save(source)
        import_map = {
            "schemaVersion": 1,
            "sourcePack": {
                "mappedDirectory": "workout_avatar",
                "mappedImageCount": 1,
            },
            "images": [
                {
                    "status": "approved_for_import",
                    "sourcePath": "workout_avatar/bodyweight_squat.png",
                    "sourceSHA256": exercise_catalog.sha256(source),
                    "canonicalExerciseID": "bodyweight.squat",
                    "canonicalMediaKey": "bodyweight.squat__composite",
                    "canonicalFileName": "bodyweight.squat__composite.png",
                    "role": "composite",
                }
            ],
        }
        self.write_json("media-import-map.json", import_map)

        valid_report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertEqual(valid_report.errors, [])
        Image.new("RGBA", (16, 16), (40, 30, 20, 255)).save(
            source.parent / "unmapped.png"
        )
        import_map["images"][0]["canonicalMediaKey"] = "bodyweight.unknown__composite"
        import_map["images"][0]["canonicalFileName"] = 7
        import_map["images"][0]["sourceSHA256"] = "0" * 64
        self.write_json("media-import-map.json", import_map)

        invalid_report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertIn("E_IMPORT_MAP_KEY_UNKNOWN", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_FILENAME", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_SOURCE_CHECKSUM", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_SOURCE_UNMAPPED", self.error_codes(invalid_report))
        self.assertIn(
            "E_IMPORT_MAP_MANIFEST_MEDIA_UNMAPPED",
            self.error_codes(invalid_report),
        )

    def test_cli_returns_one_for_errors_and_zero_for_clean_catalogue(self):
        invalid_catalogue = self.catalog_fixture()
        invalid_catalogue["exercises"][0]["instructions"] = [" "]
        self.write_json("catalog.json", invalid_catalogue)

        with contextlib.redirect_stdout(io.StringIO()):
            invalid_exit = exercise_catalog.main(
                ["validate", "--strict", "--root", str(self.root)]
            )
        self.assertEqual(invalid_exit, 1)

        self.write_json("catalog.json", self.catalog_fixture())
        with contextlib.redirect_stdout(io.StringIO()):
            valid_exit = exercise_catalog.main(
                ["validate", "--strict", "--root", str(self.root)]
            )
        self.assertEqual(valid_exit, 0)

    def write_json(self, name, payload):
        path = self.authoring / name
        path.write_text(json.dumps(payload), encoding="utf-8")

    def find_diagnostic(self, report, code):
        for diagnostic in report.errors + report.warnings:
            if diagnostic.code == code:
                return diagnostic
        self.fail(f"Missing diagnostic {code}; got {[item.code for item in report.errors]}")

    def error_codes(self, report):
        return {diagnostic.code for diagnostic in report.errors}

    def catalog_fixture(self):
        return {
            "catalogSchemaVersion": 1,
            "exercises": [self.exercise_fixture("bodyweight.squat", "Bodyweight squat")],
        }

    def equipment_fixture(self):
        return {
            "schemaVersion": 1,
            "equipment": [
                {"id": "none", "lifecycle": {"status": "active"}},
                {"id": "dumbbell", "lifecycle": {"status": "active"}},
            ],
        }

    def environment_fixture(self):
        return {
            "schemaVersion": 1,
            "environments": [
                {
                    "id": "home",
                    "defaultCapabilities": ["floor_space", "jumping_allowed"],
                    "lifecycle": {"status": "active"},
                }
            ],
        }

    def exercise_fixture(self, exercise_id, display_name, aliases=None):
        return {
            "id": exercise_id,
            "schemaVersion": 1,
            "displayName": display_name,
            "category": "strength",
            "movementPattern": "squat",
            "exerciseType": "repetition",
            "equipment": {"required": [{"id": "none", "quantity": 1}], "alternatives": []},
            "trackingMode": "reps",
            "instructions": ["Begin in a stable position.", "Move with control and return."],
            "lifecycle": {"status": "active"},
            "aliases": aliases or [],
        }


if __name__ == "__main__":
    unittest.main()
