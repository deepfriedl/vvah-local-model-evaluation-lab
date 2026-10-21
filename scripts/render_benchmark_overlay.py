#!/usr/bin/env python3
"""Render one complete, credential-free VVAH benchmark overlay."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


VARIANTS = ("direct-high", "direct-low", "typed-detection", "typed-full")
MODEL_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")


def replace_role(text: str, role: str, value: str) -> str:
    pattern = re.compile(rf"(?m)^  {re.escape(role)}: .*$")
    updated, count = pattern.subn(f"  {role}: {value}", text, count=1)
    if count != 1:
        raise ValueError(f"Expected exactly one models.{role} line in the base overlay.")
    return updated


def replace_effort(text: str, section: str, effort: str) -> str:
    pattern = re.compile(rf"(?ms)^({re.escape(section)}:\n.*?^  effort: )[A-Za-z]+$")
    updated, count = pattern.subn(rf"\g<1>{effort}", text, count=1)
    if count != 1:
        raise ValueError(f"Expected exactly one {section}.effort line in the base overlay.")
    return updated


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", type=Path, required=True, help="Version-controlled base overlay.")
    parser.add_argument("--model", required=True, help="Ollama model tag to test.")
    parser.add_argument("--variant", choices=VARIANTS, required=True)
    parser.add_argument("--output", type=Path, required=True, help="Rendered full overlay destination.")
    arguments = parser.parse_args()

    if not MODEL_PATTERN.fullmatch(arguments.model):
        parser.error("--model may contain only letters, digits, dot, underscore, colon, and hyphen.")

    text = arguments.base.read_text()
    text = text.replace("qwen3:8b", arguments.model)
    direct = f'{{id: "{arguments.model}", via: openai}}'
    typed = f'{{id: "{arguments.model}", via: deepagents, provider: openai}}'

    for role in ("threatmodel", "deepdive", "verify"):
        text = replace_role(text, role, direct)

    if arguments.variant == "direct-high":
        text = replace_effort(text, "step2", "high")
        text = replace_effort(text, "step4", "high")
    else:
        text = replace_effort(text, "step2", "low")
        text = replace_effort(text, "step4", "low")

    if arguments.variant in {"typed-detection", "typed-full"}:
        for role in ("threatmodel", "deepdive"):
            text = replace_role(text, role, typed)
    if arguments.variant == "typed-full":
        text = replace_role(text, "verify", typed)

    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(text)
    print(f"Rendered {arguments.variant} overlay for {arguments.model}: {arguments.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
