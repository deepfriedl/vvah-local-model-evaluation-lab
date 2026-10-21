#!/usr/bin/env python3
"""Run harmless OpenAI-compatible API probes against the isolated VVAH model."""

from __future__ import annotations

import json
import argparse
import sys
import urllib.error
import urllib.request


DEFAULT_BASE_URL = "http://127.0.0.1:11435/v1"


def request(base_url: str, path: str, payload: dict | None = None) -> dict:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"} if body else {}
    req = urllib.request.Request(f"{base_url}{path}", data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=180) as response:
        return json.load(response)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default="qwen3:8b", help="Installed Ollama model to probe.")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="OpenAI-compatible endpoint URL.")
    arguments = parser.parse_args()
    model = arguments.model
    base_url = arguments.base_url.rstrip("/")
    checks: list[tuple[str, bool, str]] = []

    try:
        models = request(base_url, "/models")
        names = {item.get("id") for item in models.get("data", [])}
        checks.append(("model listing", model in names, f"model present: {model in names}"))

        simple = request(
            base_url,
            "/chat/completions",
            {
                "model": model,
                "messages": [{"role": "user", "content": "Reply with exactly: ready"}],
                "reasoning_effort": "none",
                "temperature": 0,
                "max_tokens": 16,
            },
        )
        text = simple["choices"][0]["message"].get("content", "").strip().lower()
        checks.append(("chat completion", text == "ready", f"response: {text!r}"))

        structured = request(
            base_url,
            "/chat/completions",
            {
                "model": model,
                "messages": [
                    {
                        "role": "user",
                        "content": "Return an object containing only the boolean field ready set to true.",
                    }
                ],
                "reasoning_effort": "none",
                "temperature": 0,
                "max_tokens": 32,
                "response_format": {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "readiness",
                        "strict": True,
                        "schema": {
                            "type": "object",
                            "properties": {"ready": {"type": "boolean"}},
                            "required": ["ready"],
                            "additionalProperties": False,
                        },
                    },
                },
            },
        )
        structured_text = structured["choices"][0]["message"].get("content", "")
        parsed = json.loads(structured_text)
        checks.append(("structured JSON", parsed == {"ready": True}, f"response: {parsed!r}"))

        tools = [
            {
                "type": "function",
                "function": {
                    "name": "add_numbers",
                    "description": "Add two integer values.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "a": {"type": "integer"},
                            "b": {"type": "integer"},
                        },
                        "required": ["a", "b"],
                    },
                },
            }
        ]
        tool_result = request(
            base_url,
            "/chat/completions",
            {
                "model": model,
                "messages": [
                    {"role": "user", "content": "Use add_numbers to calculate 2 plus 3."}
                ],
                "tools": tools,
                "tool_choice": "required",
                "reasoning_effort": "none",
                "temperature": 0,
                "max_tokens": 64,
            },
        )
        calls = tool_result["choices"][0]["message"].get("tool_calls", [])
        valid_call = len(calls) == 1 and calls[0].get("function", {}).get("name") == "add_numbers"
        checks.append(("tool call", valid_call, f"tool calls: {calls!r}"))
    except (KeyError, TypeError, ValueError, urllib.error.URLError) as exc:
        checks.append(("request execution", False, f"{type(exc).__name__}: {exc}"))

    for name, passed, detail in checks:
        print(f"{'PASS' if passed else 'FAIL'}: {name} — {detail}")

    return 0 if checks and all(passed for _, passed, _ in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
