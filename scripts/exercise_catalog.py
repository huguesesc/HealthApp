#!/usr/bin/env python3
"""Cross-platform validation for the checked-in exercise catalogue source."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, UnidentifiedImageError


CATALOG_SCHEMA_VERSION = 1
AUTHORING_DIRECTORY = Path("Health Assistantv2/ExerciseCatalog/Resources/Authoring")
GENERATED_DIRECTORY = Path("Health Assistantv2/ExerciseCatalog/Resources/Generated")
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
) -> ValidationReport:
    """Validate authoring JSON and any present intake/generated resources without writing."""
    del strict  # Strictness affects the command exit code; checks are always exhaustive.
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
    media_keys = validate_catalog(
        catalog,
        catalog_path,
        root_path,
        equipment_ids,
        capability_ids,
        report,
    )
    if import_map_path.exists():
        validate_import_map(
            load_json(import_map_path, root_path, report),
            import_map_path,
            root_path,
            media_keys,
            Path(source_pack).resolve() if source_pack is not None else None,
            report,
        )
    validate_generated_media(root_path, media_keys, report)
    validate_intake_assets(root_path, media_keys, report)
    report.finalise()
    return report


def load_json(path: Path, root: Path, report: ValidationReport) -> Any | None:
    file = relative_path(root, path)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
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
    return None


def validate_equipment(
    data: Any,
    path: Path,
    root: Path,
    report: ValidationReport,
) -> set[str]:
    file = relative_path(root, path)
    if not isinstance(data, dict):
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
        if parent_id is not None and parent_id not in ids:
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
        for fulfillment_index, fulfillment in enumerate(entry.get("fulfills", [])):
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
            if target not in ids:
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

        default_capabilities = entry.get("defaultCapabilities", [])
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
) -> set[str]:
    file = relative_path(root, path)
    if not isinstance(data, dict):
        return set()
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
        return set()

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
        validate_media(
            exercise.get("media"),
            exercise_id,
            file,
            f"{pointer}/media",
            media_claims,
            report,
        )

        for claim in [exercise.get("displayName")] + list(exercise.get("aliases", [])):
            normalized = normalized_reference(claim)
            if normalized:
                normalized_claims[normalized].add(exercise_id)

        legacy_ids = exercise.get("legacyIDs", [])
        if legacy_ids is None:
            legacy_ids = []
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
            if replacement is not None:
                replacement_edges[exercise_id] = replacement

    for normalized, owners in sorted(normalized_claims.items()):
        if len(owners) > 1:
            report.add_error(
                "E_ALIAS_COLLISION",
                file,
                "/exercises",
                f"{normalized}: {sorted(owners)}",
                "normalized display names and aliases must be unique",
                "Remove or distinguish the ambiguous alias.",
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
    return set(media_claims)


def validate_exercise_fields(
    exercise: dict[str, Any],
    file: str,
    pointer: str,
    report: ValidationReport,
) -> None:
    if exercise.get("schemaVersion") != 1:
        report.add_error(
            "E_EXERCISE_SCHEMA_VERSION",
            file,
            f"{pointer}/schemaVersion",
            exercise.get("schemaVersion"),
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
    if aliases is None:
        aliases = []
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

    lifecycle = exercise.get("lifecycle")
    if not isinstance(lifecycle, dict) or lifecycle.get("status") not in LIFECYCLE_STATUSES:
        status = lifecycle.get("status") if isinstance(lifecycle, dict) else lifecycle
        report.add_error(
            "E_LIFECYCLE_STATUS",
            file,
            f"{pointer}/lifecycle/status",
            status,
            "lifecycle status must be active, deprecated, or disabled",
            "Choose one controlled lifecycle status.",
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
        if equipment_id not in equipment_ids:
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
    for key, values in (("required", required), ("prohibited", prohibited)):
        for index, capability in enumerate(values):
            if capability not in capability_ids:
                report.add_error(
                    "E_CAPABILITY_UNKNOWN",
                    file,
                    f"{pointer}/{key}/{index}",
                    capability,
                    "capability IDs must exist in environments.json",
                    "Add the capability to an approved environment or correct the ID.",
                )
    for capability in sorted(set(required).intersection(prohibited)):
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
    report: ValidationReport,
) -> None:
    if media is None:
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
        if role not in MEDIA_ROLES:
            report.add_error(
                "E_MEDIA_ROLE",
                file,
                f"{item_pointer}/role",
                role,
                "media roles must use the controlled media role vocabulary",
                "Use thumbnail, setup, start, mid, end, alternate, mistake, correct, or composite.",
            )
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
        if lifecycle.get("status") == "disabled":
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
    media_keys: set[str],
    source_pack: Path | None,
    report: ValidationReport,
) -> None:
    file = relative_path(root, path)
    if not isinstance(data, dict):
        return
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
        return

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
        if source_pack_metadata.get("mappedImageCount") != len(images):
            report.add_error(
                "E_IMPORT_SOURCE_COUNT",
                file,
                "/sourcePack/mappedImageCount",
                source_pack_metadata.get("mappedImageCount"),
                "mappedImageCount must equal the number of explicit image rows",
                "Update the count after adding or removing an image decision.",
            )

    claimed_sources: dict[str, str] = {}
    claimed_keys: dict[str, str] = {}
    approved_media_keys: set[str] = set()
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

        if status not in IMPORT_STATUSES:
            report.add_error(
                "E_IMPORT_MAP_STATUS",
                file,
                f"{pointer}/status",
                status,
                "status must be an explicit supported import decision",
                "Use approved_for_import, approved_pending_catalogue_entry, "
                "unreviewed, or quarantined.",
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
        if role not in MEDIA_ROLES:
            report.add_error(
                "E_IMPORT_ROLE",
                file,
                f"{pointer}/role",
                role,
                "role must use the controlled media role vocabulary",
                "Use a supported role such as composite or setup.",
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

        if status == "approved_for_import" and media_key not in media_keys:
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

        if source_pack is not None and safe_source_relative_path(source_path):
            source_file = (source_pack / source_path).resolve()
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
            elif isinstance(source_checksum, str) and SHA256_PATTERN.fullmatch(source_checksum):
                if sha256(source_file) != source_checksum:
                    report.add_error(
                        "E_IMPORT_SOURCE_CHECKSUM",
                        file,
                        f"{pointer}/sourceSHA256",
                        source_checksum,
                        "the source image checksum must match the approved mapping record",
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
            expected_sources = {
                relative_path(source_pack, source_file)
                for source_file in mapped_root.rglob("*")
                if source_file.is_file() and source_file.suffix.lower() == ".png"
            }
            for unmapped_source in sorted(expected_sources - set(claimed_sources)):
                report.add_error(
                    "E_IMPORT_SOURCE_UNMAPPED",
                    file,
                    "/images",
                    unmapped_source,
                    "every source image in mappedDirectory requires an explicit mapping status",
                    "Add an approved, pending, unreviewed, or quarantined image row.",
                )

    for unmapped_media_key in sorted(media_keys - approved_media_keys):
        report.add_error(
            "E_IMPORT_MAP_MANIFEST_MEDIA_UNMAPPED",
            file,
            "/images",
            unmapped_media_key,
            "every current manifest media key requires an approved import row",
            "Add an approved_for_import row with a reviewed source checksum.",
        )


def validate_generated_media(root: Path, media_keys: set[str], report: ValidationReport) -> None:
    index_path = root / GENERATED_DIRECTORY / "media-index.json"
    if not index_path.exists():
        return
    data = load_json(index_path, root, report)
    if not isinstance(data, dict):
        return
    file = relative_path(root, index_path)
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
    indexed_keys: set[str] = set()
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
        if not isinstance(key, str) or not isinstance(asset_name, str):
            report.add_error(
                "E_MEDIA_INDEX_FIELDS",
                file,
                pointer,
                entry,
                "media index entries need string key and assetName fields",
                "Regenerate the media index with complete mapping fields.",
            )
            continue
        indexed_keys.add(key)
        image_set = root / "Health Assistantv2" / "Assets.xcassets" / "ExerciseMedia"
        image_set = image_set / f"{asset_name}.imageset"
        if not image_set.is_dir():
            report.add_error(
                "E_MEDIA_ASSET_MISSING",
                file,
                pointer,
                asset_name,
                "media index entries must resolve to generated imagesets",
                "Run the approved importer or correct assetName.",
            )
    for key in sorted(media_keys - indexed_keys):
        report.add_error(
            "E_MEDIA_INDEX_MISSING",
            file,
            "/media",
            key,
            "every manifest media key must exist in the generated media index",
            "Run the importer after approving an import-map entry.",
        )
    for key in sorted(indexed_keys - media_keys):
        report.add_error(
            "E_MEDIA_INDEX_ORPHAN",
            file,
            "/media",
            key,
            "generated media keys must be referenced by the manifest",
            "Remove the orphan via the importer or add an approved manifest reference.",
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
        validate_png(path, root, report)
        checksum = sha256(path)
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


def validate_png(path: Path, root: Path, report: ValidationReport) -> None:
    file = relative_path(root, path)
    try:
        with Image.open(path) as image:
            image.verify()
        with Image.open(path) as image:
            width, height = image.size
            mode = image.mode
    except (OSError, UnidentifiedImageError) as error:
        report.add_error(
            "E_PNG_INVALID",
            file,
            "",
            str(error),
            "intake files with a .png extension must be valid PNG images",
            "Replace the corrupted file with a valid PNG source.",
        )
        return
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


def validate_schema_version(
    value: Any,
    file: str,
    pointer: str,
    report: ValidationReport,
    key_name: str = "schemaVersion",
) -> None:
    if value != CATALOG_SCHEMA_VERSION:
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


def valid_asset_name(name: Any) -> bool:
    if not isinstance(name, str) or not name.endswith(".png") or name != name.lower():
        return False
    if ".." in name or " " in name or "'" in name or "dumbell" in name:
        return False
    stem = name[:-4]
    return MEDIA_KEY_PATTERN.fullmatch(stem) is not None


def safe_source_relative_path(value: Any) -> bool:
    if not isinstance(value, str) or not value or "\\" in value or value.startswith("/"):
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
    return parser


def main(arguments: Iterable[str] | None = None) -> int:
    parser = build_parser()
    parsed = parser.parse_args(list(arguments) if arguments is not None else None)
    report = validate_catalogue(
        parsed.root,
        strict=parsed.strict,
        source_pack=parsed.source_pack,
    )
    print_report(report)
    if report.errors or (parsed.strict and report.warnings):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
