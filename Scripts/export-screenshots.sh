#!/usr/bin/env bash
# Exports screenshot attachments from an .xcresult bundle, named after their
# XCTAttachment names (01-example.png, 02-console-open.png, …).
#
# Usage: Scripts/export-screenshots.sh <path/to/TestResults.xcresult> [output-dir]
set -euo pipefail

XCRESULT="${1:?usage: export-screenshots.sh <path.xcresult> [output-dir]}"
OUT_DIR="${2:-Example/Screenshots}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

xcrun xcresulttool export attachments --path "$XCRESULT" --output-path "$TMP_DIR"

mkdir -p "$OUT_DIR"
python3 - "$TMP_DIR" "$OUT_DIR" <<'PY'
import json
import pathlib
import re
import shutil
import sys

tmp_dir, out_dir = (pathlib.Path(arg) for arg in sys.argv[1:3])
manifest_path = tmp_dir / "manifest.json"
if not manifest_path.exists():
    sys.exit(f"no manifest.json in {tmp_dir} — xcresulttool output format changed?")

# XCTest appends "_<index>_<uuid>" to the XCTAttachment name; strip it back to the
# clean name we set in the test (e.g. "01-example_0_<uuid>.png" -> "01-example.png").
suffix = re.compile(r"_\d+_[0-9A-Fa-f-]{36}(\.[A-Za-z]+)$")

exported = 0
for test in json.loads(manifest_path.read_text()):
    for attachment in test.get("attachments", []):
        exported_name = attachment.get("exportedFileName")
        if not exported_name:
            continue
        source = tmp_dir / exported_name
        if source.suffix.lower() not in {".png", ".jpg", ".jpeg"}:
            continue
        raw = attachment.get("suggestedHumanReadableName") or exported_name
        # Only keep intentionally-named screenshots (skip system attachments).
        if not suffix.search(raw):
            continue
        name = suffix.sub(r"\1", raw)
        destination = out_dir / name
        shutil.copy(source, destination)
        print(f"exported {destination}")
        exported += 1

if exported == 0:
    sys.exit("no screenshot attachments found in the result bundle")
PY
