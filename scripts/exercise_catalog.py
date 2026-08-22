#!/usr/bin/env python3
"""Cross-platform validation for the checked-in exercise catalogue source."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import unicodedata
import uuid
import warnings
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, UnidentifiedImageError


CATALOG_SCHEMA_VERSION = 1
AUTHORING_DIRECTORY = Path("Health Assistantv2/ExerciseCatalog/Resources/Authoring")
GENERATED_DIRECTORY = Path("Health Assistantv2/ExerciseCatalog/Resources/Generated")
GENERATED_ASSET_DIRECTORY = Path("Health Assistantv2/Assets.xcassets/ExerciseMedia")
INTAKE_DIRECTORY = Path("exercise-assets-intake")
IMPORT_MAPPING_FILENAME = "media-import-map.json"
EXERCISE_ID_PATTERN = re.compile(
    r"^[a-z0-9]+(?:_[a-z0-9]+)*\.[a-z0-9]+(?:_[a-z0-9]+)*(?:\.[a-z0-9]+(?:_[a-z0-9]+)*)?$"
)
TOKEN_PATTERN = re.compile(r"^[a-z0-9]+(?:_[a-z0-9]+)*$")
MEDIA_KEY_PATTERN = re.compile(
    r"^[a-z0-9]+(?:_[a-z0-9]+)*\.[a-z0-9]+(?:_[a-z0-9]+)*"
    r"(?:\.[a-z0-9]+(?:_[a-z0-9]+)*)?(?:__[a-z0-9]+(?:_[a-z0-9]+)*)+$"
)
MEDIA_ROLES = {
    "thumbnail",
    "setup",
    "start",
    "mid",
    "end",
    "alternate",
    "mistake",
    "correct",
    "composite",
}
LIFECYCLE_STATUSES = {"active", "deprecated", "disabled"}
IMPORT_STATUSES = {
    "approved_for_import",
    "approved_pending_catalogue_entry",
    "unreviewed",
    "quarantined",
}
SHA256_PATTERN = re.compile(r"^[a-f0-9]{64}$")


class _JsonNullValue:
    def __repr__(self) -> str:
        return "null"


JSON_NULL = _JsonNullValue()


@dataclass(frozen=True)
class Diagnostic:
    severity: str
    code: str
    file: str
    pointer: str
    value: str
    rule: str
    fix: str

    def sort_key(self) -> tuple[str, str, str, str, str]:
        return (self.file, self.pointer, self.code, self.value, self.severity)

    def format(self) -> str:
        location = f"{self.file}{self.pointer}"
        return (
            f"{self.severity} {self.code} {location} | value={self.value!r} | "
            f"rule: {self.rule} | fix: {self.fix}"
        )


@dataclass
class ValidationReport:
    errors: list[Diagnostic] = field(default_factory=list)
    warnings: list[Diagnostic] = field(default_factory=list)
    exercise_count: int = 0
    intake_asset_count: int = 0

    def add_error(
        self,
        code: str,
        file: str,
        pointer: str,
        value: Any,
        rule: str,
        fix: str,
    ) -> None:
        self.errors.append(Diagnostic("ERROR", code, file, pointer, repr(value), rule, fix))

    def add_warning(
        self,
        code: str,
        file: str,
        pointer: str,
        value: Any,
        rule: str,
        fix: str,
    ) -> None:
        self.warnings.append(Diagnostic("WARNING", code, file, pointer, repr(value), rule, fix))

    def finalise(self) -> None:
        self.errors.sort(key=Diagnostic.sort_key)
        self.warnings.sort(key=Diagnostic.sort_key)


def repository_root() -> Path:
    return Path(__file__).resolve().parents[1]


def validate_catalogue(
    root: Path | str,
    strict: bool = False,
    source_pack: Path | str | None = None,
    include_generated: bool = True,
    require_source_pack: bool = False,
) -> ValidationReport:
    """Validate authoring JSON and any present intake/generated resources without writing."""
    root_path = Path(root).resolve()
    report = ValidationReport()
    authoring = root_path / AUTHORING_DIRECTORY
    catalog_path = authoring / "catalog.json"
    equipment_path = authoring / "equipment.json"
    environments_path = authoring / "environments.json"
    import_map_path = authoring / IMPORT_MAPPING_FILENAME

    catalog = load_json(catalog_path, root_path, report)
    equipment = load_json(equipment_path, root_path, report)
    environments = load_json(environments_path, root_path, report)

    equipment_ids = validate_equipment(equipment, equipment_path, root_path, report)
    capability_ids = validate_environments(environments, environments_path, root_path, report)
    media_roles = validate_catalog(
        catalog,
        catalog_path,
        root_path,
        equipment_ids,
        capability_ids,
        report,
    )
    approved_rows: dict[str, dict[str, Any]] = {}
    if import_map_path.is_file():
        approved_rows = validate_import_map(
            load_json(import_map_path, root_path, report),
            import_map_path,
            root_path,
            media_roles,
            Path(source_pack).resolve() if source_pack is not None else None,
            report,
        )
    if require_source_pack and source_pack is None and approved_rows:
        report.add_error(
            "E_IMPORT_SOURCE_PACK_REQUIRED",
            relative_path(root_path, import_map_path),
            "/images",
            len(approved_rows),
            "strict CLI validation must verify every approved source PNG and checksum",
            "Pass --source-pack with the reviewed source-pack directory.",
        )
    index_path = root_path / GENERATED_DIRECTORY / "media-index.json"
    namespace = root_path / GENERATED_ASSET_DIRECTORY
    if (
        strict
        and media_roles
        and not import_map_path.is_file()
        and not index_path.is_file()
        and not namespace.is_dir()
    ):
        report.add_error(
            "E_MEDIA_APPROVAL_RESOURCES_MISSING",
            relative_path(root_path, import_map_path),
            "",
            len(media_roles),
            "strict validation requires an approval map or generated resources for media",
            "Add the approved import map, or restore outputs generated from that map.",
        )
    if include_generated:
        validate_generated_media(root_path, media_roles, approved_rows, report)
    validate_intake_assets(root_path, set(media_roles), report)
    report.finalise()
    return report


def load_json(path: Path, root: Path, report: ValidationReport) -> Any | None:
    file = relative_path(root, path)
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        return JSON_NULL if value is None else value
    except FileNotFoundError:
        report.add_error(
            "E_FILE_MISSING",
            file,
            "",
            path.name,
            "required authoring file is missing",
            f"Add {path.name} under {AUTHORING_DIRECTORY.as_posix()}.",
        )
    except json.JSONDecodeError as error:
        report.add_error(
            "E_JSON_PARSE",
            file,
            json_pointer_from_line(path, error.lineno),
            error.msg,
            "file must contain valid JSON",
            "Correct the JSON syntax near the reported location.",
        )
    except UnicodeDecodeError:
        report.add_error(
            "E_JSON_ENCODING",
            file,
            "",
            "utf-8",
            "authoring JSON files must contain valid UTF-8 text",
            "Re-encode the file as UTF-8 and remove invalid byte sequences.",
        )
    return None


def validate_equipment(
    data: Any,
    path: Path,
    root: Path,
    report: ValidationReport,
) -> set[str]:
    file = relative_path(root, path)
    if not isinstance(data, dict):
        if data is not None:
            report.add_error(
                "E_EQUIPMENT_OBJECT",
                file,
                "",
                data,
                "equipment.json must contain a top-level object",
                "Replace the top-level value with the documented equipment object.",
            )
        return set()
    validate_schema_version(data.get("schemaVersion"), file, "/schemaVersion", report)
    entries = data.get("equipment")
    if not isinstance(entries, list):
        report.add_error(
            "E_EQUIPMENT_LIST",
            file,
            "/equipment",
            entries,
            "equipment must be an array",
            "Provide an array of equipment records.",
        )
        return set()

    ids: set[str] = set()
    duplicates: set[str] = set()
    definitions: dict[str, dict[str, Any]] = {}
    parent_edges: dict[str, str] = {}
    for index, entry in enumerate(entries):
        pointer = f"/equipment/{index}"
        if not isinstance(entry, dict):
            report.add_error(
                "E_EQUIPMENT_RECORD",
                file,
                pointer,
                entry,
                "equipment entries must be objects",
                "Replace the value with an equipment object.",
            )
            continue
        display_name = entry.get("displayName")
        if not isinstance(display_name, str) or not display_name.strip():
            report.add_error(
                "E_EQUIPMENT_DISPLAY_NAME",
                file,
                f"{pointer}/displayName",
                display_name,
                "equipment displayName must be a nonblank string",
                "Provide the user-facing equipment name required by the Swift schema.",
            )
        category = entry.get("category")
        if not is_token(category):
            report.add_error(
                "E_EQUIPMENT_CATEGORY",
                file,
                f"{pointer}/category",
                category,
                "equipment category must be a lowercase token",
                "Provide the equipment category required by the Swift schema.",
            )
        aliases = entry.get("aliases", [])
        if not isinstance(aliases, list):
            report.add_error(
                "E_EQUIPMENT_ALIAS_LIST",
                file,
                f"{pointer}/aliases",
                aliases,
                "equipment aliases must be an array when present",
                "Use an array of nonblank aliases or omit aliases.",
            )
        else:
            for alias_index, alias in enumerate(aliases):
                if not isinstance(alias, str) or not alias.strip():
                    report.add_error(
                        "E_EQUIPMENT_ALIAS",
                        file,
                        f"{pointer}/aliases/{alias_index}",
                        alias,
                        "equipment aliases must be nonblank strings",
                        "Remove the invalid alias or provide a nonblank string.",
                    )
        fulfillments = entry.get("fulfills", [])
        if not isinstance(fulfillments, list):
            report.add_error(
                "E_EQUIPMENT_FULFILLMENT_LIST",
                file,
                f"{pointer}/fulfills",
                fulfillments,
                "equipment fulfills must be an array when present",
                "Use an array of fulfillment objects or omit fulfills.",
            )
        lifecycle = entry.get("lifecycle")
        lifecycle_status = lifecycle.get("status") if isinstance(lifecycle, dict) else None
        if not isinstance(lifecycle_status, str) or lifecycle_status not in LIFECYCLE_STATUSES:
            status = lifecycle.get("status") if isinstance(lifecycle, dict) else lifecycle
            report.add_error(
                "E_EQUIPMENT_LIFECYCLE",
                file,
                f"{pointer}/lifecycle/status",
                status,
                "equipment lifecycle status must be active, deprecated, or disabled",
                "Provide the lifecycle object required by the Swift schema.",
            )
        equipment_id = entry.get("id")
        if not is_token(equipment_id):
            report.add_error(
                "E_EQUIPMENT_ID",
                file,
                f"{pointer}/id",
                equipment_id,
                "equipment IDs use lowercase ASCII tokens with underscores only",
                "Choose a lowercase token such as dumbbell or leg_press_machine.",
            )
            continue
        if equipment_id in ids:
            duplicates.add(equipment_id)
        ids.add(equipment_id)
        definitions.setdefault(equipment_id, entry)

    for equipment_id in sorted(duplicates):
        report.add_error(
            "E_EQUIPMENT_DUPLICATE",
            file,
            "/equipment",
            equipment_id,
            "equipment IDs must be unique",
            "Keep one canonical equipment record for this ID.",
        )

    for index, entry in enumerate(entries):
        if not isinstance(entry, dict) or not is_token(entry.get("id")):
            continue
        pointer = f"/equipment/{index}"
        equipment_id = entry["id"]
        parent_id = entry.get("parentID")
        if parent_id is not None and (
            not isinstance(parent_id, str) or parent_id not in ids
        ):
            report.add_error(
                "E_EQUIPMENT_PARENT_UNKNOWN",
                file,
                f"{pointer}/parentID",
                parent_id,
                "parentID must reference an existing equipment ID",
                "Add the parent definition first or correct the parentID.",
            )
        elif isinstance(parent_id, str):
            parent_edges[equipment_id] = parent_id
        fulfillment_targets: set[str] = set()
        fulfillments = entry.get("fulfills", [])
        if not isinstance(fulfillments, list):
            fulfillments = []
        for fulfillment_index, fulfillment in enumerate(fulfillments):
            fulfillment_pointer = f"{pointer}/fulfills/{fulfillment_index}"
            if not isinstance(fulfillment, dict):
                report.add_error(
                    "E_EQUIPMENT_FULFILLMENT",
                    file,
                    fulfillment_pointer,
                    fulfillment,
                    "fulfillment entries must be objects",
                    "Use an object with id and quantityPerUnit.",
                )
                continue
            target = fulfillment.get("id")
            quantity = fulfillment.get("quantityPerUnit")
            if isinstance(target, str) and target in fulfillment_targets:
                report.add_error(
                    "E_EQUIPMENT_FULFILLMENT_DUPLICATE",
                    file,
                    f"{fulfillment_pointer}/id",
                    target,
                    "one equipment record cannot fulfill the same target twice",
                    "Merge the duplicate fulfillment into one quantityPerUnit value.",
                )
            if isinstance(target, str):
                fulfillment_targets.add(target)
            if not isinstance(target, str) or target not in ids:
                report.add_error(
                    "E_EQUIPMENT_FULFILLMENT_UNKNOWN",
                    file,
                    f"{fulfillment_pointer}/id",
                    target,
                    "fulfillment targets must exist in equipment.json",
                    "Add the target equipment or correct the fulfillment ID.",
                )
            if not positive_integer(quantity):
                report.add_error(
                    "E_EQUIPMENT_FULFILLMENT_QUANTITY",
                    file,
                    f"{fulfillment_pointer}/quantityPerUnit",
                    quantity,
                    "quantityPerUnit must be a positive integer",
                    "Use a quantityPerUnit of at least 1.",
                )
    for cycle in find_cycles(parent_edges):
        report.add_error(
            "E_EQUIPMENT_PARENT_CYCLE",
            file,
            "/equipment",
            " -> ".join(cycle),
            "equipment parentID links cannot form a cycle",
            "Remove one parentID so the hierarchy terminates.",
        )
    return ids


def validate_environments(
    data: Any,
    path: Path,
    root: Path,
    report: ValidationReport,
) -> set[str]:
    file = relative_path(root, path)
    if not isinstance(data, dict):
        if data is not None:
            report.add_error(
                "E_ENVIRONMENT_OBJECT",
                file,
                "",
                data,
                "environments.json must contain a top-level object",
                "Replace the top-level value with the documented environments object.",
            )
        return set()
    validate_schema_version(data.get("schemaVersion"), file, "/schemaVersion", report)
    entries = data.get("environments")
    if not isinstance(entries, list):
        report.add_error(
            "E_ENVIRONMENT_LIST",
            file,
            "/environments",
            entries,
            "environments must be an array",
            "Provide an array of environment records.",
        )
        return set()

    environment_ids: set[str] = set()
    capabilities: set[str] = set()
    for index, entry in enumerate(entries):
        pointer = f"/environments/{index}"
        if not isinstance(entry, dict):
            report.add_error(
                "E_ENVIRONMENT_RECORD",
                file,
                pointer,
                entry,
                "environment entries must be objects",
                "Replace the value with an environment object.",
            )
            continue
        display_name = entry.get("displayName")
        if not isinstance(display_name, str) or not display_name.strip():
            report.add_error(
                "E_ENVIRONMENT_DISPLAY_NAME",
                file,
                f"{pointer}/displayName",
                display_name,
                "environment displayName must be a nonblank string",
                "Provide the user-facing environment name required by the Swift schema.",
            )
        ranking_tags = entry.get("rankingTags")
        if not isinstance(ranking_tags, list):
            report.add_error(
                "E_ENVIRONMENT_RANKING_TAG_LIST",
                file,
                f"{pointer}/rankingTags",
                ranking_tags,
                "environment rankingTags must be an array",
                "Provide the ranking-tag array required by the Swift schema.",
            )
        else:
            for tag_index, tag in enumerate(ranking_tags):
                if not is_token(tag):
                    report.add_error(
                        "E_ENVIRONMENT_RANKING_TAG",
                        file,
                        f"{pointer}/rankingTags/{tag_index}",
                        tag,
                        "environment ranking tags must be lowercase tokens",
                        "Use a lowercase ranking tag with optional underscores.",
                    )
        lifecycle = entry.get("lifecycle")
        lifecycle_status = lifecycle.get("status") if isinstance(lifecycle, dict) else None
        if not isinstance(lifecycle_status, str) or lifecycle_status not in LIFECYCLE_STATUSES:
            status = lifecycle.get("status") if isinstance(lifecycle, dict) else lifecycle
            report.add_error(
                "E_ENVIRONMENT_LIFECYCLE",
                file,
                f"{pointer}/lifecycle/status",
                status,
                "environment lifecycle status must be active, deprecated, or disabled",
                "Provide the lifecycle object required by the Swift schema.",
            )
        environment_id = entry.get("id")
        if not is_token(environment_id):
            report.add_error(
                "E_ENVIRONMENT_ID",
                file,
                f"{pointer}/id",
                environment_id,
                "environment IDs use lowercase ASCII tokens with underscores only",
                "Choose a unique lowercase environment token.",
            )
        elif environment_id in environment_ids:
            report.add_error(
                "E_ENVIRONMENT_DUPLICATE",
                file,
                f"{pointer}/id",
                environment_id,
                "environment IDs must be unique",
                "Keep one canonical environment record for this ID.",
            )
        else:
            environment_ids.add(environment_id)

        default_capabilities = entry.get("defaultCapabilities")
        if not isinstance(default_capabilities, list):
            report.add_error(
                "E_CAPABILITY_LIST",
                file,
                f"{pointer}/defaultCapabilities",
                default_capabilities,
                "defaultCapabilities must be an array",
                "Use an array of lowercase capability IDs.",
            )
            continue
        for capability_index, capability in enumerate(default_capabilities):
            capability_pointer = f"{pointer}/defaultCapabilities/{capability_index}"
            if not is_token(capability):
                report.add_error(
                    "E_CAPABILITY_ID",
                    file,
                    capability_pointer,
                    capability,
                    "capability IDs use lowercase ASCII tokens with underscores only",
                    "Use a lowercase capability token.",
                )
                continue
            capabilities.add(capability)
    return capabilities


def validate_catalog(
    data: Any,
    path: Path,
    root: Path,
    equipment_ids: set[str],
    capability_ids: set[str],
    report: ValidationReport,
) -> dict[str, str]:
    file = relative_path(root, path)
    if not isinstance(data, dict):
        if data is not None:
            report.add_error(
                "E_CATALOG_OBJECT",
                file,
                "",
                data,
                "catalog.json must contain a top-level object",
                "Replace the top-level value with the documented catalogue object.",
            )
        return {}
    validate_schema_version(
        data.get("catalogSchemaVersion"),
        file,
        "/catalogSchemaVersion",
        report,
        key_name="catalogSchemaVersion",
    )
    exercises = data.get("exercises")
    if not isinstance(exercises, list):
        report.add_error(
            "E_EXERCISE_LIST",
            file,
            "/exercises",
            exercises,
            "exercises must be an array",
            "Provide an array of exercise records.",
        )
        return {}

    report.exercise_count = len(exercises)
    exercise_ids: set[str] = set()
    exercise_by_id: dict[str, dict[str, Any]] = {}
    duplicate_ids: set[str] = set()
    for index, exercise in enumerate(exercises):
        pointer = f"/exercises/{index}"
        if not isinstance(exercise, dict):
            report.add_error(
                "E_EXERCISE_RECORD",
                file,
                pointer,
                exercise,
                "exercise entries must be objects",
                "Replace the value with an exercise object.",
            )
            continue
        exercise_id = exercise.get("id")
        if not is_exercise_id(exercise_id):
            report.add_error(
                "E_EXERCISE_ID",
                file,
                f"{pointer}/id",
                exercise_id,
                "exercise IDs must use the stable lowercase dot-ID format",
                "Choose a unique stable ID such as bodyweight.squat.",
            )
            continue
        flag_canonical_dumbell(exercise_id, file, f"{pointer}/id", "stable IDs", report)
        if exercise_id in exercise_ids:
            duplicate_ids.add(exercise_id)
        exercise_ids.add(exercise_id)
        exercise_by_id.setdefault(exercise_id, exercise)

    for exercise_id in sorted(duplicate_ids):
        report.add_error(
            "E_EXERCISE_DUPLICATE",
            file,
            "/exercises",
            exercise_id,
            "exercise IDs must be unique",
            "Keep one canonical exercise record for this ID.",
        )

    normalized_claims: dict[str, set[str]] = defaultdict(set)
    legacy_claims: dict[str, set[str]] = defaultdict(set)
    media_claims: dict[str, list[str]] = defaultdict(list)
    media_roles: dict[str, str] = {}
    replacement_edges: dict[str, str] = {}

    for index, exercise in enumerate(exercises):
        if not isinstance(exercise, dict):
            continue
        pointer = f"/exercises/{index}"
        exercise_id = exercise.get("id")
        if not is_exercise_id(exercise_id):
            continue
        validate_exercise_fields(exercise, file, pointer, report)
        validate_equipment_requirements(
            exercise.get("equipment"),
            file,
            f"{pointer}/equipment",
            equipment_ids,
            report,
        )
        validate_environment_requirements(
            exercise.get("environmentRequirements"),
            file,
            f"{pointer}/environmentRequirements",
            capability_ids,
            report,
        )
        if "media" in exercise:
            validate_media(
                exercise.get("media"),
                exercise_id,
                file,
                f"{pointer}/media",
                media_claims,
                media_roles,
                report,
            )

        aliases = exercise.get("aliases", [])
        if not isinstance(aliases, list):
            aliases = []
        legacy_names = exercise.get("legacyNames", [])
        if not isinstance(legacy_names, list):
            legacy_names = []
        for claim in [exercise.get("displayName")] + aliases + legacy_names:
            normalized = normalized_reference(claim)
            if normalized:
                normalized_claims[normalized].add(exercise_id)

        legacy_ids = exercise.get("legacyIDs", [])
        if not isinstance(legacy_ids, list):
            report.add_error(
                "E_LEGACY_ID_LIST",
                file,
                f"{pointer}/legacyIDs",
                legacy_ids,
                "legacyIDs must be an array when present",
                "Use an array of stable legacy IDs.",
            )
        else:
            for legacy_index, legacy_id in enumerate(legacy_ids):
                legacy_pointer = f"{pointer}/legacyIDs/{legacy_index}"
                if not is_exercise_id(legacy_id):
                    report.add_error(
                        "E_LEGACY_ID",
                        file,
                        legacy_pointer,
                        legacy_id,
                        "legacy IDs must use the stable lowercase dot-ID format",
                        "Correct the legacy ID or move a human title to aliases.",
                    )
                    continue
                legacy_claims[legacy_id].add(exercise_id)
                if legacy_id in exercise_ids:
                    report.add_error(
                        "E_LEGACY_ID_STABLE_COLLISION",
                        file,
                        legacy_pointer,
                        legacy_id,
                        "a legacy ID cannot reuse a current stable ID",
                        "Choose a distinct legacy ID or remove the redundant claim.",
                    )

        lifecycle = exercise.get("lifecycle")
        if isinstance(lifecycle, dict):
            replacement = lifecycle.get("replacementExerciseID")
            if is_exercise_id(replacement):
                replacement_edges[exercise_id] = replacement

    for normalized, owners in sorted(normalized_claims.items()):
        if len(owners) > 1:
            report.add_error(
                "E_ALIAS_COLLISION",
                file,
                "/exercises",
                f"{normalized}: {sorted(owners)}",
                "normalized display names, aliases, and legacy names must be unique",
                "Remove or distinguish the ambiguous name.",
            )
    for legacy_id, owners in sorted(legacy_claims.items()):
        if len(owners) > 1:
            report.add_error(
                "E_LEGACY_ID_DUPLICATE",
                file,
                "/exercises",
                f"{legacy_id}: {sorted(owners)}",
                "legacy IDs must resolve to one exercise",
                "Keep the legacy ID on only one record.",
            )
    for key, pointers in sorted(media_claims.items()):
        if len(pointers) > 1:
            report.add_error(
                "E_MEDIA_KEY_DUPLICATE",
                file,
                "/exercises",
                key,
                "media keys must be globally unique",
                "Use one logical key for one media resource.",
            )

    validate_replacements(replacement_edges, exercise_by_id, file, report)
    return media_roles


DUMBELL_MISSPELLING = "dumbell"


def flag_canonical_dumbell(
    value: Any,
    file: str,
    pointer: str,
    field_kind: str,
    report: ValidationReport,
) -> None:
    """Canonical catalogue text must spell 'dumbbell'; only hidden legacy
    names may deliberately preserve the historical 'dumbell' misspelling."""
    if isinstance(value, str) and DUMBELL_MISSPELLING in value.lower():
        report.add_error(
            "E_CANONICAL_DUMBELL",
            file,
            pointer,
            value,
            f"{field_kind} must use the canonical spelling 'dumbbell'",
            "Replace 'dumbell' with 'dumbbell'; keep the historical "
            "misspelling only in legacyNames.",
        )


def validate_exercise_fields(
    exercise: dict[str, Any],
    file: str,
    pointer: str,
    report: ValidationReport,
) -> None:
    schema_version = exercise.get("schemaVersion")
    if (
        not isinstance(schema_version, int)
        or isinstance(schema_version, bool)
        or schema_version != CATALOG_SCHEMA_VERSION
    ):
        report.add_error(
            "E_EXERCISE_SCHEMA_VERSION",
            file,
            f"{pointer}/schemaVersion",
            schema_version,
            "exercise schemaVersion must be 1",
            "Use schemaVersion 1 until a documented migration is added.",
        )
    for key in ("displayName", "category", "movementPattern", "exerciseType", "trackingMode"):
        value = exercise.get(key)
        if not isinstance(value, str) or not value.strip():
            report.add_error(
                "E_EXERCISE_REQUIRED_FIELD",
                file,
                f"{pointer}/{key}",
                value,
                f"{key} must be a nonblank string",
                f"Provide a nonblank {key} value.",
            )

    instructions = exercise.get("instructions")
    if not isinstance(instructions, list) or not instructions:
        report.add_error(
            "E_INSTRUCTIONS_EMPTY",
            file,
            f"{pointer}/instructions",
            instructions,
            "instructions must contain written guidance",
            "Add at least one nonblank written instruction; media is not a substitute.",
        )
    else:
        for instruction_index, instruction in enumerate(instructions):
            if not isinstance(instruction, str) or not instruction.strip():
                report.add_error(
                    "E_INSTRUCTION_BLANK",
                    file,
                    f"{pointer}/instructions/{instruction_index}",
                    instruction,
                    "instructions must be nonblank strings",
                    "Replace the blank instruction with written guidance.",
                )

    aliases = exercise.get("aliases", [])
    if not isinstance(aliases, list):
        report.add_error(
            "E_ALIAS_LIST",
            file,
            f"{pointer}/aliases",
            aliases,
            "aliases must be an array when present",
            "Use an array of human-readable aliases.",
        )
    else:
        for alias_index, alias in enumerate(aliases):
            if not isinstance(alias, str) or not alias.strip():
                report.add_error(
                    "E_ALIAS_BLANK",
                    file,
                    f"{pointer}/aliases/{alias_index}",
                    alias,
                    "aliases must be nonblank strings",
                    "Remove the blank alias or provide a distinct name.",
                )

    flag_canonical_dumbell(
        exercise.get("displayName"),
        file,
        f"{pointer}/displayName",
        "display names",
        report,
    )
    if isinstance(aliases, list):
        for alias_index, alias in enumerate(aliases):
            flag_canonical_dumbell(
                alias,
                file,
                f"{pointer}/aliases/{alias_index}",
                "aliases",
                report,
            )

    legacy_names = exercise.get("legacyNames")
    if legacy_names is not None:
        if not isinstance(legacy_names, list):
            report.add_error(
                "E_LEGACY_NAME_LIST",
                file,
                f"{pointer}/legacyNames",
                legacy_names,
                "legacyNames must be an array when present",
                "Use an array of historical misspelled or retired human titles.",
            )
        else:
            for name_index, name in enumerate(legacy_names):
                if not isinstance(name, str) or not name.strip():
                    report.add_error(
                        "E_LEGACY_NAME_BLANK",
                        file,
                        f"{pointer}/legacyNames/{name_index}",
                        name,
                        "legacyNames must be nonblank strings",
                        "Remove the blank entry or provide the historical title.",
                    )

    if "guidance" in exercise:
        guidance = exercise.get("guidance")
        if not isinstance(guidance, list):
            report.add_error(
                "E_GUIDANCE_LIST",
                file,
                f"{pointer}/guidance",
                guidance,
                "guidance must be an array when present",
                "Use an array of nonblank guidance strings or omit guidance.",
            )
        else:
            for guidance_index, item in enumerate(guidance):
                if not isinstance(item, str) or not item.strip():
                    report.add_error(
                        "E_GUIDANCE_BLANK",
                        file,
                        f"{pointer}/guidance/{guidance_index}",
                        item,
                        "guidance entries must be nonblank strings",
                        "Remove the invalid guidance entry or provide written guidance.",
                    )

    lifecycle = exercise.get("lifecycle")
    lifecycle_status = lifecycle.get("status") if isinstance(lifecycle, dict) else None
    if not isinstance(lifecycle_status, str) or lifecycle_status not in LIFECYCLE_STATUSES:
        status = lifecycle.get("status") if isinstance(lifecycle, dict) else lifecycle
        report.add_error(
            "E_LIFECYCLE_STATUS",
            file,
            f"{pointer}/lifecycle/status",
            status,
            "lifecycle status must be active, deprecated, or disabled",
            "Choose one controlled lifecycle status.",
        )
    if isinstance(lifecycle, dict):
        replacement = lifecycle.get("replacementExerciseID")
        if replacement is not None and not is_exercise_id(replacement):
            report.add_error(
                "E_REPLACEMENT_ID",
                file,
                f"{pointer}/lifecycle/replacementExerciseID",
                replacement,
                "replacementExerciseID must use the stable lowercase dot-ID format",
                "Correct the replacement ID or remove the replacement link.",
            )


def validate_equipment_requirements(
    requirements: Any,
    file: str,
    pointer: str,
    equipment_ids: set[str],
    report: ValidationReport,
) -> None:
    if not isinstance(requirements, dict):
        report.add_error(
            "E_EQUIPMENT_REQUIREMENTS",
            file,
            pointer,
            requirements,
            "equipment must be an object with required and alternatives",
            "Provide equipment requirement groups.",
        )
        return
    required = requirements.get("required")
    alternatives = requirements.get("alternatives", [])
    validate_equipment_group(required, file, f"{pointer}/required", equipment_ids, report)
    if not isinstance(alternatives, list):
        report.add_error(
            "E_EQUIPMENT_ALTERNATIVES",
            file,
            f"{pointer}/alternatives",
            alternatives,
            "alternatives must be an array of AND groups",
            "Use [] or nested equipment clause arrays.",
        )
        return
    for index, group in enumerate(alternatives):
        validate_equipment_group(
            group,
            file,
            f"{pointer}/alternatives/{index}",
            equipment_ids,
            report,
        )


def validate_equipment_group(
    group: Any,
    file: str,
    pointer: str,
    equipment_ids: set[str],
    report: ValidationReport,
) -> None:
    if not isinstance(group, list) or not group:
        report.add_error(
            "E_EQUIPMENT_GROUP_EMPTY",
            file,
            pointer,
            group,
            "each equipment AND group must contain at least one clause",
            "Add a valid equipment clause or remove the alternative group.",
        )
        return
    ids: list[str] = []
    for index, clause in enumerate(group):
        clause_pointer = f"{pointer}/{index}"
        if not isinstance(clause, dict):
            report.add_error(
                "E_EQUIPMENT_CLAUSE",
                file,
                clause_pointer,
                clause,
                "equipment clauses must be objects",
                "Use an object with id and quantity.",
            )
            continue
        equipment_id = clause.get("id")
        quantity = clause.get("quantity")
        if not isinstance(equipment_id, str) or equipment_id not in equipment_ids:
            report.add_error(
                "E_EQUIPMENT_UNKNOWN",
                file,
                f"{clause_pointer}/id",
                equipment_id,
                "equipment IDs must exist in equipment.json",
                "Add an approved equipment definition first or correct the ID.",
            )
        if not positive_integer(quantity):
            report.add_error(
                "E_EQUIPMENT_QUANTITY",
                file,
                f"{clause_pointer}/quantity",
                quantity,
                "equipment quantities must be positive integers",
                "Use a quantity of at least 1.",
            )
        if isinstance(equipment_id, str):
            ids.append(equipment_id)
    if "none" in ids and len(ids) > 1:
        report.add_error(
            "E_EQUIPMENT_NONE_COMBINATION",
            file,
            pointer,
            ids,
            "none must be the sole equipment clause in its group",
            "Remove none or make it the only required clause.",
        )
    for duplicate in sorted({item for item in ids if ids.count(item) > 1}):
        report.add_error(
            "E_EQUIPMENT_CLAUSE_DUPLICATE",
            file,
            pointer,
            duplicate,
            "an equipment group cannot repeat one equipment ID",
            "Merge the quantities into one clause.",
        )


def validate_environment_requirements(
    requirements: Any,
    file: str,
    pointer: str,
    capability_ids: set[str],
    report: ValidationReport,
) -> None:
    if requirements is None:
        return
    if not isinstance(requirements, dict):
        report.add_error(
            "E_ENVIRONMENT_REQUIREMENTS",
            file,
            pointer,
            requirements,
            "environmentRequirements must be an object",
            "Use required and optional prohibited capability arrays.",
        )
        return
    required = requirements.get("required")
    prohibited = requirements.get("prohibited", [])
    if not isinstance(required, list):
        report.add_error(
            "E_CAPABILITY_REQUIRED_LIST",
            file,
            f"{pointer}/required",
            required,
            "required capabilities must be an array",
            "Use an array of known capability IDs.",
        )
        required = []
    if not isinstance(prohibited, list):
        report.add_error(
            "E_CAPABILITY_PROHIBITED_LIST",
            file,
            f"{pointer}/prohibited",
            prohibited,
            "prohibited capabilities must be an array",
            "Use an array of known capability IDs.",
        )
        prohibited = []
    valid_capabilities: dict[str, set[str]] = {"required": set(), "prohibited": set()}
    for key, values in (("required", required), ("prohibited", prohibited)):
        for index, capability in enumerate(values):
            if not is_token(capability) or capability not in capability_ids:
                report.add_error(
                    "E_CAPABILITY_UNKNOWN",
                    file,
                    f"{pointer}/{key}/{index}",
                    capability,
                    "capability IDs must exist in environments.json",
                    "Add the capability to an approved environment or correct the ID.",
                )
                continue
            valid_capabilities[key].add(capability)
    contradictions = valid_capabilities["required"].intersection(
        valid_capabilities["prohibited"]
    )
    for capability in sorted(contradictions):
        report.add_error(
            "E_CAPABILITY_CONTRADICTION",
            file,
            pointer,
            capability,
            "a capability cannot be both required and prohibited",
            "Keep the capability in only one requirement list.",
        )


def validate_media(
    media: Any,
    exercise_id: str,
    file: str,
    pointer: str,
    media_claims: dict[str, list[str]],
    media_roles: dict[str, str],
    report: ValidationReport,
) -> None:
    if media is None:
        report.add_error(
            "E_MEDIA_LIST",
            file,
            pointer,
            media,
            "media must be an array when present",
            "Use an array of media records or omit media entirely.",
        )
        return
    if not isinstance(media, list):
        report.add_error(
            "E_MEDIA_LIST",
            file,
            pointer,
            media,
            "media must be an array when present",
            "Use an array of media records or omit media entirely.",
        )
        return
    starts: list[int | None] = []
    ends: list[int | None] = []
    sequences: dict[str, list[int]] = defaultdict(list)
    local_keys: set[str] = set()
    for index, item in enumerate(media):
        item_pointer = f"{pointer}/{index}"
        if not isinstance(item, dict):
            report.add_error(
                "E_MEDIA_RECORD",
                file,
                item_pointer,
                item,
                "media entries must be objects",
                "Use an object with key, role, and accessibilityDescription.",
            )
            continue
        key = item.get("key")
        role = item.get("role")
        description = item.get("accessibilityDescription")
        sequence = item.get("sequence")
        if not isinstance(key, str) or not key.strip() or key != key.strip():
            report.add_error(
                "E_MEDIA_KEY",
                file,
                f"{item_pointer}/key",
                key,
                "media keys must be nonblank and cannot have surrounding whitespace",
                "Use a stable logical media key without surrounding whitespace.",
            )
        elif not MEDIA_KEY_PATTERN.fullmatch(key) or not key.startswith(f"{exercise_id}__"):
            report.add_error(
                "E_MEDIA_KEY_FORMAT",
                file,
                f"{item_pointer}/key",
                key,
                "media keys must start with the exercise ID followed by __role",
                f"Use a key such as {exercise_id}__composite.",
            )
        else:
            if key in local_keys:
                report.add_error(
                    "E_MEDIA_KEY_DUPLICATE",
                    file,
                    f"{item_pointer}/key",
                    key,
                    "media keys must be unique within an exercise",
                    "Give each media item a distinct logical key.",
                )
            local_keys.add(key)
            media_claims[key].append(item_pointer)
        if not isinstance(role, str) or role not in MEDIA_ROLES:
            report.add_error(
                "E_MEDIA_ROLE",
                file,
                f"{item_pointer}/role",
                role,
                "media roles must use the controlled media role vocabulary",
                "Use thumbnail, setup, start, mid, end, alternate, mistake, correct, or composite.",
            )
        elif (
            isinstance(key, str)
            and MEDIA_KEY_PATTERN.fullmatch(key) is not None
            and key.startswith(f"{exercise_id}__")
        ):
            if not media_key_has_role(key, role):
                report.add_error(
                    "E_MEDIA_KEY_ROLE_MISMATCH",
                    file,
                    f"{item_pointer}/role",
                    role,
                    "the first media-key suffix must equal the declared media role",
                    f"Use role {media_key_role(key)!r} or rename the media key.",
                )
            media_roles.setdefault(key, role)
        if not isinstance(description, str) or not description.strip():
            report.add_error(
                "E_MEDIA_ACCESSIBILITY",
                file,
                f"{item_pointer}/accessibilityDescription",
                description,
                "media requires nonblank accessibilityDescription text",
                "Describe the instructional image for assistive technologies.",
            )
        if sequence is not None and not positive_integer(sequence):
            report.add_error(
                "E_MEDIA_SEQUENCE",
                file,
                f"{item_pointer}/sequence",
                sequence,
                "media sequence values must be positive integers",
                "Use a sequence starting at 1 or omit it for an unordered item.",
            )
        if role == "start":
            starts.append(sequence if positive_integer(sequence) else None)
        if role == "end":
            ends.append(sequence if positive_integer(sequence) else None)
        if positive_integer(sequence):
            variant = item.get("variant") if role == "alternate" else None
            namespace = f"alternate:{variant or ''}" if role == "alternate" else "primary"
            sequences[namespace].append(sequence)

    if bool(starts) != bool(ends):
        missing = "end" if starts else "start"
        report.add_error(
            "E_MEDIA_MISSING_ENDPOINT",
            file,
            pointer,
            missing,
            "start and end media roles must occur as a pair",
            f"Add the missing {missing} item or remove the unmatched endpoint.",
        )
    if starts and ends:
        if any(sequence is None for sequence in starts):
            report.add_error(
                "E_MEDIA_ENDPOINT_SEQUENCE",
                file,
                pointer,
                "start",
                "start media in a pair requires a positive sequence",
                "Add a positive sequence to every start item.",
            )
        if any(sequence is None for sequence in ends):
            report.add_error(
                "E_MEDIA_ENDPOINT_SEQUENCE",
                file,
                pointer,
                "end",
                "end media in a pair requires a positive sequence",
                "Add a positive sequence to every end item.",
            )
        known_starts = [sequence for sequence in starts if sequence is not None]
        known_ends = [sequence for sequence in ends if sequence is not None]
        if known_starts and known_ends and max(known_starts) >= min(known_ends):
            report.add_error(
                "E_MEDIA_ENDPOINT_ORDER",
                file,
                pointer,
                {"start": known_starts, "end": known_ends},
                "all start frames must precede all end frames",
                "Order start frames before end frames with distinct positive sequences.",
            )
    for namespace, values in sorted(sequences.items()):
        duplicates = sorted({value for value in values if values.count(value) > 1})
        for duplicate in duplicates:
            report.add_error(
                "E_MEDIA_SEQUENCE_DUPLICATE",
                file,
                pointer,
                {"namespace": namespace, "sequence": duplicate},
                "media sequences must be unique inside each namespace",
                "Assign each frame a distinct sequence number.",
            )
        unique_values = sorted(set(values))
        if unique_values and unique_values != list(range(1, unique_values[-1] + 1)):
            report.add_error(
                "E_MEDIA_SEQUENCE_GAP",
                file,
                pointer,
                {"namespace": namespace, "sequences": unique_values},
                "media sequences must be contiguous from 1 inside each namespace",
                "Renumber the sequence without gaps.",
            )


def validate_replacements(
    edges: dict[str, str],
    exercise_by_id: dict[str, dict[str, Any]],
    file: str,
    report: ValidationReport,
) -> None:
    for exercise_id, replacement_id in sorted(edges.items()):
        if replacement_id not in exercise_by_id:
            report.add_error(
                "E_REPLACEMENT_UNKNOWN",
                file,
                "/exercises",
                f"{exercise_id} -> {replacement_id}",
                "replacementExerciseID must reference an existing exercise",
                "Add the replacement record or correct replacementExerciseID.",
            )
            continue
        lifecycle = exercise_by_id[replacement_id].get("lifecycle", {})
        if isinstance(lifecycle, dict) and lifecycle.get("status") == "disabled":
            report.add_error(
                "E_REPLACEMENT_DISABLED",
                file,
                "/exercises",
                f"{exercise_id} -> {replacement_id}",
                "a replacement exercise cannot be disabled",
                "Choose an active or deprecated replacement exercise.",
            )

    visited: set[str] = set()
    cycles: set[tuple[str, ...]] = set()
    for start in sorted(edges):
        if start in visited:
            continue
        positions: dict[str, int] = {}
        path: list[str] = []
        current = start
        while current in edges and current in exercise_by_id:
            if current in positions:
                cycle = path[positions[current] :]
                cycles.add(canonical_cycle(cycle))
                break
            if current in visited:
                break
            positions[current] = len(path)
            path.append(current)
            current = edges[current]
        visited.update(path)
    for cycle in sorted(cycles):
        report.add_error(
            "E_REPLACEMENT_CYCLE",
            file,
            "/exercises",
            " -> ".join(cycle),
            "replacementExerciseID links cannot form a cycle",
            "Remove one replacement link so the chain terminates.",
        )


def validate_import_map(
    data: Any,
    path: Path,
    root: Path,
    media_roles: dict[str, str],
    source_pack: Path | None,
    report: ValidationReport,
) -> dict[str, dict[str, Any]]:
    file = relative_path(root, path)
    if not isinstance(data, dict):
        report.add_error(
            "E_IMPORT_MAP_OBJECT",
            file,
            "",
            data,
            "media-import-map.json must contain a top-level object",
            "Replace the top-level value with the documented import-map object.",
        )
        return {}
    validate_schema_version(data.get("schemaVersion"), file, "/schemaVersion", report)
    images = data.get("images")
    if not isinstance(images, list):
        report.add_error(
            "E_IMPORT_MAP_LIST",
            file,
            "/images",
            images,
            "media-import-map.json must contain an images array",
            "Provide one explicit image-mapping object for every workout source image.",
        )
        return {}

    source_pack_metadata = data.get("sourcePack")
    mapped_directory: str | None = None
    if not isinstance(source_pack_metadata, dict):
        report.add_error(
            "E_IMPORT_SOURCE_PACK_METADATA",
            file,
            "/sourcePack",
            source_pack_metadata,
            "media-import-map.json must declare sourcePack metadata",
            "Record the source-pack mappedDirectory and mappedImageCount.",
        )
    else:
        directory_name = source_pack_metadata.get("directoryName")
        if (
            not isinstance(directory_name, str)
            or not directory_name.strip()
            or "/" in directory_name
            or "\\" in directory_name
            or directory_name in {".", ".."}
        ):
            report.add_error(
                "E_IMPORT_SOURCE_PACK_NAME",
                file,
                "/sourcePack/directoryName",
                directory_name,
                "directoryName must be a nonblank source-pack directory name",
                "Record the source pack's directory name without path separators.",
            )
        candidate_directory = source_pack_metadata.get("mappedDirectory")
        if not safe_source_relative_path(candidate_directory):
            report.add_error(
                "E_IMPORT_SOURCE_DIRECTORY",
                file,
                "/sourcePack/mappedDirectory",
                candidate_directory,
                "mappedDirectory must be a safe path relative to the source pack",
                "Use a directory such as workout_avatar.",
            )
        else:
            mapped_directory = candidate_directory
        verified_file_count = source_pack_metadata.get("verifiedFileCount")
        if not nonnegative_integer(verified_file_count):
            report.add_error(
                "E_IMPORT_SOURCE_FILE_COUNT",
                file,
                "/sourcePack/verifiedFileCount",
                verified_file_count,
                "verifiedFileCount must be a nonnegative integer",
                "Record the verified source-pack file count as an integer.",
            )
        mapped_image_count = source_pack_metadata.get("mappedImageCount")
        if not nonnegative_integer(mapped_image_count):
            report.add_error(
                "E_IMPORT_SOURCE_COUNT_TYPE",
                file,
                "/sourcePack/mappedImageCount",
                mapped_image_count,
                "mappedImageCount must be a nonnegative integer",
                "Record the number of explicit image rows as an integer.",
            )
        elif mapped_image_count != len(images):
            report.add_error(
                "E_IMPORT_SOURCE_COUNT",
                file,
                "/sourcePack/mappedImageCount",
                mapped_image_count,
                "mappedImageCount must equal the number of explicit image rows",
                "Update the count after adding or removing an image decision.",
            )
        source_pack_checksum = source_pack_metadata.get("verifiedZipSHA256")
        if (
            not isinstance(source_pack_checksum, str)
            or SHA256_PATTERN.fullmatch(source_pack_checksum) is None
        ):
            report.add_error(
                "E_IMPORT_SOURCE_PACK_CHECKSUM",
                file,
                "/sourcePack/verifiedZipSHA256",
                source_pack_checksum,
                "verifiedZipSHA256 must be a lowercase 64-character SHA-256 digest",
                "Record the verified source ZIP checksum without opening or changing it.",
            )

    claimed_sources: dict[str, str] = {}
    claimed_keys: dict[str, str] = {}
    approved_media_keys: set[str] = set()
    approved_rows: dict[str, dict[str, Any]] = {}
    for index, image in enumerate(images):
        pointer = f"/images/{index}"
        if not isinstance(image, dict):
            report.add_error(
                "E_IMPORT_MAP_RECORD",
                file,
                pointer,
                image,
                "import-map entries must be objects",
                "Replace the value with a complete image-mapping object.",
            )
            continue

        status = image.get("status")
        source_path = image.get("sourcePath")
        source_checksum = image.get("sourceSHA256")
        exercise_id = image.get("canonicalExerciseID")
        media_key = image.get("canonicalMediaKey")
        filename = image.get("canonicalFileName")
        role = image.get("role")
        approval_reference = image.get("approvalReference")

        if not isinstance(status, str) or status not in IMPORT_STATUSES:
            report.add_error(
                "E_IMPORT_MAP_STATUS",
                file,
                f"{pointer}/status",
                status,
                "status must be an explicit supported import decision",
                "Use approved_for_import, approved_pending_catalogue_entry, "
                "unreviewed, or quarantined.",
            )
        if isinstance(status, str) and status in {
            "approved_for_import",
            "approved_pending_catalogue_entry",
        } and (
            not isinstance(approval_reference, str) or not approval_reference.strip()
        ):
            report.add_error(
                "E_IMPORT_APPROVAL_REFERENCE",
                file,
                f"{pointer}/approvalReference",
                approval_reference,
                "approved import decisions require a nonblank approvalReference",
                "Record the accountable approval decision before importing this row.",
            )
        if not safe_source_relative_path(source_path):
            report.add_error(
                "E_IMPORT_SOURCE_PATH",
                file,
                f"{pointer}/sourcePath",
                source_path,
                "sourcePath must be a nonempty safe POSIX path relative to the source pack",
                "Use a path such as workout_avatar/bodyweight_squat.png.",
            )
        elif mapped_directory is not None and not source_path.startswith(
            f"{mapped_directory}/"
        ):
            report.add_error(
                "E_IMPORT_SOURCE_SCOPE",
                file,
                f"{pointer}/sourcePath",
                source_path,
                "sourcePath must be inside the declared mappedDirectory",
                "Map only source images from the declared exercise-media directory.",
            )
        if safe_source_relative_path(source_path) and Path(source_path).suffix.lower() != ".png":
            report.add_error(
                "E_IMPORT_SOURCE_EXTENSION",
                file,
                f"{pointer}/sourcePath",
                source_path,
                "mapped exercise-media sources must use a .png extension",
                "Point the row at the reviewed PNG source file.",
            )
        if (
            not isinstance(source_checksum, str)
            or SHA256_PATTERN.fullmatch(source_checksum) is None
        ):
            report.add_error(
                "E_IMPORT_SOURCE_CHECKSUM_FORMAT",
                file,
                f"{pointer}/sourceSHA256",
                source_checksum,
                "sourceSHA256 must be a lowercase 64-character SHA-256 digest",
                "Record the exact lowercase SHA-256 of the approved source file.",
            )
        if not is_exercise_id(exercise_id):
            report.add_error(
                "E_IMPORT_EXERCISE_ID",
                file,
                f"{pointer}/canonicalExerciseID",
                exercise_id,
                "canonicalExerciseID must use the stable exercise ID format",
                "Use the canonical stable ID proposed for this image.",
            )
        else:
            flag_canonical_dumbell(
                exercise_id, file, f"{pointer}/canonicalExerciseID", "stable IDs", report
            )
        flag_canonical_dumbell(
            media_key, file, f"{pointer}/canonicalMediaKey", "media keys", report
        )
        flag_canonical_dumbell(
            filename, file, f"{pointer}/canonicalFileName", "generated filenames", report
        )
        if not isinstance(media_key, str) or MEDIA_KEY_PATTERN.fullmatch(media_key) is None:
            report.add_error(
                "E_IMPORT_MEDIA_KEY_FORMAT",
                file,
                f"{pointer}/canonicalMediaKey",
                media_key,
                "canonicalMediaKey must use the canonical media-key format",
                "Use a key such as bodyweight.squat__composite.",
            )
        elif isinstance(exercise_id, str) and not media_key.startswith(f"{exercise_id}__"):
            report.add_error(
                "E_IMPORT_MEDIA_KEY_EXERCISE_MISMATCH",
                file,
                f"{pointer}/canonicalMediaKey",
                media_key,
                "canonicalMediaKey must begin with canonicalExerciseID followed by __",
                "Correct canonicalExerciseID or canonicalMediaKey so they describe one exercise.",
            )
        if not valid_asset_name(filename):
            report.add_error(
                "E_IMPORT_FILENAME",
                file,
                f"{pointer}/canonicalFileName",
                filename,
                "canonicalFileName must be a lowercase canonical PNG name",
                "Use canonicalMediaKey followed by .png.",
            )
        elif isinstance(media_key, str) and filename != f"{media_key}.png":
            report.add_error(
                "E_IMPORT_FILENAME_KEY_MISMATCH",
                file,
                f"{pointer}/canonicalFileName",
                filename,
                "canonicalFileName must equal canonicalMediaKey plus .png",
                "Rename the generated filename to match the canonical media key.",
            )
        if not isinstance(role, str) or role not in MEDIA_ROLES:
            report.add_error(
                "E_IMPORT_ROLE",
                file,
                f"{pointer}/role",
                role,
                "role must use the controlled media role vocabulary",
                "Use a supported role such as composite or setup.",
            )
        else:
            if (
                isinstance(media_key, str)
                and MEDIA_KEY_PATTERN.fullmatch(media_key) is not None
                and not media_key_has_role(media_key, role)
            ):
                report.add_error(
                    "E_IMPORT_MEDIA_KEY_ROLE_MISMATCH",
                    file,
                    f"{pointer}/role",
                    role,
                    "the first canonicalMediaKey suffix must equal the declared role",
                    f"Use role {media_key_role(media_key)!r} or rename the media key.",
                )
            if isinstance(media_key, str) and media_key in media_roles:
                manifest_role = media_roles[media_key]
                if role != manifest_role:
                    report.add_error(
                        "E_IMPORT_ROLE_MANIFEST_MISMATCH",
                        file,
                        f"{pointer}/role",
                        role,
                        "import-map role must match the manifest media role",
                        f"Use role {manifest_role!r} for {media_key}.",
                    )

        if isinstance(source_path, str):
            previous_pointer = claimed_sources.get(source_path)
            if previous_pointer is not None:
                report.add_error(
                    "E_IMPORT_SOURCE_DUPLICATE",
                    file,
                    f"{pointer}/sourcePath",
                    source_path,
                    "each source image must have exactly one explicit mapping decision",
                    f"Merge this decision with {previous_pointer} or choose a distinct "
                    "source image.",
                )
            else:
                claimed_sources[source_path] = pointer
        if isinstance(media_key, str):
            previous_pointer = claimed_keys.get(media_key)
            if previous_pointer is not None:
                report.add_error(
                    "E_IMPORT_MEDIA_KEY_DUPLICATE",
                    file,
                    f"{pointer}/canonicalMediaKey",
                    media_key,
                    "one canonical media key cannot be claimed by multiple source images",
                    f"Use a distinct media key or consolidate the row with {previous_pointer}.",
                )
            else:
                claimed_keys[media_key] = pointer

        if status == "approved_for_import" and (
            not isinstance(media_key, str) or media_key not in media_roles
        ):
            report.add_error(
                "E_IMPORT_MAP_KEY_UNKNOWN",
                file,
                f"{pointer}/canonicalMediaKey",
                media_key,
                "approved import rows must map to exactly one current manifest media key",
                "Add the approved manifest media record first or defer this row "
                "pending a catalogue entry.",
            )
        if status == "approved_for_import" and isinstance(media_key, str):
            approved_media_keys.add(media_key)
            approved_rows.setdefault(media_key, image)

        if source_pack is not None and safe_source_relative_path(source_path):
            try:
                source_file = (source_pack / source_path).resolve()
            except (OSError, ValueError):
                report.add_error(
                    "E_IMPORT_SOURCE_PATH",
                    file,
                    f"{pointer}/sourcePath",
                    source_path,
                    "sourcePath must resolve safely inside the supplied source pack",
                    "Replace malformed path characters with a safe POSIX relative path.",
                )
                continue
            if not source_file.is_relative_to(source_pack):
                report.add_error(
                    "E_IMPORT_SOURCE_OUTSIDE_PACK",
                    file,
                    f"{pointer}/sourcePath",
                    source_path,
                    "sourcePath must resolve inside the supplied source pack",
                    "Remove traversal segments and use the source-pack-relative path.",
                )
            elif not source_file.is_file():
                report.add_error(
                    "E_IMPORT_SOURCE_MISSING",
                    file,
                    f"{pointer}/sourcePath",
                    source_path,
                    "every mapped source image must exist in the supplied source pack",
                    "Restore the approved source image or correct sourcePath.",
                )
            else:
                png_details = validate_png_readable(
                    source_file,
                    file,
                    f"{pointer}/sourcePath",
                    source_path,
                    "E_IMPORT_SOURCE_PNG",
                    "mapped source files must contain readable PNG image data",
                    "Replace the source with the reviewed PNG export.",
                    report,
                )
                if (
                    png_details is not None
                    and isinstance(source_checksum, str)
                    and SHA256_PATTERN.fullmatch(source_checksum)
                ):
                    try:
                        actual_checksum = sha256(source_file)
                    except OSError:
                        report.add_error(
                            "E_IMPORT_SOURCE_CHECKSUM_READ",
                            file,
                            f"{pointer}/sourcePath",
                            source_path,
                            "source PNG bytes must remain readable for checksum verification",
                            "Restore stable read access to the reviewed source PNG.",
                        )
                    else:
                        if actual_checksum != source_checksum:
                            report.add_error(
                                "E_IMPORT_SOURCE_CHECKSUM",
                                file,
                                f"{pointer}/sourceSHA256",
                                source_checksum,
                                "the source image checksum must match the approved mapping "
                                "record",
                                "Stop the import and record the exact checksum of the reviewed "
                                "source file.",
                            )

    if source_pack is not None and mapped_directory is not None:
        mapped_root = (source_pack / mapped_directory).resolve()
        if not mapped_root.is_relative_to(source_pack) or not mapped_root.is_dir():
            report.add_error(
                "E_IMPORT_SOURCE_DIRECTORY_MISSING",
                file,
                "/sourcePack/mappedDirectory",
                mapped_directory,
                "mappedDirectory must exist inside the supplied source pack",
                "Supply the reviewed source pack or correct mappedDirectory.",
            )
        else:
            expected_sources = set()
            for source_file in mapped_root.rglob("*"):
                if not source_file.is_file() or source_file.suffix.lower() != ".png":
                    continue
                if source_file.name.startswith("._"):
                    report.add_warning(
                        "W_SOURCE_APPLEDOUBLE_SKIPPED",
                        file,
                        "/images",
                        relative_path(source_pack, source_file),
                        "macOS AppleDouble metadata files are transfer artifacts, "
                        "not catalogue images",
                        "Delete the ._ file from the transferred pack; it must never "
                        "receive an import-map row.",
                    )
                    continue
                expected_sources.add(relative_path(source_pack, source_file))
            for unmapped_source in sorted(expected_sources - set(claimed_sources)):
                report.add_error(
                    "E_IMPORT_SOURCE_UNMAPPED",
                    file,
                    "/images",
                    unmapped_source,
                    "every source image in mappedDirectory requires an explicit mapping status",
                    "Add an approved, pending, unreviewed, or quarantined image row.",
                )

    for unmapped_media_key in sorted(set(media_roles) - approved_media_keys):
        report.add_error(
            "E_IMPORT_MAP_MANIFEST_MEDIA_UNMAPPED",
            file,
            "/images",
            unmapped_media_key,
            "every current manifest media key requires an approved import row",
            "Add an approved_for_import row with a reviewed source checksum.",
        )
    return approved_rows


def validate_generated_media(
    root: Path,
    media_roles: dict[str, str],
    approved_rows: dict[str, dict[str, Any]],
    report: ValidationReport,
) -> None:
    index_path = root / GENERATED_DIRECTORY / "media-index.json"
    namespace = root / GENERATED_ASSET_DIRECTORY
    partial_generated = bool(media_roles) and (
        path_entry_exists(namespace) or path_entry_exists(index_path)
    )
    generated_required = bool(approved_rows) or partial_generated
    if not namespace.is_dir() and (generated_required or path_entry_exists(index_path)):
        report.add_error(
            "E_MEDIA_NAMESPACE_MISSING",
            relative_path(root, namespace),
            "",
            namespace.name,
            "approved generated media requires the ExerciseMedia asset namespace",
            "Run import --apply to regenerate the complete ExerciseMedia namespace.",
        )
    if not index_path.is_file():
        if generated_required:
            report.add_error(
                "E_MEDIA_INDEX_FILE_MISSING",
                relative_path(root, index_path),
                "",
                index_path.name,
                "approved generated media requires media-index.json",
                "Run import --apply to regenerate the media index.",
            )
        return

    file = relative_path(root, index_path)
    data = load_json(index_path, root, report)
    if not isinstance(data, dict):
        if data is not None:
            report.add_error(
                "E_MEDIA_INDEX_OBJECT",
                file,
                "",
                data,
                "generated media index must contain a top-level object",
                "Regenerate media-index.json with the importer.",
            )
        return
    validate_schema_version(data.get("schemaVersion"), file, "/schemaVersion", report)
    entries = data.get("media")
    if not isinstance(entries, list):
        report.add_error(
            "E_MEDIA_INDEX_LIST",
            file,
            "/media",
            entries,
            "generated media index must contain a media array",
            "Regenerate media-index.json with the importer.",
        )
        return

    if namespace.is_dir():
        validate_generated_namespace_contents(namespace, root, report)
        actual_assets = {
            child.name[: -len(".imageset")]
            for child in namespace.iterdir()
            if child.is_dir() and child.name.endswith(".imageset")
        }
        expected_assets = set(media_roles)
        for asset_name in sorted(expected_assets - actual_assets):
            report.add_error(
                "E_MEDIA_IMAGESET_MISSING",
                relative_path(root, namespace),
                "",
                asset_name,
                "every manifest media key requires one generated imageset",
                "Run import --apply to regenerate the missing imageset.",
            )
        for asset_name in sorted(actual_assets - expected_assets):
            report.add_error(
                "E_MEDIA_IMAGESET_EXTRA",
                relative_path(root, namespace),
                "",
                asset_name,
                "generated imagesets must have an exact manifest-key match",
                "Run import --apply to remove the extra imageset.",
            )

    indexed_keys: set[str] = set()
    indexed_assets: set[str] = set()
    for index, entry in enumerate(entries):
        pointer = f"/media/{index}"
        if not isinstance(entry, dict):
            report.add_error(
                "E_MEDIA_INDEX_RECORD",
                file,
                pointer,
                entry,
                "generated media index entries must be objects",
                "Regenerate the media index with the importer.",
            )
            continue
        key = entry.get("key")
        asset_name = entry.get("assetName")
        filename = entry.get("filename")
        role = entry.get("role")
        source_path = entry.get("sourcePath")
        source_checksum = entry.get("sourceSHA256")
        if not all(
            isinstance(value, str)
            for value in (key, asset_name, filename, role, source_path, source_checksum)
        ):
            report.add_error(
                "E_MEDIA_INDEX_FIELDS",
                file,
                pointer,
                entry,
                "media index entries require string key, asset, file, role, and source fields",
                "Regenerate the media index with complete mapping fields.",
            )
            continue
        key_is_canonical = MEDIA_KEY_PATTERN.fullmatch(key) is not None
        if not key_is_canonical:
            report.add_error(
                "E_MEDIA_INDEX_KEY",
                file,
                f"{pointer}/key",
                key,
                "generated media keys must use the canonical media-key format",
                "Regenerate the media index from the approved import map.",
            )
        if key in indexed_keys:
            report.add_error(
                "E_MEDIA_INDEX_KEY_DUPLICATE",
                file,
                f"{pointer}/key",
                key,
                "generated media index keys must be unique",
                "Regenerate the media index from unique approved map rows.",
            )
        indexed_keys.add(key)
        if asset_name in indexed_assets:
            report.add_error(
                "E_MEDIA_INDEX_ASSET_DUPLICATE",
                file,
                f"{pointer}/assetName",
                asset_name,
                "generated asset names must be unique",
                "Regenerate the media index from unique approved map rows.",
            )
        indexed_assets.add(asset_name)
        if asset_name != key:
            report.add_error(
                "E_MEDIA_INDEX_ASSET_NAME",
                file,
                f"{pointer}/assetName",
                asset_name,
                "assetName must equal the canonical media key",
                f"Use assetName {key!r}.",
            )
        filename_is_canonical = valid_asset_name(filename) and filename == f"{key}.png"
        if not filename_is_canonical:
            report.add_error(
                "E_MEDIA_INDEX_FILENAME",
                file,
                f"{pointer}/filename",
                filename,
                "generated filename must equal the canonical media key plus .png",
                f"Use filename {key}.png.",
            )
        if role not in MEDIA_ROLES:
            report.add_error(
                "E_MEDIA_INDEX_ROLE",
                file,
                f"{pointer}/role",
                role,
                "generated media role must use the controlled role vocabulary",
                "Regenerate the media index from the approved import map.",
            )
        elif key_is_canonical and not media_key_has_role(key, role):
            report.add_error(
                "E_MEDIA_INDEX_KEY_ROLE_MISMATCH",
                file,
                f"{pointer}/role",
                role,
                "the first generated media-key suffix must equal the declared role",
                f"Use role {media_key_role(key)!r} or regenerate the media index.",
            )
        manifest_role = media_roles.get(key)
        if manifest_role is not None and role != manifest_role:
            report.add_error(
                "E_MEDIA_INDEX_ROLE_MISMATCH",
                file,
                f"{pointer}/role",
                role,
                "generated role must match the manifest and approved import map",
                f"Use role {manifest_role!r} for {key}.",
            )
        if not safe_source_relative_path(source_path):
            report.add_error(
                "E_MEDIA_INDEX_SOURCE_PATH",
                file,
                f"{pointer}/sourcePath",
                source_path,
                "generated sourcePath must be a safe source-pack-relative path",
                "Regenerate the media index from the approved import map.",
            )
        if SHA256_PATTERN.fullmatch(source_checksum) is None:
            report.add_error(
                "E_MEDIA_INDEX_CHECKSUM_FORMAT",
                file,
                f"{pointer}/sourceSHA256",
                source_checksum,
                "generated sourceSHA256 must be a lowercase SHA-256 digest",
                "Regenerate the media index from the approved import map.",
            )

        approved_row = approved_rows.get(key)
        if approved_row is not None:
            if role != approved_row.get("role"):
                report.add_error(
                    "E_MEDIA_INDEX_ROLE_MISMATCH",
                    file,
                    f"{pointer}/role",
                    role,
                    "generated role must match the approved import-map row",
                    "Regenerate generated media from the current approved map.",
                )
            if source_path != approved_row.get("sourcePath"):
                report.add_error(
                    "E_MEDIA_INDEX_SOURCE_MISMATCH",
                    file,
                    f"{pointer}/sourcePath",
                    source_path,
                    "generated sourcePath must match the approved import-map row",
                    "Regenerate generated media from the current approved map.",
                )
            if source_checksum != approved_row.get("sourceSHA256"):
                report.add_error(
                    "E_MEDIA_INDEX_CHECKSUM_MISMATCH",
                    file,
                    f"{pointer}/sourceSHA256",
                    source_checksum,
                    "generated checksum provenance must match the approved import-map row",
                    "Regenerate generated media from the current approved map.",
                )
            if filename != approved_row.get("canonicalFileName"):
                report.add_error(
                    "E_MEDIA_INDEX_FILENAME_MISMATCH",
                    file,
                    f"{pointer}/filename",
                    filename,
                    "generated filename must match the approved import-map row",
                    "Regenerate generated media from the current approved map.",
                )

        if not namespace.is_dir() or not key_is_canonical or asset_name != key:
            continue
        image_set = namespace / f"{asset_name}.imageset"
        if not image_set.is_dir():
            report.add_error(
                "E_MEDIA_ASSET_MISSING",
                file,
                pointer,
                asset_name,
                "media index entries must resolve to generated imagesets",
                "Run import --apply to regenerate the imageset.",
            )
            continue
        if not filename_is_canonical:
            continue
        validate_generated_imageset_contents(image_set, filename, root, report)
        png_path = image_set / filename
        if not png_path.is_file():
            report.add_error(
                "E_MEDIA_PNG_MISSING",
                relative_path(root, image_set),
                "",
                filename,
                "Contents.json and the media index must reference an existing PNG",
                "Run import --apply to restore the canonical PNG.",
            )
            continue
        png_details = validate_png_readable(
            png_path,
            file,
            f"{pointer}/filename",
            filename,
            "E_MEDIA_PNG_INVALID",
            "generated media files must contain readable PNG image data",
            "Run import --apply from the reviewed source pack.",
            report,
        )
        if png_details is not None and SHA256_PATTERN.fullmatch(source_checksum):
            try:
                actual_checksum = sha256(png_path)
            except OSError:
                report.add_error(
                    "E_MEDIA_PNG_CHECKSUM_READ",
                    file,
                    f"{pointer}/filename",
                    filename,
                    "generated PNG bytes must remain readable for checksum verification",
                    "Run import --apply to restore a stably readable generated PNG.",
                )
            else:
                if actual_checksum != source_checksum:
                    report.add_error(
                        "E_MEDIA_PNG_CHECKSUM",
                        file,
                        f"{pointer}/sourceSHA256",
                        source_checksum,
                        "generated PNG bytes must match their approved source checksum",
                        "Run import --apply from the unchanged reviewed source pack.",
                    )

    for key in sorted(set(media_roles) - indexed_keys):
        report.add_error(
            "E_MEDIA_INDEX_MISSING",
            file,
            "/media",
            key,
            "every manifest media key must exist in the generated media index",
            "Run the importer after approving an import-map entry.",
        )
    for key in sorted(indexed_keys - set(media_roles)):
        report.add_error(
            "E_MEDIA_INDEX_ORPHAN",
            file,
            "/media",
            key,
            "generated media keys must be referenced by the manifest",
            "Remove the orphan via the importer or add an approved manifest reference.",
        )


def validate_generated_namespace_contents(
    namespace: Path,
    root: Path,
    report: ValidationReport,
) -> None:
    contents_path = namespace / "Contents.json"
    if not contents_path.is_file():
        report.add_error(
            "E_MEDIA_NAMESPACE_CONTENTS_MISSING",
            relative_path(root, namespace),
            "",
            contents_path.name,
            "the generated ExerciseMedia namespace requires Contents.json",
            "Run import --apply to regenerate the asset namespace metadata.",
        )
        return
    data = load_json(contents_path, root, report)
    expected = {"author": "xcode", "version": 1}
    if not isinstance(data, dict) or data.get("info") != expected:
        report.add_error(
            "E_MEDIA_NAMESPACE_CONTENTS",
            relative_path(root, contents_path),
            "",
            data,
            "ExerciseMedia Contents.json must contain canonical Xcode metadata",
            "Run import --apply to regenerate the asset namespace metadata.",
        )


def validate_generated_imageset_contents(
    image_set: Path,
    expected_filename: str,
    root: Path,
    report: ValidationReport,
) -> None:
    contents_path = image_set / "Contents.json"
    if not contents_path.is_file():
        report.add_error(
            "E_MEDIA_CONTENTS_MISSING",
            relative_path(root, image_set),
            "",
            contents_path.name,
            "every generated imageset requires Contents.json",
            "Run import --apply to regenerate the imageset metadata.",
        )
        return
    data = load_json(contents_path, root, report)
    if not isinstance(data, dict):
        if data is not None:
            report.add_error(
                "E_MEDIA_CONTENTS_OBJECT",
                relative_path(root, contents_path),
                "",
                data,
                "imageset Contents.json must contain a top-level object",
                "Run import --apply to regenerate the imageset metadata.",
            )
        return
    images = data.get("images")
    expected_images = [{"filename": expected_filename, "idiom": "universal"}]
    if images != expected_images:
        report.add_error(
            "E_MEDIA_CONTENTS_IMAGES",
            relative_path(root, contents_path),
            "/images",
            images,
            "imageset Contents.json must reference only the canonical universal PNG",
            "Run import --apply to regenerate the imageset metadata.",
        )
    if data.get("info") != {"author": "xcode", "version": 1}:
        report.add_error(
            "E_MEDIA_CONTENTS_INFO",
            relative_path(root, contents_path),
            "/info",
            data.get("info"),
            "imageset Contents.json must contain canonical Xcode metadata",
            "Run import --apply to regenerate the imageset metadata.",
        )


def validate_intake_assets(root: Path, media_keys: set[str], report: ValidationReport) -> None:
    intake = root / INTAKE_DIRECTORY
    if not intake.is_dir():
        return
    files = sorted(path for path in intake.rglob("*") if path.is_file())
    report.intake_asset_count = len(files)
    content_hashes: dict[str, Path] = {}
    lower_names: dict[str, Path] = {}
    for path in files:
        file = relative_path(root, path)
        name = path.name
        lowered = name.casefold()
        previous_case = lower_names.get(lowered)
        if previous_case is not None and previous_case.name != name:
            report.add_error(
                "E_ASSET_CASE_COLLISION",
                file,
                "",
                name,
                "asset names must not collide on case-insensitive filesystems",
                "Rename one asset to a distinct canonical name.",
            )
        lower_names[lowered] = path
        if not valid_asset_name(name):
            report.add_error(
                "E_ASSET_NAME",
                file,
                "",
                name,
                "intake PNG names must use canonical lowercase media naming",
                "Use <exercise-id>__<role>[_NN][__variant][__appearance].png.",
            )
        if path.suffix.lower() != ".png":
            report.add_error(
                "E_ASSET_EXTENSION",
                file,
                "",
                name,
                "intake assets must be PNG files",
                "Convert the asset to a single .png file.",
            )
            continue
        metadata = validate_png(path, root, report)
        if metadata is not None:
            try:
                checksum = sha256(path)
            except OSError:
                report.add_error(
                    "E_ASSET_CHECKSUM_READ",
                    file,
                    "",
                    name,
                    "intake PNG bytes must remain readable for checksum verification",
                    "Restore stable read access to the intake PNG.",
                )
            else:
                prior = content_hashes.get(checksum)
                if prior is not None:
                    report.add_error(
                        "E_ASSET_DUPLICATE_CONTENT",
                        file,
                        "",
                        f"{prior.name}, {name}",
                        "exact duplicate image content cannot occupy two intake names",
                        "Keep one approved source and map it explicitly.",
                    )
                else:
                    content_hashes[checksum] = path
        stem = name[:-4] if name.lower().endswith(".png") else ""
        if stem and stem not in media_keys:
            report.add_error(
                "E_ASSET_ORPHAN",
                file,
                "",
                stem,
                "intake asset names must match an approved manifest media key",
                "Add an approved media key or remove the unreferenced intake file.",
            )


def validate_png_readable(
    path: Path,
    file: str,
    pointer: str,
    value: Any,
    code: str,
    rule: str,
    fix: str,
    report: ValidationReport,
) -> tuple[int, int, str] | None:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(path) as image:
                image_format = image.format
                image.verify()
            with Image.open(path) as image:
                width, height = image.size
                mode = image.mode
                image.load()
    except (
        OSError,
        SyntaxError,
        ValueError,
        UnidentifiedImageError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ):
        report.add_error(
            code,
            file,
            pointer,
            value,
            rule,
            fix,
        )
        return None
    if image_format != "PNG" or width <= 0 or height <= 0 or not mode:
        report.add_error(
            code,
            file,
            pointer,
            value,
            rule,
            fix,
        )
        return None
    return width, height, mode


def validate_png(
    path: Path,
    root: Path,
    report: ValidationReport,
) -> tuple[int, int, str] | None:
    file = relative_path(root, path)
    metadata = validate_png_readable(
        path,
        file,
        "",
        path.name,
        "E_PNG_INVALID",
        "intake files with a .png extension must be valid PNG images",
        "Replace the corrupted file with a valid PNG source.",
        report,
    )
    if metadata is None:
        return
    width, height, mode = metadata
    if width != height or width != 1254:
        report.add_warning(
            "W_PNG_DIMENSIONS",
            file,
            "",
            f"{width}x{height}",
            "the supplied exercise pack uses 1254x1254 square instructional PNGs",
            "Obtain an approved square export or document the deliberate exception.",
        )
    if "A" not in mode:
        report.add_warning(
            "W_PNG_ALPHA",
            file,
            "",
            mode,
            "instructional PNGs normally preserve transparency",
            "Confirm the opaque background is intentional or obtain an alpha export.",
        )
    return metadata


def validate_schema_version(
    value: Any,
    file: str,
    pointer: str,
    report: ValidationReport,
    key_name: str = "schemaVersion",
) -> None:
    if (
        not isinstance(value, int)
        or isinstance(value, bool)
        or value != CATALOG_SCHEMA_VERSION
    ):
        report.add_error(
            "E_SCHEMA_VERSION",
            file,
            pointer,
            value,
            f"{key_name} must equal supported version {CATALOG_SCHEMA_VERSION}",
            f"Use {key_name}: {CATALOG_SCHEMA_VERSION} or add a documented migration.",
        )


def canonical_cycle(cycle: list[str]) -> tuple[str, ...]:
    if not cycle:
        return ()
    rotations = [tuple(cycle[index:] + cycle[:index]) for index in range(len(cycle))]
    return min(rotations)


def find_cycles(edges: dict[str, str]) -> set[tuple[str, ...]]:
    visited: set[str] = set()
    cycles: set[tuple[str, ...]] = set()
    for start in sorted(edges):
        if start in visited:
            continue
        positions: dict[str, int] = {}
        path: list[str] = []
        current = start
        while current in edges:
            if current in positions:
                cycles.add(canonical_cycle(path[positions[current] :]))
                break
            if current in visited:
                break
            positions[current] = len(path)
            path.append(current)
            current = edges[current]
        visited.update(path)
    return cycles


def normalise_reference(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    folded = unicodedata.normalize("NFKD", value).casefold()
    normalized = "".join(character for character in folded if character.isalnum())
    return normalized or None


def normalized_reference(value: Any) -> str | None:
    return normalise_reference(value)


def is_exercise_id(value: Any) -> bool:
    return isinstance(value, str) and EXERCISE_ID_PATTERN.fullmatch(value) is not None


def is_token(value: Any) -> bool:
    return isinstance(value, str) and TOKEN_PATTERN.fullmatch(value) is not None


def positive_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def nonnegative_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def valid_asset_name(name: Any) -> bool:
    if not isinstance(name, str) or not name.endswith(".png") or name != name.lower():
        return False
    if ".." in name or " " in name or "'" in name or "dumbell" in name:
        return False
    stem = name[:-4]
    return MEDIA_KEY_PATTERN.fullmatch(stem) is not None


def media_key_role(key: Any) -> str | None:
    if not isinstance(key, str) or MEDIA_KEY_PATTERN.fullmatch(key) is None:
        return None
    first_suffix = key.split("__", 1)[1].split("__", 1)[0]
    for role in sorted(MEDIA_ROLES, key=len, reverse=True):
        if first_suffix == role or re.fullmatch(rf"{re.escape(role)}_[0-9]+", first_suffix):
            return role
    return None


def media_key_has_role(key: Any, role: Any) -> bool:
    return isinstance(role, str) and media_key_role(key) == role


def safe_source_relative_path(value: Any) -> bool:
    if not isinstance(value, str) or not value or "\\" in value or value.startswith("/"):
        return False
    if any(unicodedata.category(character) in {"Cc", "Cf", "Cs"} for character in value):
        return False
    parts = value.split("/")
    return all(part not in {"", ".", ".."} for part in parts)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def relative_path(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path)


def json_pointer_from_line(path: Path, line_number: int) -> str:
    del path, line_number
    return ""


def load_validated_import_map(
    root: Path | str,
    source_pack: Path | str,
) -> tuple[Path, list[dict[str, Any]]] | None:
    root_path = Path(root).resolve()
    import_map_path = root_path / AUTHORING_DIRECTORY / IMPORT_MAPPING_FILENAME
    if not import_map_path.is_file():
        print(f"ERROR E_IMPORT_MAP_MISSING {relative_path(root_path, import_map_path)}")
        return None

    report = validate_catalogue(
        root_path,
        strict=True,
        source_pack=source_pack,
        include_generated=False,
    )
    if report.errors or report.warnings:
        print_report(report)
        return None

    import_map = json.loads(import_map_path.read_text(encoding="utf-8"))
    return root_path, import_map["images"]


def run_import_dry_run(root: Path | str, source_pack: Path | str) -> int:
    import_map = load_validated_import_map(root, source_pack)
    if import_map is None:
        return 1
    root_path, images = import_map
    mapped_rows = sorted(
        images,
        key=lambda image: image["canonicalMediaKey"],
    )
    status_counts = {
        status: sum(image["status"] == status for image in images)
        for status in sorted(IMPORT_STATUSES)
    }
    print(
        "exercise-catalog import dry run: "
        f"approved={status_counts['approved_for_import']} "
        f"pending={status_counts['approved_pending_catalogue_entry']} "
        f"unreviewed={status_counts['unreviewed']} "
        f"quarantined={status_counts['quarantined']}"
    )
    for image in mapped_rows:
        destination = (
            root_path
            / "Health Assistantv2"
            / "Assets.xcassets"
            / "ExerciseMedia"
            / f"{image['canonicalMediaKey']}.imageset"
            / image["canonicalFileName"]
        )
        action = "COPY" if image["status"] == "approved_for_import" else "REJECT"
        print(
            f"DRY-RUN {action} status={image['status']} "
            f"{image['sourcePath']} -> {relative_path(root_path, destination)}"
        )
    return 0


def run_import_apply(root: Path | str, source_pack: Path | str) -> int:
    import_map = load_validated_import_map(root, source_pack)
    if import_map is None:
        return 1
    root_path, images = import_map
    source_pack_path = Path(source_pack).resolve()
    approved_rows = sorted(
        (image for image in images if image["status"] == "approved_for_import"),
        key=lambda image: image["canonicalMediaKey"],
    )
    pending_count = sum(
        image["status"] == "approved_pending_catalogue_entry" for image in images
    )
    unreviewed_count = sum(image["status"] == "unreviewed" for image in images)
    quarantined_count = sum(image["status"] == "quarantined" for image in images)
    staging_root = root_path / f".exercise-catalog-import-{uuid.uuid4().hex}"
    staging_root.mkdir()
    staging_assets = staging_root / "ExerciseMedia"
    staging_index = staging_root / "media-index.json"
    try:
        write_staged_import(approved_rows, source_pack_path, staging_assets, staging_index)
        verify_staged_import(approved_rows, staging_assets, staging_index)
        replace_generated_import(root_path, staging_assets, staging_index)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR E_IMPORT_APPLY {error}")
        return 1
    finally:
        if staging_root.exists():
            shutil.rmtree(staging_root)

    post_apply_report = validate_catalogue(
        root_path,
        strict=True,
        source_pack=source_pack_path,
    )
    if post_apply_report.errors or post_apply_report.warnings:
        print_report(post_apply_report)
        return 1

    print(
        "exercise-catalog import applied: "
        f"approved={len(approved_rows)} rejected_pending={pending_count} "
        f"rejected_unreviewed={unreviewed_count} rejected_quarantined={quarantined_count}"
    )
    return 0


def write_staged_import(
    approved_rows: list[dict[str, Any]],
    source_pack: Path,
    staging_assets: Path,
    staging_index: Path,
) -> None:
    staging_assets.mkdir(parents=True)
    write_json_file(
        staging_assets / "Contents.json",
        {"info": {"author": "xcode", "version": 1}},
    )
    media_index: list[dict[str, str]] = []
    for image in approved_rows:
        image_set = staging_assets / f"{image['canonicalMediaKey']}.imageset"
        image_set.mkdir()
        destination = image_set / image["canonicalFileName"]
        source = source_pack / image["sourcePath"]
        shutil.copy2(source, destination)
        write_json_file(
            image_set / "Contents.json",
            {
                "images": [
                    {"filename": image["canonicalFileName"], "idiom": "universal"}
                ],
                "info": {"author": "xcode", "version": 1},
            },
        )
        media_index.append(
            {
                "assetName": image["canonicalMediaKey"],
                "filename": image["canonicalFileName"],
                "key": image["canonicalMediaKey"],
                "role": image["role"],
                "sourcePath": image["sourcePath"],
                "sourceSHA256": image["sourceSHA256"],
            }
        )
    write_json_file(staging_index, {"media": media_index, "schemaVersion": 1})


def verify_staged_import(
    approved_rows: list[dict[str, Any]],
    staging_assets: Path,
    staging_index: Path,
) -> None:
    staged_index = json.loads(staging_index.read_text(encoding="utf-8"))
    expected_keys = [image["canonicalMediaKey"] for image in approved_rows]
    indexed_keys = [entry["key"] for entry in staged_index["media"]]
    if staged_index.get("schemaVersion") != 1 or indexed_keys != expected_keys:
        raise ValueError("staged media index does not match the approved import rows")
    for image in approved_rows:
        image_set = staging_assets / f"{image['canonicalMediaKey']}.imageset"
        destination = image_set / image["canonicalFileName"]
        contents = json.loads((image_set / "Contents.json").read_text(encoding="utf-8"))
        if sha256(destination) != image["sourceSHA256"]:
            raise ValueError(f"staged checksum mismatch for {image['sourcePath']}")
        if contents.get("images") != [
            {"filename": image["canonicalFileName"], "idiom": "universal"}
        ]:
            raise ValueError(f"staged Contents.json mismatch for {image['canonicalMediaKey']}")


def path_entry_exists(path: Path) -> bool:
    return path.exists() or path.is_symlink()


def remove_path_entry(path: Path) -> None:
    if not path_entry_exists(path):
        return
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)
    else:
        path.unlink()


def replace_generated_import(root: Path, staging_assets: Path, staging_index: Path) -> None:
    assets_parent = root / "Health Assistantv2" / "Assets.xcassets"
    generated_parent = root / GENERATED_DIRECTORY
    target_assets = assets_parent / "ExerciseMedia"
    target_index = generated_parent / "media-index.json"
    assets_parent.mkdir(parents=True, exist_ok=True)
    generated_parent.mkdir(parents=True, exist_ok=True)
    token = uuid.uuid4().hex
    assets_backup = assets_parent / f".ExerciseMedia.backup-{token}"
    index_backup = generated_parent / f".media-index.backup-{token}.json"
    assets_backed_up = False
    index_backed_up = False
    assets_installed = False
    index_installed = False
    try:
        if path_entry_exists(target_assets):
            os.replace(target_assets, assets_backup)
            assets_backed_up = True
        if path_entry_exists(target_index):
            os.replace(target_index, index_backup)
            index_backed_up = True
        os.replace(staging_assets, target_assets)
        assets_installed = True
        os.replace(staging_index, target_index)
        index_installed = True
    except OSError:
        if assets_installed:
            remove_path_entry(target_assets)
        if index_installed:
            remove_path_entry(target_index)
        if assets_backed_up and path_entry_exists(assets_backup):
            os.replace(assets_backup, target_assets)
        if index_backed_up and path_entry_exists(index_backup):
            os.replace(index_backup, target_index)
        raise
    else:
        if assets_backed_up:
            remove_path_entry(assets_backup)
        if index_backed_up:
            remove_path_entry(index_backup)


def write_json_file(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def print_report(report: ValidationReport) -> None:
    print(
        "exercise-catalog validation: "
        f"exercises={report.exercise_count} intake_assets={report.intake_asset_count} "
        f"errors={len(report.errors)} warnings={len(report.warnings)}"
    )
    for diagnostic in report.errors + report.warnings:
        print(diagnostic.format())


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    for name in ("validate", "report"):
        command = subcommands.add_parser(name)
        command.add_argument("--root", type=Path, default=repository_root())
        command.add_argument(
            "--source-pack",
            type=Path,
            help="Optional source-pack root used to verify mapped source checksums.",
        )
        command.add_argument("--strict", action="store_true")
    importer = subcommands.add_parser("import")
    importer.add_argument("--root", type=Path, default=repository_root())
    importer.add_argument("--source-pack", type=Path, required=True)
    import_mode = importer.add_mutually_exclusive_group(required=True)
    import_mode.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the deterministic approved-copy plan without writing files.",
    )
    import_mode.add_argument(
        "--apply",
        action="store_true",
        help="Generate only approved imagesets and the media index transactionally.",
    )
    return parser


def main(arguments: Iterable[str] | None = None) -> int:
    parser = build_parser()
    parsed = parser.parse_args(list(arguments) if arguments is not None else None)
    if parsed.command == "import":
        if parsed.apply:
            return run_import_apply(parsed.root, parsed.source_pack)
        return run_import_dry_run(parsed.root, parsed.source_pack)
    report = validate_catalogue(
        parsed.root,
        strict=parsed.strict,
        source_pack=parsed.source_pack,
        require_source_pack=parsed.strict,
    )
    print_report(report)
    if report.errors or (parsed.strict and report.warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
