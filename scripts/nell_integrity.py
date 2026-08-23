"""Conservative static integrity checks for the Nell repository.

Companion to exercise_catalog.py. Runs fully on Windows and macOS with no
dependencies beyond the standard library. Deliberately conservative: every
rule below targets a defect class observed in this repository or an approved
product decision; speculative patterns are intentionally omitted so false
positives stay rare.

Usage:
    python scripts/nell_integrity.py            # human-readable report
    python scripts/nell_integrity.py --json     # machine-readable report

Exit code 0 = clean (warnings allowed), 1 = at least one error.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]

APP_SOURCES = Path("Health Assistantv2")
LEGACY_SOURCES = Path("Sources")
TEST_SOURCES = Path("Health Assistantv2Tests")

RUNTIME_RESOURCE_NAMES = (
    "catalog.json",
    "equipment.json",
    "environments.json",
)

GENERATED_INDEX_RELATIVE = APP_SOURCES / "ExerciseCatalog/Resources/Generated/media-index.json"
GENERATED_NAMESPACE_RELATIVE = APP_SOURCES / "Assets.xcassets/ExerciseMedia"

MERGE_MARKERS = ("<<<<<<<", ">>>>>>>", "=======")
JUNK_SUFFIXES = (".zip", ".DS_Store", ".xcuserstate", ".xcresult")
DUMBELL_TOKEN = "dumbell"
APPROVED_COACH_CONTEXTS = ("appStoreTitle",)


@dataclass
class Finding:
    severity: str  # ERROR or WARNING
    rule: str
    path: str
    detail: str

    def as_payload(self) -> dict[str, str]:
        return {
            "severity": self.severity,
            "rule": self.rule,
            "path": self.path,
            "detail": self.detail,
        }


@dataclass
class IntegrityReport:
    findings: list[Finding] = field(default_factory=list)

    def error(self, rule: str, path: str, detail: str) -> None:
        self.findings.append(Finding("ERROR", rule, path, detail))

    def warning(self, rule: str, path: str, detail: str) -> None:
        self.findings.append(Finding("WARNING", rule, path, detail))

    @property
    def errors(self) -> list[Finding]:
        return [item for item in self.findings if item.severity == "ERROR"]

    def as_payload(self) -> dict[str, object]:
        return {
            "ok": not self.errors,
            "errorCount": len(self.errors),
            "warningCount": len(self.findings) - len(self.errors),
            "findings": [item.as_payload() for item in self.findings],
        }


def _tracked_files(root: Path) -> list[Path] | None:
    try:
        completed = subprocess.run(
            ["git", "ls-files"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return [
        root / line
        for line in completed.stdout.splitlines()
        if line.strip()
    ]


def _read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8", errors="strict")
    except (OSError, UnicodeDecodeError):
        return None


def _swift_files(root: Path) -> list[Path]:
    directories = [root / APP_SOURCES, root / TEST_SOURCES, root / LEGACY_SOURCES]
    files: list[Path] = []
    for directory in directories:
        if directory.is_dir():
            files.extend(sorted(directory.rglob("*.swift")))
    return files


def check_merge_markers(root: Path, report: IntegrityReport) -> None:
    for path in _swift_files(root):
        text = _read_text(path)
        if text is None:
            continue
        for marker in MERGE_MARKERS:
            if any(line.startswith(marker) for line in text.splitlines()):
                report.error(
                    "MERGE_MARKER",
                    str(path.relative_to(root)),
                    f"unresolved conflict marker {marker!r}",
                )
                break


def check_junk_files(root: Path, report: IntegrityReport) -> None:
    files = _tracked_files(root)
    candidates = files if files is not None else [
        path for path in root.rglob("*") if path.is_file() and ".git" not in path.parts
    ]
    for path in candidates:
        name = path.name
        relative = str(path.relative_to(root))
        if name.startswith("._") or name == ".DS_Store":
            report.error("APPLEDOUBLE_TRACKED", relative, "macOS metadata file is tracked")
            continue
        if any(name.endswith(suffix) for suffix in JUNK_SUFFIXES):
            report.warning(
                "JUNK_FILE_PRESENT",
                relative,
                f"{name} should normally live outside version control",
            )


def check_duplicate_swift_types(root: Path, report: IntegrityReport) -> None:
    declarations: dict[str, list[str]] = {}
    import re

    pattern = re.compile(r"^(?:@\w+\s+)*(?:public |internal |private |fileprivate )*(?:final )?(?:struct|class|enum|actor)\s+(\w+)", re.MULTILINE)
    for path in _swift_files(root):
        text = _read_text(path)
        if text is None:
            continue
        relative = str(path.relative_to(root))
        for match in pattern.finditer(text):
            declarations.setdefault(match.group(1), []).append(relative)

    for name, locations in sorted(declarations.items()):
        unique_files = sorted(set(locations))
        if len(unique_files) > 1:
            extensions_are_legal = False  # type/actor redefinition is never legal
            if not extensions_are_legal:
                report.error(
                    "DUPLICATE_TYPE_DECLARATION",
                    unique_files[0],
                    f"type {name!r} declared in {len(unique_files)} files: "
                    + ", ".join(unique_files),
                )


def check_dumbell_canonical_spelling(root: Path, report: IntegrityReport) -> None:
    authoring = root / APP_SOURCES / "ExerciseCatalog/Resources/Authoring"
    for filename in (*RUNTIME_RESOURCE_NAMES, "media-import-map.json"):
        path = authoring / filename
        text = _read_text(path)
        if text is None:
            continue
        try:
            payload = json.loads(text)
        except ValueError:
            continue  # catalogue validator owns malformed-JSON diagnostics

        def scan(value: object, pointer: str) -> None:
            base = path.relative_to(root).as_posix()
            if isinstance(value, dict):
                for key, item in value.items():
                    inside_hidden_names = key == "legacyNames"
                    records_original_provenance = key == "sourcePath"
                    if isinstance(item, str) and not records_original_provenance:
                        if DUMBELL_TOKEN in item.lower():
                            report.error(
                                "CANONICAL_DUMBELL_SPELLING",
                                f"{base}{pointer}/{key}",
                                item,
                            )
                    elif isinstance(item, list) and not inside_hidden_names:
                        for index, element in enumerate(item):
                            if isinstance(element, str):
                                if DUMBELL_TOKEN in element.lower():
                                    report.error(
                                        "CANONICAL_DUMBELL_SPELLING",
                                        f"{base}{pointer}/{key}/{index}",
                                        element,
                                    )
                            else:
                                scan(element, f"{pointer}/{key}/{index}")
                    elif isinstance(item, dict) and not records_original_provenance:
                        scan(item, f"{pointer}/{key}")

        scan(payload, "")


def check_media_string_references_exist_in_index(root: Path, report: IntegrityReport) -> None:
    index_path = root / GENERATED_INDEX_RELATIVE
    try:
        index_payload = json.loads(index_path.read_text(encoding="utf-8"))
        indexed_keys = {
            entry.get("key")
            for entry in index_payload.get("media", [])
            if isinstance(entry, dict)
        }
    except (OSError, ValueError):
        return

    import re

    literal_pattern = re.compile(r'"([a-z0-9_.]+__[a-z0-9_]+)"')
    for path in _swift_files(root):
        text = _read_text(path)
        if text is None:
            continue
        for match in literal_pattern.finditer(text):
            candidate = match.group(1)
            if "__composite" in candidate or "__start" in candidate or "__end" in candidate:
                if candidate not in indexed_keys and "PreviewFixture" not in text:
                    report.error(
                        "HARDCODED_MEDIA_KEY_UNKNOWN",
                        str(path.relative_to(root)),
                        f"literal {candidate!r} is absent from media-index.json",
                    )


def check_runtime_resources_present(root: Path, report: IntegrityReport) -> None:
    authoring = root / APP_SOURCES / "ExerciseCatalog/Resources/Authoring"
    for filename in RUNTIME_RESOURCE_NAMES:
        if not (authoring / filename).is_file():
            report.error(
                "RUNTIME_RESOURCE_MISSING",
                str((authoring / filename).relative_to(root)),
                "bundled loader expects this resource",
            )
    if not (root / GENERATED_INDEX_RELATIVE).is_file():
        report.warning(
            "MEDIA_INDEX_MISSING",
            str(GENERATED_INDEX_RELATIVE),
            "generated media index absent; importer has not been applied",
        )


def check_approved_brand_decisions(root: Path, report: IntegrityReport) -> None:
    """Approved decisions: bottom destination is Nell; profile buttons use the
    Nell logo on v2 screens. Conservative: legacy Sources/ stack is exempt."""
    import re

    coach_literal = re.compile(r'Text\(\s*"Coach"\s*\)|case\s+\w+\s*=\s*"Coach"')
    person_glyph = re.compile(r"person\.crop\.circle")
    for path in sorted((root / APP_SOURCES).rglob("*.swift")):
        text = _read_text(path)
        if text is None:
            continue
        relative = str(path.relative_to(root))
        for match in coach_literal.finditer(text):
            context = text[max(0, match.start() - 120): match.end()]
            if any(token in context for token in APPROVED_COACH_CONTEXTS):
                continue
            report.error(
                "STALE_COACH_LABEL",
                relative,
                f"user-visible 'Coach' label near offset {match.start()}; "
                "approved product label is Nell",
            )
        if person_glyph.search(text):
            report.error(
                "PERSON_GLYPH_PROFILE_BUTTON",
                relative,
                "person.crop.circle used on an approved-Nell screen; "
                "profile buttons use the Nell logo",
            )


def check_documented_source_paths_exist(root: Path, report: IntegrityReport) -> None:
    """Only checks backticked repo-relative .swift/.py paths under
    docs/nell-redesign — the doc set this phase owns."""
    import re

    pattern = re.compile(r"`([\w\-./ ]+\.(?:swift|py|json))`")
    for document in sorted((root / "docs" / "nell-redesign").rglob("*.md")):
        text = _read_text(document)
        if text is None:
            continue
        for match in pattern.finditer(text):
            candidate = match.group(1).strip()
            if candidate.startswith(("Health Assistantv2", "Sources", "scripts/", "/")):
                normalized = candidate.lstrip("/")
                if not (root / normalized).is_file():
                    report.warning(
                        "DOC_REFERENCES_MISSING_PATH",
                        str(document.relative_to(root)),
                        f"documented path {candidate!r} does not exist",
                    )


def run_integrity_checks(root: Path | None = None) -> IntegrityReport:
    root = Path(root).resolve() if root else REPOSITORY_ROOT
    report = IntegrityReport()
    check_merge_markers(root, report)
    check_junk_files(root, report)
    check_duplicate_swift_types(root, report)
    check_dumbell_canonical_spelling(root, report)
    check_media_string_references_exist_in_index(root, report)
    check_runtime_resources_present(root, report)
    check_approved_brand_decisions(root, report)
    check_documented_source_paths_exist(root, report)
    report.findings.sort(key=lambda item: (item.severity, item.rule, item.path))
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=REPOSITORY_ROOT)
    parser.add_argument("--json", action="store_true")
    parsed = parser.parse_args(argv if argv is not None else sys.argv[1:])
    report = run_integrity_checks(parsed.root)
    if parsed.json:
        print(json.dumps(report.as_payload(), indent=2))
    else:
        print(
            f"nell-integrity: errors={len(report.errors)} "
            f"warnings={len(report.findings) - len(report.errors)}"
        )
        for finding in report.findings:
            print(f"{finding.severity} {finding.rule} {finding.path} | {finding.detail}")
    return 1 if report.errors else 0


if __name__ == "__main__":
    sys.exit(main())
