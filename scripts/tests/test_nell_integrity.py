import json
import tempfile
import unittest
from pathlib import Path

from scripts import nell_integrity


class NellIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "docs").mkdir()
        # Stub the runtime resources so resource-presence checks stay quiet
        # unless a test deliberately removes them.
        authoring = (
            self.root / "Health Assistantv2" / "ExerciseCatalog" / "Resources" / "Authoring"
        )
        authoring.mkdir(parents=True, exist_ok=True)
        for filename in nell_integrity.RUNTIME_RESOURCE_NAMES:
            (authoring / filename).write_text("{}", encoding="utf-8")

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, relative, text, encoding="utf-8"):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding=encoding)

    def test_clean_tree_reports_no_findings(self):
        self.write("Health Assistantv2/Exercise.swift", "struct Exercise {}\n")

        report = nell_integrity.run_integrity_checks(self.root)

        self.assertEqual(report.errors, [])

    def test_merge_markers_are_errors(self):
        self.write(
            "Health Assistantv2/Views/ConflictedView.swift",
            "struct ConflictedView {}\n<<<<<<< HEAD\nlet a = 1\n=======\nlet b = 2\n>>>>>>> other\n",
        )

        report = nell_integrity.run_integrity_checks(self.root)

        self.assertIn("MERGE_MARKER", {item.rule for item in report.errors})

    def test_dumbell_is_flagged_in_canonical_fields_only(self):
        self.write(
            "Health Assistantv2/ExerciseCatalog/Resources/Authoring/equipment.json",
            json.dumps({
                "schemaVersion": 1,
                "equipment": [
                    {
                        "id": "dumbell",
                        "displayName": "Dumbell",
                        "aliases": ["dumbell pair"],
                        "category": "free_weight",
                        "lifecycle": {"status": "active"},
                    }
                ],
            }),
        )
        self.write(
            "Health Assistantv2/ExerciseCatalog/Resources/Authoring/media-import-map.json",
            json.dumps({
                "schemaVersion": 1,
                "sourcePack": {"directoryName": "pack"},
                "images": [
                    {
                        "status": "unreviewed",
                        # Provenance MUST be allowed to preserve the misspelling.
                        "sourcePath": "workout_avatar/bench_dumbell_hip_thrust.png",
                        "canonicalExerciseID": "dumbbell.hip_thrust",
                    }
                ],
            }),
        )
        self.write(
            "Health Assistantv2/ExerciseCatalog/Resources/Authoring/catalog.json",
            json.dumps({
                "catalogSchemaVersion": 1,
                "exercises": [
                    {
                        "id": "dumbbell.curl",
                        "legacyNames": ["Dumbell curl"],
                        "aliases": [],
                    }
                ],
            }),
        )

        report = nell_integrity.run_integrity_checks(self.root)

        spelling_errors = [
            item for item in report.errors if item.rule == "CANONICAL_DUMBELL_SPELLING"
        ]
        pointers = {item.path for item in spelling_errors}
        authoring_posix = "Health Assistantv2/ExerciseCatalog/Resources/Authoring/equipment.json"
        self.assertEqual(
            pointers,
            {
                f"{authoring_posix}/equipment/0/id",
                f"{authoring_posix}/equipment/0/displayName",
                f"{authoring_posix}/equipment/0/aliases/0",
            },
        )
        provenance_paths = [item.path for item in report.findings if "media-import-map" in item.path]
        self.assertEqual(provenance_paths, [])

    def test_duplicate_type_declaration_across_files_is_an_error(self):
        self.write("Health Assistantv2/One/DuplicatedWidget.swift", "struct DuplicatedWidget {}\n")
        self.write("Health Assistantv2/Two/DuplicatedWidget.swift", "struct DuplicatedWidget {}\n")

        report = nell_integrity.run_integrity_checks(self.root)

        duplicates = [item for item in report.errors if item.rule == "DUPLICATE_TYPE_DECLARATION"]
        self.assertEqual(len(duplicates), 1)
        self.assertIn("DuplicatedWidget", duplicates[0].detail)

    def test_person_glyph_on_v2_screen_is_error_but_legacy_stack_is_exempt(self):
        self.write(
            "Health Assistantv2/Settings/NellProfileButton.swift",
            'Label("Profile", systemImage: "person.crop.circle")\n',
        )
        self.write(
            "Sources/Features/Settings/SettingsView.swift",
            'Label("Personalisation and profile", systemImage: "person.crop.circle")\n',
        )

        report = nell_integrity.run_integrity_checks(self.root)

        glyph_errors = [item for item in report.errors if item.rule == "PERSON_GLYPH_PROFILE_BUTTON"]
        self.assertEqual(len(glyph_errors), 1)
        self.assertIn("NellProfileButton", glyph_errors[0].path)


if __name__ == "__main__":
    unittest.main()
