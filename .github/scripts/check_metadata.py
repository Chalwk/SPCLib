#!/usr/bin/env python3
"""Verify that metadata.json and the script files on disk agree.

Layout the Script Browser expects:
    SAPP     -> sapp/<category>/<name>.lua
    PHASOR   -> phasor/<category>/<name>.lua
    CHIMERA  -> chimera/global/<name>.lua
    RELEASES -> GitHub release tags (not files; only the JSON shape is checked)

Errors (fail the build):
    - metadata.json is invalid JSON, has duplicate keys, or has the wrong shape
    - an entry has no matching .lua file
    - a .lua file has no matching entry
    - an entry has an empty description
    - a category folder with .lua files exists that metadata.json does not list
Warnings (do not fail):
    - an unknown top-level key in metadata.json
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
METADATA = ROOT / "metadata.json"

CATEGORY_PLATFORMS = {"SAPP": "sapp", "PHASOR": "phasor"}  # key -> folder
FLAT_PLATFORMS = {"CHIMERA": "chimera/global"}  # key -> folder
JSON_ONLY = {"RELEASES"}  # no files to check
KNOWN_KEYS = set(CATEGORY_PLATFORMS) | set(FLAT_PLATFORMS) | JSON_ONLY

errors, warnings = [], []


def error(msg, file="metadata.json"):
    errors.append(msg)
    print(f"::error file={file}::{msg}")


def warn(msg, file="metadata.json"):
    warnings.append(msg)
    print(f"::warning file={file}::{msg}")


def no_duplicate_keys(pairs):
    seen = {}
    for k, v in pairs:
        if k in seen:
            error(f"Duplicate key {k!r} in metadata.json (the later one silently wins)")
        seen[k] = v
    return seen


def lua_stems(folder: Path):
    """Names of .lua files directly inside folder (no extension)."""
    if not folder.is_dir():
        return None
    return {p.stem for p in folder.glob("*.lua")}


def compare(label, entries, folder_rel, descriptions_ok=True):
    """entries: dict name -> description. Compare against folder_rel on disk."""
    folder = ROOT / folder_rel
    on_disk = lua_stems(folder)
    if on_disk is None:
        if entries:
            error(
                f"{label}: folder '{folder_rel}/' does not exist but metadata lists "
                f"{len(entries)} script(s)"
            )
        return
    listed = set(entries)
    for name in sorted(listed - on_disk):
        error(
            f"{label}: '{name}' is in metadata.json but {folder_rel}/{name}.lua does not exist"
        )
    for name in sorted(on_disk - listed):
        error(
            f"{label}: {folder_rel}/{name}.lua exists but has no entry in metadata.json",
            file=f"{folder_rel}/{name}.lua",
        )
    if descriptions_ok:
        for name, desc in entries.items():
            if not isinstance(desc, str) or not desc.strip():
                error(f"{label}: '{name}' needs a non-empty string description")


def main():
    if not METADATA.is_file():
        error("metadata.json not found at repo root")
        return 1
    try:
        with METADATA.open(encoding="utf-8") as fh:
            meta = json.load(fh, object_pairs_hook=no_duplicate_keys)
    except json.JSONDecodeError as exc:
        error(f"metadata.json is not valid JSON: {exc}")
        return 1

    if not isinstance(meta, dict):
        error("metadata.json top level must be an object")
        return 1

    for key in meta:
        if key not in KNOWN_KEYS:
            warn(f"Unknown top-level key {key!r} is ignored by the Script Browser")

    # Platforms with categories: SAPP, PHASOR
    for key, folder in CATEGORY_PLATFORMS.items():
        cats = meta.get(key)
        if cats is None:
            error(f"Missing top-level key {key!r}")
            continue
        if not isinstance(cats, dict) or not all(
            isinstance(v, dict) for v in cats.values()
        ):
            error(f"{key} must be an object of {{category: {{script: description}}}}")
            continue
        for cat, entries in cats.items():
            compare(f"{key}/{cat}", entries, f"{folder}/{cat}")
        base = ROOT / folder
        if base.is_dir():
            for sub in sorted(p.name for p in base.iterdir() if p.is_dir()):
                if sub not in cats and list((base / sub).glob("*.lua")):
                    error(
                        f"{key}: folder {folder}/{sub}/ has .lua files but no "
                        f"'{sub}' category in metadata.json"
                    )

    # Flat platforms: CHIMERA
    for key, folder in FLAT_PLATFORMS.items():
        entries = meta.get(key)
        if entries is None:
            error(f"Missing top-level key {key!r}")
            continue
        if not isinstance(entries, dict):
            error(f"{key} must be an object of {{script: description}}")
            continue
        compare(key, entries, folder)

    # Releases: shape only
    rel = meta.get("RELEASES")
    if rel is None:
        error("Missing top-level key 'RELEASES'")
    elif not isinstance(rel, dict):
        error("RELEASES must be an object of {name: description}")
    else:
        for name, desc in rel.items():
            if not isinstance(desc, str) or not desc.strip():
                error(f"RELEASES: '{name}' needs a non-empty string description")

    total = sum(
        len(e)
        for k, v in meta.items()
        if isinstance(v, dict)
        for e in ([v] if k not in CATEGORY_PLATFORMS else v.values())
        if isinstance(e, dict)
    )
    print(
        f"\nChecked {total} entries: {len(errors)} error(s), {len(warnings)} warning(s)"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
