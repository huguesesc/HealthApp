from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PERSISTENCE = ROOT / "Sources" / "Persistence" / "PersistenceController.swift"

forbidden_tokens = [
    "groupContainer",
    "AppGroup.identifier",
    "forSecurityApplicationGroupIdentifier",
]

source = PERSISTENCE.read_text(encoding="utf-8")
found = [token for token in forbidden_tokens if token in source]

if found:
    joined = ", ".join(found)
    raise SystemExit(
        f"{PERSISTENCE} is not M1 simulator-safe; forbidden token(s): {joined}"
    )

print("M1 simulator persistence check passed")
