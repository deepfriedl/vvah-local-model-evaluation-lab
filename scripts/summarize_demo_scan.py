#!/usr/bin/env python3
"""Print metadata-only diagnostics for a local VVAH demo scan.

This deliberately avoids printing source code, prompts, finding descriptions, or
report excerpts. It is safe to paste into an experiment log or issue tracker.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


SAFE_FIELDS = {
    "stage",
    "outcome",
    "status",
    "error_code",
    "severity",
    "cwe",
    "cwe_id",
    "rule_id",
}
RUN_TIMESTAMP = re.compile(r"_(\d{8}T\d{6}Z)_")


def iter_records(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from iter_records(child)
    elif isinstance(value, list):
        for child in value:
            yield from iter_records(child)


def load_records(path: Path) -> tuple[list[Any], str | None]:
    try:
        if path.suffix == ".jsonl":
            return [json.loads(line) for line in path.read_text().splitlines() if line.strip()], None
        return [json.loads(path.read_text())], None
    except (OSError, json.JSONDecodeError) as error:
        return [], type(error).__name__


def run_label(path: Path) -> str:
    match = RUN_TIMESTAMP.search(path.name)
    return match.group(1) if match else "current-unversioned"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scan-dir",
        type=Path,
        default=Path("targets/toy-vulnerable-python-api/security-scan"),
        help="VVAH report directory (default: local demo target report directory).",
    )
    arguments = parser.parse_args()
    scan_dir = arguments.scan_dir.resolve()

    if not scan_dir.is_dir():
        print(f"No scan artifact directory found: {scan_dir}")
        return 1

    artifact_paths = sorted(
        path for path in scan_dir.rglob("*") if path.is_file() and path.suffix in {".json", ".jsonl", ".sarif", ".md"}
    )
    json_paths = [path for path in artifact_paths if path.suffix in {".json", ".jsonl", ".sarif"}]
    counters_by_run: dict[str, dict[str, Counter[str]]] = {}
    malformed_by_run: dict[str, list[str]] = {}

    for path in json_paths:
        label = run_label(path)
        counters = counters_by_run.setdefault(label, {field: Counter() for field in SAFE_FIELDS})
        records, error = load_records(path)
        if error:
            malformed_by_run.setdefault(label, []).append(path.name)
            continue
        for record in records:
            for mapping in iter_records(record):
                for field in SAFE_FIELDS:
                    value = mapping.get(field)
                    if isinstance(value, (str, int, float, bool)):
                        counters[field][str(value)] += 1

    print(f"Scan diagnostics: {scan_dir}")
    print(f"Artifacts: {len(artifact_paths)} total; {len(json_paths)} structured-data file(s)")
    for label in sorted(counters_by_run):
        print(f"Run {label}:")
        for field in sorted(SAFE_FIELDS):
            if counters_by_run[label][field]:
                values = ", ".join(f"{value}={count}" for value, count in sorted(counters_by_run[label][field].items()))
                print(f"  {field}: {values}")
        if malformed_by_run.get(label):
            print(f"  Unreadable structured artifacts: {', '.join(sorted(malformed_by_run[label]))}")
    print("No source, prompt, finding-description, or report-excerpt content was printed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
