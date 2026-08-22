import contextlib
import io
import json
import shutil
import tempfile
import unittest
import warnings
from pathlib import Path
from unittest import mock

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

    def test_unreadable_intake_png_is_not_hashed(self):
        intake = self.root / "exercise-assets-intake"
        intake.mkdir()
        asset = intake / "bodyweight.squat__composite.png"
        asset.write_bytes(b"not a png")

        with mock.patch.object(
            exercise_catalog,
            "sha256",
            return_value="a" * 64,
        ) as checksum:
            report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_PNG_INVALID", self.error_codes(report))
        checksum.assert_not_called()

    def test_intake_checksum_read_failure_is_diagnostic_only(self):
        intake = self.root / "exercise-assets-intake"
        intake.mkdir()
        asset = intake / "bodyweight.squat__composite.png"
        Image.new("RGBA", (16, 16), (20, 30, 40, 255)).save(asset)

        with mock.patch.object(
            exercise_catalog,
            "sha256",
            side_effect=OSError("simulated intake checksum read failure"),
        ):
            try:
                report = exercise_catalog.validate_catalogue(self.root, strict=True)
            except OSError as error:
                self.fail(f"validator leaked intake checksum OSError: {error}")

        self.assertIn("E_ASSET_CHECKSUM_READ", self.error_codes(report))

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
                "directoryName": "source-pack",
                "mappedDirectory": "workout_avatar",
                "verifiedFileCount": 1,
                "mappedImageCount": 1,
                "verifiedZipSHA256": "a" * 64,
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
                    "approvalReference": "TEST-APPROVAL",
                }
            ],
        }
        self.write_json("media-import-map.json", import_map)

        valid_report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
            include_generated=False,
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
            include_generated=False,
        )

        self.assertIn("E_IMPORT_MAP_KEY_UNKNOWN", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_FILENAME", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_SOURCE_CHECKSUM", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_SOURCE_UNMAPPED", self.error_codes(invalid_report))
        self.assertIn("E_IMPORT_MAP_MANIFEST_MEDIA_UNMAPPED", self.error_codes(invalid_report))

    def test_appledouble_metadata_files_are_skipped_with_warning(self):
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
        apple_double = source.parent / "._bodyweight_squat.png"
        apple_double.write_bytes(b"\x00\x05\x16\x07\x00" + b"\x00" * 32)
        import_map = {
            "schemaVersion": 1,
            "sourcePack": {
                "directoryName": "source-pack",
                "mappedDirectory": "workout_avatar",
                "verifiedFileCount": 2,
                "mappedImageCount": 1,
                "verifiedZipSHA256": "a" * 64,
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
                    "approvalReference": "TEST-APPROVAL",
                }
            ],
        }
        self.write_json("media-import-map.json", import_map)

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
            include_generated=False,
        )

        self.assertEqual(report.errors, [])
        self.assertIn("W_SOURCE_APPLEDOUBLE_SKIPPED", self.warning_codes(report))
        warning = self.find_diagnostic(report, "W_SOURCE_APPLEDOUBLE_SKIPPED")
        self.assertIn("._bodyweight_squat.png", warning.value)
        self.assertIn("Delete the ._ file", warning.fix)

    def test_import_dry_run_lists_only_approved_rows_without_writing(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [
            {
                "key": "bodyweight.squat__composite",
                "role": "composite",
                "accessibilityDescription": "Bodyweight squat composite",
            }
        ]
        self.write_json("catalog.json", catalogue)
        source_directory = self.source_pack / "workout_avatar"
        source_directory.mkdir(parents=True)
        approved_source = source_directory / "bodyweight_squat.png"
        unreviewed_source = source_directory / "bodyweight_lunge.png"
        Image.new("RGBA", (16, 16), (20, 30, 40, 255)).save(approved_source)
        Image.new("RGBA", (16, 16), (40, 30, 20, 255)).save(unreviewed_source)
        self.write_json(
            "media-import-map.json",
            {
                "schemaVersion": 1,
                "sourcePack": {
                    "directoryName": "source-pack",
                    "mappedDirectory": "workout_avatar",
                    "verifiedFileCount": 2,
                    "mappedImageCount": 2,
                    "verifiedZipSHA256": "a" * 64,
                },
                "images": [
                    {
                        "status": "approved_for_import",
                        "sourcePath": "workout_avatar/bodyweight_squat.png",
                        "sourceSHA256": exercise_catalog.sha256(approved_source),
                        "canonicalExerciseID": "bodyweight.squat",
                        "canonicalMediaKey": "bodyweight.squat__composite",
                        "canonicalFileName": "bodyweight.squat__composite.png",
                        "role": "composite",
                        "approvalReference": "TEST-APPROVAL",
                    },
                    {
                        "status": "unreviewed",
                        "sourcePath": "workout_avatar/bodyweight_lunge.png",
                        "sourceSHA256": exercise_catalog.sha256(unreviewed_source),
                        "canonicalExerciseID": "bodyweight.lunge",
                        "canonicalMediaKey": "bodyweight.lunge__composite",
                        "canonicalFileName": "bodyweight.lunge__composite.png",
                        "role": "composite",
                    },
                ],
            },
        )

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = exercise_catalog.main([
                "import",
                "--dry-run",
                "--root",
                str(self.root),
                "--source-pack",
                str(self.source_pack),
            ])

        self.assertEqual(exit_code, 0)
        self.assertIn("approved=1", output.getvalue())
        self.assertIn("unreviewed=1", output.getvalue())
        self.assertIn("bodyweight.squat__composite.png", output.getvalue())
        self.assertIn("REJECT status=unreviewed", output.getvalue())
        self.assertIn("bodyweight.lunge__composite.png", output.getvalue())
        self.assertFalse(
            (self.root / "Health Assistantv2" / "Assets.xcassets" / "ExerciseMedia").exists()
        )

    def test_import_apply_generates_only_approved_imagesets_and_media_index(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [
            {
                "key": "bodyweight.squat__composite",
                "role": "composite",
                "accessibilityDescription": "Bodyweight squat composite",
            }
        ]
        self.write_json("catalog.json", catalogue)
        source_directory = self.source_pack / "workout_avatar"
        source_directory.mkdir(parents=True)
        approved_source = source_directory / "bodyweight_squat.png"
        unreviewed_source = source_directory / "bodyweight_lunge.png"
        Image.new("RGBA", (16, 16), (20, 30, 40, 255)).save(approved_source)
        Image.new("RGBA", (16, 16), (40, 30, 20, 255)).save(unreviewed_source)
        self.write_json(
            "media-import-map.json",
            {
                "schemaVersion": 1,
                "sourcePack": {
                    "directoryName": "source-pack",
                    "mappedDirectory": "workout_avatar",
                    "verifiedFileCount": 2,
                    "mappedImageCount": 2,
                    "verifiedZipSHA256": "a" * 64,
                },
                "images": [
                    {
                        "status": "approved_for_import",
                        "sourcePath": "workout_avatar/bodyweight_squat.png",
                        "sourceSHA256": exercise_catalog.sha256(approved_source),
                        "canonicalExerciseID": "bodyweight.squat",
                        "canonicalMediaKey": "bodyweight.squat__composite",
                        "canonicalFileName": "bodyweight.squat__composite.png",
                        "role": "composite",
                        "approvalReference": "TEST-APPROVAL",
                    },
                    {
                        "status": "unreviewed",
                        "sourcePath": "workout_avatar/bodyweight_lunge.png",
                        "sourceSHA256": exercise_catalog.sha256(unreviewed_source),
                        "canonicalExerciseID": "bodyweight.lunge",
                        "canonicalMediaKey": "bodyweight.lunge__composite",
                        "canonicalFileName": "bodyweight.lunge__composite.png",
                        "role": "composite",
                    },
                ],
            },
        )

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exit_code = exercise_catalog.main([
                "import",
                "--apply",
                "--root",
                str(self.root),
                "--source-pack",
                str(self.source_pack),
            ])

        image_set = (
            self.root
            / "Health Assistantv2"
            / "Assets.xcassets"
            / "ExerciseMedia"
            / "bodyweight.squat__composite.imageset"
        )
        index_path = (
            self.root
            / "Health Assistantv2"
            / "ExerciseCatalog"
            / "Resources"
            / "Generated"
            / "media-index.json"
        )
        self.assertEqual(exit_code, 0)
        self.assertIn("import applied", output.getvalue())
        self.assertEqual(
            (image_set / "bodyweight.squat__composite.png").read_bytes(),
            approved_source.read_bytes(),
        )
        self.assertFalse(
            (
                self.root
                / "Health Assistantv2"
                / "Assets.xcassets"
                / "ExerciseMedia"
                / "bodyweight.lunge__composite.imageset"
            ).exists()
        )
        index = json.loads(index_path.read_text(encoding="utf-8"))
        self.assertEqual(index["schemaVersion"], 1)
        self.assertEqual(index["media"][0]["key"], "bodyweight.squat__composite")
        post_apply_report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )
        self.assertEqual(post_apply_report.errors, [])

        first_index = index_path.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            second_exit_code = exercise_catalog.main([
                "import",
                "--apply",
                "--root",
                str(self.root),
                "--source-pack",
                str(self.source_pack),
            ])
        self.assertEqual(second_exit_code, 0)
        self.assertEqual(index_path.read_bytes(), first_index)

    def test_boolean_schema_versions_are_rejected(self):
        catalogue = self.catalog_fixture()
        catalogue["catalogSchemaVersion"] = True
        catalogue["exercises"][0]["schemaVersion"] = True
        equipment = self.equipment_fixture()
        equipment["schemaVersion"] = True
        environments = self.environment_fixture()
        environments["schemaVersion"] = True
        self.write_json("catalog.json", catalogue)
        self.write_json("equipment.json", equipment)
        self.write_json("environments.json", environments)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        schema_diagnostics = {
            (diagnostic.file, diagnostic.pointer, diagnostic.code)
            for diagnostic in report.errors
            if diagnostic.code in {"E_SCHEMA_VERSION", "E_EXERCISE_SCHEMA_VERSION"}
        }
        self.assertEqual(
            schema_diagnostics,
            {
                (
                    "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json",
                    "/catalogSchemaVersion",
                    "E_SCHEMA_VERSION",
                ),
                (
                    "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json",
                    "/exercises/0/schemaVersion",
                    "E_EXERCISE_SCHEMA_VERSION",
                ),
                (
                    "Health Assistantv2/ExerciseCatalog/Resources/Authoring/equipment.json",
                    "/schemaVersion",
                    "E_SCHEMA_VERSION",
                ),
                (
                    "Health Assistantv2/ExerciseCatalog/Resources/Authoring/environments.json",
                    "/schemaVersion",
                    "E_SCHEMA_VERSION",
                ),
            },
        )

    def test_required_taxonomy_fields_and_null_arrays_fail_without_crashing(self):
        equipment = self.equipment_fixture()
        entry = equipment["equipment"][0]
        del entry["displayName"]
        entry["category"] = 7
        entry["aliases"] = None
        entry["fulfills"] = None
        entry["lifecycle"] = None
        environments = self.environment_fixture()
        environment = environments["environments"][0]
        del environment["displayName"]
        environment["defaultCapabilities"] = None
        environment["rankingTags"] = None
        environment["lifecycle"] = None
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["aliases"] = None
        catalogue["exercises"][0]["legacyIDs"] = None
        self.write_json("equipment.json", equipment)
        self.write_json("environments.json", environments)
        self.write_json("catalog.json", catalogue)

        try:
            report = exercise_catalog.validate_catalogue(self.root, strict=True)
        except Exception as error:  # Regression guard: malformed JSON must be diagnostic-only.
            self.fail(f"validator crashed with {type(error).__name__}: {error}")

        self.assertTrue(
            {
                "E_EQUIPMENT_DISPLAY_NAME",
                "E_EQUIPMENT_CATEGORY",
                "E_EQUIPMENT_ALIAS_LIST",
                "E_EQUIPMENT_FULFILLMENT_LIST",
                "E_EQUIPMENT_LIFECYCLE",
                "E_ENVIRONMENT_DISPLAY_NAME",
                "E_CAPABILITY_LIST",
                "E_ENVIRONMENT_RANKING_TAG_LIST",
                "E_ENVIRONMENT_LIFECYCLE",
                "E_ALIAS_LIST",
                "E_LEGACY_ID_LIST",
            }.issubset(self.error_codes(report))
        )

    def test_authoring_files_require_top_level_objects(self):
        self.write_json("equipment.json", [])
        self.write_json("environments.json", "not an object")
        self.write_json("catalog.json", None)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertTrue(
            {
                "E_EQUIPMENT_OBJECT",
                "E_ENVIRONMENT_OBJECT",
                "E_CATALOG_OBJECT",
            }.issubset(self.error_codes(report))
        )

    def test_all_swift_required_taxonomy_fields_are_diagnosed(self):
        equipment = self.equipment_fixture()
        for field in ("id", "displayName", "category", "lifecycle"):
            del equipment["equipment"][0][field]
        environments = self.environment_fixture()
        for field in (
            "id",
            "displayName",
            "defaultCapabilities",
            "rankingTags",
            "lifecycle",
        ):
            del environments["environments"][0][field]
        self.write_json("equipment.json", equipment)
        self.write_json("environments.json", environments)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertTrue(
            {
                "E_EQUIPMENT_ID",
                "E_EQUIPMENT_DISPLAY_NAME",
                "E_EQUIPMENT_CATEGORY",
                "E_EQUIPMENT_LIFECYCLE",
                "E_ENVIRONMENT_ID",
                "E_ENVIRONMENT_DISPLAY_NAME",
                "E_CAPABILITY_LIST",
                "E_ENVIRONMENT_RANKING_TAG_LIST",
                "E_ENVIRONMENT_LIFECYCLE",
            }.issubset(self.error_codes(report))
        )

    def test_control_characters_in_source_paths_are_diagnostic_only(self):
        source, row = self.configure_approved_media()
        del source
        row["sourcePath"] = "workout_avatar/bad\x00.png"
        self.write_import_map([row])

        try:
            report = exercise_catalog.validate_catalogue(
                self.root,
                strict=True,
                source_pack=self.source_pack,
            )
        except Exception as error:  # Regression guard: paths must be diagnostic-only.
            self.fail(f"validator crashed with {type(error).__name__}: {error}")

        self.assertIn("E_IMPORT_SOURCE_PATH", self.error_codes(report))

    def test_invalid_utf8_is_reported_without_crashing(self):
        (self.authoring / "catalog.json").write_bytes(b"\xff")

        try:
            report = exercise_catalog.validate_catalogue(self.root, strict=True)
        except Exception as error:  # Regression guard: decoding must be diagnostic-only.
            self.fail(f"validator crashed with {type(error).__name__}: {error}")

        self.assertIn("E_JSON_ENCODING", self.error_codes(report))

    def test_decompression_bomb_is_reported_as_source_png_error(self):
        self.configure_approved_media()
        original_limit = Image.MAX_IMAGE_PIXELS
        try:
            Image.MAX_IMAGE_PIXELS = 1
            try:
                report = exercise_catalog.validate_catalogue(
                    self.root,
                    strict=True,
                    source_pack=self.source_pack,
                )
            except Exception as error:  # Regression guard: Pillow failures are diagnostics.
                self.fail(f"validator crashed with {type(error).__name__}: {error}")
        finally:
            Image.MAX_IMAGE_PIXELS = original_limit

        self.assertIn("E_IMPORT_SOURCE_PNG", self.error_codes(report))

    def test_decompression_bomb_warning_is_reported_as_source_png_error(self):
        self.configure_approved_media()
        original_limit = Image.MAX_IMAGE_PIXELS
        try:
            Image.MAX_IMAGE_PIXELS = 200
            with warnings.catch_warnings(record=True):
                warnings.simplefilter("always")
                report = exercise_catalog.validate_catalogue(
                    self.root,
                    strict=True,
                    source_pack=self.source_pack,
                )
        finally:
            Image.MAX_IMAGE_PIXELS = original_limit

        self.assertIn("E_IMPORT_SOURCE_PNG", self.error_codes(report))

    def test_source_checksum_read_failure_is_diagnostic_only(self):
        self.configure_approved_media()

        with mock.patch.object(
            exercise_catalog,
            "sha256",
            side_effect=OSError("simulated source checksum read failure"),
        ):
            try:
                report = exercise_catalog.validate_catalogue(
                    self.root,
                    strict=True,
                    source_pack=self.source_pack,
                    include_generated=False,
                )
            except OSError as error:
                self.fail(f"validator leaked source checksum OSError: {error}")

        self.assertIn("E_IMPORT_SOURCE_CHECKSUM_READ", self.error_codes(report))

    def test_generated_checksum_read_failure_is_diagnostic_only(self):
        source, row = self.configure_approved_media()
        del source
        with contextlib.redirect_stdout(io.StringIO()):
            apply_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)
        self.assertEqual(apply_exit, 0)
        report = exercise_catalog.ValidationReport()

        with mock.patch.object(
            exercise_catalog,
            "sha256",
            side_effect=OSError("simulated generated checksum read failure"),
        ):
            try:
                exercise_catalog.validate_generated_media(
                    self.root,
                    {row["canonicalMediaKey"]: row["role"]},
                    {row["canonicalMediaKey"]: row},
                    report,
                )
            except OSError as error:
                self.fail(f"validator leaked generated checksum OSError: {error}")

        self.assertIn("E_MEDIA_PNG_CHECKSUM_READ", self.error_codes(report))

    def test_unreadable_source_png_is_not_hashed(self):
        source, row = self.configure_approved_media()
        source.write_bytes(b"not a png")

        with mock.patch.object(
            exercise_catalog,
            "sha256",
            return_value=row["sourceSHA256"],
        ) as checksum:
            report = exercise_catalog.validate_catalogue(
                self.root,
                strict=True,
                source_pack=self.source_pack,
                include_generated=False,
            )

        self.assertIn("E_IMPORT_SOURCE_PNG", self.error_codes(report))
        checksum.assert_not_called()

    def test_unreadable_generated_png_is_not_hashed(self):
        source, row = self.configure_approved_media()
        del source
        with contextlib.redirect_stdout(io.StringIO()):
            apply_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)
        self.assertEqual(apply_exit, 0)
        png_path = (
            self.generated_namespace()
            / f"{row['canonicalMediaKey']}.imageset"
            / row["canonicalFileName"]
        )
        png_path.write_bytes(b"not a png")
        report = exercise_catalog.ValidationReport()

        with mock.patch.object(
            exercise_catalog,
            "sha256",
            return_value=row["sourceSHA256"],
        ) as checksum:
            exercise_catalog.validate_generated_media(
                self.root,
                {row["canonicalMediaKey"]: row["role"]},
                {row["canonicalMediaKey"]: row},
                report,
            )

        self.assertIn("E_MEDIA_PNG_INVALID", self.error_codes(report))
        checksum.assert_not_called()

    def test_manifest_media_key_suffix_must_match_role(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [
            self.media_fixture("bodyweight.squat", role="start")
        ]
        catalogue["exercises"][0]["media"][0]["role"] = "end"
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_MEDIA_KEY_ROLE_MISMATCH", self.error_codes(report))

    def test_import_map_media_key_suffix_must_match_role(self):
        source, row = self.configure_approved_media()
        del source
        row["role"] = "start"
        self.write_import_map([row])

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertIn("E_IMPORT_MEDIA_KEY_ROLE_MISMATCH", self.error_codes(report))

    def test_generated_index_media_key_suffix_must_match_role(self):
        source, row = self.configure_approved_media()
        del source
        with contextlib.redirect_stdout(io.StringIO()):
            apply_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)
        self.assertEqual(apply_exit, 0)
        index = json.loads(self.generated_index_path().read_text(encoding="utf-8"))
        index["media"][0]["role"] = "start"
        self.write_json_path(self.generated_index_path(), index)

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertIn("E_MEDIA_INDEX_KEY_ROLE_MISMATCH", self.error_codes(report))

    def test_strict_cli_requires_source_pack_for_approved_rows(self):
        self.configure_approved_media()
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            exit_code = exercise_catalog.main(
                ["validate", "--strict", "--root", str(self.root)]
            )

        self.assertEqual(exit_code, 1)
        self.assertIn("E_IMPORT_SOURCE_PACK_REQUIRED", output.getvalue())

    def test_strict_manifest_media_requires_approval_or_generated_resources(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [self.media_fixture("bodyweight.squat")]
        self.write_json("catalog.json", catalogue)
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            exit_code = exercise_catalog.main(
                ["validate", "--strict", "--root", str(self.root)]
            )

        self.assertEqual(exit_code, 1)
        self.assertIn("E_MEDIA_APPROVAL_RESOURCES_MISSING", output.getvalue())

    def test_non_object_import_map_reports_a_diagnostic(self):
        self.write_json("media-import-map.json", [])

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_IMPORT_MAP_OBJECT", self.error_codes(report))

    def test_import_map_metadata_and_approval_reference_are_validated(self):
        source, row = self.configure_approved_media()
        del source
        row["approvalReference"] = " "
        self.write_import_map(
            [row],
            {
                "directoryName": 7,
                "mappedDirectory": "workout_avatar",
                "verifiedFileCount": "1",
                "mappedImageCount": True,
                "verifiedZipSHA256": "not-a-checksum",
            },
        )

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertTrue(
            {
                "E_IMPORT_SOURCE_PACK_NAME",
                "E_IMPORT_SOURCE_FILE_COUNT",
                "E_IMPORT_SOURCE_COUNT_TYPE",
                "E_IMPORT_SOURCE_PACK_CHECKSUM",
                "E_IMPORT_APPROVAL_REFERENCE",
            }.issubset(self.error_codes(report))
        )

    def test_non_png_sources_are_rejected_before_dry_run_and_apply(self):
        catalogue = self.catalog_fixture()
        first = catalogue["exercises"][0]
        first["media"] = [self.media_fixture("bodyweight.squat")]
        second = self.exercise_fixture("bodyweight.lunge", "Forward lunge")
        second["media"] = [self.media_fixture("bodyweight.lunge")]
        catalogue["exercises"].append(second)
        self.write_json("catalog.json", catalogue)
        wrong_extension = self.source_pack / "workout_avatar" / "bodyweight_squat.jpg"
        wrong_extension.parent.mkdir(parents=True)
        Image.new("RGBA", (16, 16), (20, 30, 40, 255)).save(
            wrong_extension,
            format="PNG",
        )
        invalid_png = self.source_pack / "workout_avatar" / "bodyweight_lunge.png"
        invalid_png.write_bytes(b"not an image")
        rows = [
            self.approved_row(wrong_extension, "bodyweight.squat"),
            self.approved_row(invalid_png, "bodyweight.lunge"),
        ]
        self.write_import_map(rows)

        dry_output = io.StringIO()
        with contextlib.redirect_stdout(dry_output):
            dry_exit = exercise_catalog.main([
                "import",
                "--dry-run",
                "--root",
                str(self.root),
                "--source-pack",
                str(self.source_pack),
            ])
        apply_output = io.StringIO()
        with contextlib.redirect_stdout(apply_output):
            apply_exit = exercise_catalog.main([
                "import",
                "--apply",
                "--root",
                str(self.root),
                "--source-pack",
                str(self.source_pack),
            ])

        self.assertEqual(dry_exit, 1)
        self.assertEqual(apply_exit, 1)
        combined_output = dry_output.getvalue() + apply_output.getvalue()
        self.assertIn("E_IMPORT_SOURCE_EXTENSION", combined_output)
        self.assertIn("E_IMPORT_SOURCE_PNG", combined_output)

    def test_manifest_and_import_map_roles_must_match(self):
        source, row = self.configure_approved_media()
        del source
        row["role"] = "setup"
        self.write_import_map([row])

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertIn("E_IMPORT_ROLE_MANIFEST_MISMATCH", self.error_codes(report))

    def test_approved_map_requires_generated_index_and_namespace(self):
        self.configure_approved_media()

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertIn("E_MEDIA_INDEX_FILE_MISSING", self.error_codes(report))
        self.assertIn("E_MEDIA_NAMESPACE_MISSING", self.error_codes(report))

    def test_partial_generated_namespace_requires_media_index(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [self.media_fixture("bodyweight.squat")]
        self.write_json("catalog.json", catalogue)
        self.write_json_path(
            self.generated_namespace() / "Contents.json",
            {"info": {"author": "xcode", "version": 1}},
        )

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        self.assertIn("E_MEDIA_INDEX_FILE_MISSING", self.error_codes(report))

    def test_generated_index_and_imageset_structure_are_fail_closed(self):
        source, row = self.configure_approved_media()
        del source
        namespace = self.generated_namespace()
        image_set = namespace / f"{row['canonicalMediaKey']}.imageset"
        image_set.mkdir(parents=True)
        self.write_json_path(
            namespace / "Contents.json",
            {"info": {"author": "xcode", "version": 1}},
        )
        entry = self.generated_index_entry(row)
        duplicate = dict(entry)
        duplicate["role"] = "setup"
        duplicate["sourcePath"] = "workout_avatar/other.png"
        duplicate["sourceSHA256"] = "b" * 64
        self.write_json_path(
            self.generated_index_path(),
            {"schemaVersion": True, "media": [entry, duplicate]},
        )

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertTrue(
            {
                "E_SCHEMA_VERSION",
                "E_MEDIA_INDEX_KEY_DUPLICATE",
                "E_MEDIA_INDEX_ASSET_DUPLICATE",
                "E_MEDIA_INDEX_ROLE_MISMATCH",
                "E_MEDIA_INDEX_SOURCE_MISMATCH",
                "E_MEDIA_INDEX_CHECKSUM_MISMATCH",
                "E_MEDIA_CONTENTS_MISSING",
                "E_MEDIA_PNG_MISSING",
            }.issubset(self.error_codes(report))
        )

    def test_generated_png_checksum_must_match_approved_source(self):
        source, row = self.configure_approved_media()
        del source
        namespace = self.generated_namespace()
        image_set = namespace / f"{row['canonicalMediaKey']}.imageset"
        image_set.mkdir(parents=True)
        self.write_json_path(
            namespace / "Contents.json",
            {"info": {"author": "xcode", "version": 1}},
        )
        self.write_json_path(
            image_set / "Contents.json",
            {
                "images": [
                    {"filename": row["canonicalFileName"], "idiom": "universal"}
                ],
                "info": {"author": "xcode", "version": 1},
            },
        )
        Image.new("RGBA", (16, 16), (90, 80, 70, 255)).save(
            image_set / row["canonicalFileName"]
        )
        self.write_json_path(
            self.generated_index_path(),
            {"schemaVersion": 1, "media": [self.generated_index_entry(row)]},
        )

        report = exercise_catalog.validate_catalogue(
            self.root,
            strict=True,
            source_pack=self.source_pack,
        )

        self.assertIn("E_MEDIA_PNG_CHECKSUM", self.error_codes(report))

    def test_incremental_import_replaces_a_stale_prior_index(self):
        first_source, first_row = self.configure_approved_media()
        del first_source
        with contextlib.redirect_stdout(io.StringIO()):
            first_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)
        self.assertEqual(first_exit, 0)

        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [self.media_fixture("bodyweight.squat")]
        second = self.exercise_fixture("bodyweight.lunge", "Forward lunge")
        second["media"] = [self.media_fixture("bodyweight.lunge")]
        catalogue["exercises"].append(second)
        self.write_json("catalog.json", catalogue)
        second_source = self.create_source_png("bodyweight_lunge.png", (50, 60, 70, 255))
        second_row = self.approved_row(second_source, "bodyweight.lunge")
        self.write_import_map([first_row, second_row])

        with contextlib.redirect_stdout(io.StringIO()):
            second_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)

        self.assertEqual(second_exit, 0)
        index = json.loads(self.generated_index_path().read_text(encoding="utf-8"))
        self.assertEqual(
            [entry["key"] for entry in index["media"]],
            ["bodyweight.lunge__composite", "bodyweight.squat__composite"],
        )

    def test_apply_repairs_a_missing_imageset(self):
        source, row = self.configure_approved_media()
        del source
        with contextlib.redirect_stdout(io.StringIO()):
            first_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)
        self.assertEqual(first_exit, 0)
        image_set = self.generated_namespace() / f"{row['canonicalMediaKey']}.imageset"
        shutil.rmtree(image_set)

        with contextlib.redirect_stdout(io.StringIO()):
            repair_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)

        self.assertEqual(repair_exit, 0)
        self.assertTrue((image_set / row["canonicalFileName"]).is_file())

    def test_replacement_is_transactional_for_malformed_output_types(self):
        self.configure_approved_media()
        namespace = self.generated_namespace()
        index_path = self.generated_index_path()
        namespace.parent.mkdir(parents=True, exist_ok=True)
        namespace.write_bytes(b"stale asset namespace file")
        index_path.mkdir(parents=True)
        (index_path / "stale.txt").write_text("stale index directory", encoding="utf-8")

        with contextlib.redirect_stdout(io.StringIO()):
            apply_exit = exercise_catalog.run_import_apply(self.root, self.source_pack)

        self.assertEqual(apply_exit, 0)
        self.assertTrue(namespace.is_dir())
        self.assertTrue(index_path.is_file())
        self.assertEqual(list(namespace.parent.glob(".ExerciseMedia.backup-*")), [])
        self.assertEqual(list(index_path.parent.glob(".media-index.backup-*")), [])

        shutil.rmtree(namespace)
        index_path.unlink()
        namespace.write_bytes(b"original asset namespace file")
        index_path.mkdir()
        (index_path / "marker.txt").write_text("original index directory", encoding="utf-8")
        staging_root = self.root / "replacement-staging"
        staging_assets = staging_root / "ExerciseMedia"
        staging_assets.mkdir(parents=True)
        (staging_assets / "new.txt").write_text("new assets", encoding="utf-8")
        staging_index = staging_root / "media-index.json"
        staging_index.write_text("{}", encoding="utf-8")
        real_replace = exercise_catalog.os.replace
        replace_count = 0

        def fail_index_install(source_path, destination_path):
            nonlocal replace_count
            replace_count += 1
            if replace_count == 4:
                raise OSError("simulated index install failure")
            return real_replace(source_path, destination_path)

        with mock.patch.object(
            exercise_catalog.os,
            "replace",
            side_effect=fail_index_install,
        ):
            with self.assertRaisesRegex(OSError, "simulated index install failure"):
                exercise_catalog.replace_generated_import(
                    self.root,
                    staging_assets,
                    staging_index,
                )

        self.assertTrue(namespace.is_file())
        self.assertEqual(namespace.read_bytes(), b"original asset namespace file")
        self.assertTrue(index_path.is_dir())
        self.assertEqual(
            (index_path / "marker.txt").read_text(encoding="utf-8"),
            "original index directory",
        )
        self.assertEqual(list(namespace.parent.glob(".ExerciseMedia.backup-*")), [])
        self.assertEqual(list(index_path.parent.glob(".media-index.backup-*")), [])

    def test_checked_in_catalogue_remains_strict_green(self):
        root = exercise_catalog.repository_root()
        source_pack = root.parent / "HealthAssistant_image_Pack"
        if not source_pack.is_dir():
            # The reviewed pack intentionally lives outside the repository, so
            # hosts without it (for example CI) cannot run checksum-pinned
            # validation. Skipping here keeps "not run" honest instead of
            # failing on an environmental absence.
            self.skipTest(
                "source pack not present beside the repository; "
                "run this check on a host with the pack checkout"
            )

        report = exercise_catalog.validate_catalogue(
            root,
            strict=True,
            source_pack=source_pack,
        )

        self.assertEqual(report.errors, [])
        self.assertEqual(report.warnings, [])

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

    def write_json_path(self, path, payload):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(payload), encoding="utf-8")

    def media_fixture(self, exercise_id, role="composite"):
        return {
            "key": f"{exercise_id}__{role}",
            "role": role,
            "accessibilityDescription": f"{exercise_id} {role}",
        }

    def create_source_png(self, filename, color=(20, 30, 40, 255)):
        source = self.source_pack / "workout_avatar" / filename
        source.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (16, 16), color).save(source)
        return source

    def approved_row(self, source, exercise_id, role="composite"):
        media_key = f"{exercise_id}__{role}"
        return {
            "status": "approved_for_import",
            "sourcePath": source.relative_to(self.source_pack).as_posix(),
            "sourceSHA256": exercise_catalog.sha256(source),
            "canonicalExerciseID": exercise_id,
            "canonicalMediaKey": media_key,
            "canonicalFileName": f"{media_key}.png",
            "role": role,
            "approvalReference": "TEST-APPROVAL",
        }

    def write_import_map(self, rows, source_pack_metadata=None):
        metadata = source_pack_metadata or {
            "directoryName": "source-pack",
            "mappedDirectory": "workout_avatar",
            "verifiedFileCount": len(rows),
            "mappedImageCount": len(rows),
            "verifiedZipSHA256": "a" * 64,
        }
        self.write_json(
            "media-import-map.json",
            {"schemaVersion": 1, "sourcePack": metadata, "images": rows},
        )

    def configure_approved_media(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["media"] = [self.media_fixture("bodyweight.squat")]
        self.write_json("catalog.json", catalogue)
        source = self.create_source_png("bodyweight_squat.png")
        row = self.approved_row(source, "bodyweight.squat")
        self.write_import_map([row])
        return source, row

    def generated_namespace(self):
        return self.root / "Health Assistantv2" / "Assets.xcassets" / "ExerciseMedia"

    def generated_index_path(self):
        return (
            self.root
            / "Health Assistantv2"
            / "ExerciseCatalog"
            / "Resources"
            / "Generated"
            / "media-index.json"
        )

    def generated_index_entry(self, row):
        return {
            "assetName": row["canonicalMediaKey"],
            "filename": row["canonicalFileName"],
            "key": row["canonicalMediaKey"],
            "role": row["role"],
            "sourcePath": row["sourcePath"],
            "sourceSHA256": row["sourceSHA256"],
        }

    def find_diagnostic(self, report, code):
        for diagnostic in report.errors + report.warnings:
            if diagnostic.code == code:
                return diagnostic
        self.fail(f"Missing diagnostic {code}; got {[item.code for item in report.errors]}")

    def error_codes(self, report):
        return {diagnostic.code for diagnostic in report.errors}

    def warning_codes(self, report):
        return {diagnostic.code for diagnostic in report.warnings}

    def catalog_fixture(self):
        return {
            "catalogSchemaVersion": 1,
            "exercises": [self.exercise_fixture("bodyweight.squat", "Bodyweight squat")],
        }

    def equipment_fixture(self):
        return {
            "schemaVersion": 1,
            "equipment": [
                {
                    "id": "none",
                    "displayName": "No equipment",
                    "category": "none",
                    "lifecycle": {"status": "active"},
                },
                {
                    "id": "dumbbell",
                    "displayName": "Dumbbell",
                    "category": "free_weight",
                    "lifecycle": {"status": "active"},
                },
            ],
        }

    def environment_fixture(self):
        return {
            "schemaVersion": 1,
            "environments": [
                {
                    "id": "home",
                    "displayName": "Home",
                    "defaultCapabilities": ["floor_space", "jumping_allowed"],
                    "rankingTags": ["home"],
                    "lifecycle": {"status": "active"},
                }
            ],
        }

    def exercise_fixture(self, exercise_id, display_name, aliases=None, legacy_names=None):
        fixture = {
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
        if legacy_names is not None:
            fixture["legacyNames"] = legacy_names
        return fixture

    def test_inventory_reports_dispositions_without_writing(self):
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
        transparent_fixture = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for pixel_x in range(4):
            for pixel_y in range(4):
                transparent_fixture.putpixel((pixel_x, pixel_y), (20, 30, 40, 255))
        transparent_fixture.save(source)
        self.write_json(
            "media-import-map.json",
            {
                "schemaVersion": 1,
                "sourcePack": {
                    "directoryName": "source-pack",
                    "mappedDirectory": "workout_avatar",
                    "verifiedFileCount": 1,
                    "mappedImageCount": 1,
                    "verifiedZipSHA256": "a" * 64,
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
                        "approvalReference": "TEST-APPROVAL",
                    }
                ],
            },
        )

        inventory = exercise_catalog.build_inventory(self.root, self.source_pack)

        mapped_rows = [
            row for row in inventory["images"]
            if row["status"] != "outside_exercise_scope"
        ]
        self.assertEqual(len(mapped_rows), 1)
        row = mapped_rows[0]
        self.assertEqual(row["proposedExerciseID"], "bodyweight.squat")
        self.assertEqual(row["displayName"], "Bodyweight squat")
        self.assertTrue(row["referencedByCatalogue"])
        self.assertFalse(row["importedIntoApp"])
        self.assertFalse(row["generatedImagesetPresent"])
        self.assertTrue(row["pngMetadata"]["readable"])
        self.assertEqual((row["pngMetadata"]["width"], row["pngMetadata"]["height"]), (16, 16))
        self.assertTrue(row["pngMetadata"]["alphaActuallyUsed"])
        self.assertEqual(row["fileSizeBytes"], source.stat().st_size)
        self.assertEqual(row["checksumMatchesSource"], True)
        self.assertEqual(inventory["totals"]["unreviewed"], 0)

    def test_legacy_names_participate_in_alias_collision_detection(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"].append(
            self.exercise_fixture(
                exercise_id="bodyweight.lunge",
                display_name="Forward lunge",
            )
        )
        catalogue["exercises"][0]["legacyNames"] = ["Forward lunge"]
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)

        diagnostic = self.find_diagnostic(report, "E_ALIAS_COLLISION")
        self.assertIn("forwardlunge", diagnostic.value)

    def test_legacy_names_may_hold_dumbell_but_canonical_fields_cannot(self):
        catalogue = self.catalog_fixture()
        catalogue["exercises"][0]["displayName"] = "Dumbell squat"
        catalogue["exercises"][0]["aliases"] = ["Dumbell air squat"]
        catalogue["exercises"][0]["legacyNames"] = ["Dumbell squat (historical)"]
        catalogue["exercises"].append(
            self.exercise_fixture(
                exercise_id="dumbell.press",
                display_name="Clean press",
            )
        )
        self.write_json("catalog.json", catalogue)

        report = exercise_catalog.validate_catalogue(self.root, strict=True)
        codes = self.error_codes(report)

        self.assertIn("E_CANONICAL_DUMBELL", codes)
        dumbell_diagnostics = [
            item for item in report.errors if item.code == "E_CANONICAL_DUMBELL"
        ]
        pointers = {item.pointer for item in dumbell_diagnostics}
        self.assertEqual(
            pointers,
            {
                "/exercises/0/displayName",
                "/exercises/0/aliases/0",
                "/exercises/1/id",
            },
        )
        # The hidden legacy name itself must never be flagged.
        self.assertNotIn("/exercises/0/legacyNames/0", pointers)
        self.assertIn("dumbbell", dumbell_diagnostics[0].fix)


if __name__ == "__main__":
    unittest.main()
