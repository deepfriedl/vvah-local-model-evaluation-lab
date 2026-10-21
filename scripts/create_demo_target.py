#!/usr/bin/env python3
"""Create a deliberately vulnerable, local-only source-code fixture for VVAH."""

from __future__ import annotations

from pathlib import Path
import sys


PROJECT_ROOT = Path(__file__).resolve().parent.parent
TARGET = PROJECT_ROOT / "targets" / "toy-vulnerable-python-api"

APP_SOURCE = '''"""Intentionally vulnerable training code. Do not deploy or run this service."""

import os
import sqlite3
import subprocess

from flask import Flask, jsonify, request, send_file


app = Flask(__name__)
DATABASE_PATH = os.path.join(os.path.dirname(__file__), "training.db")
REPORTS_DIRECTORY = os.path.join(os.path.dirname(__file__), "reports")


def connection() -> sqlite3.Connection:
    return sqlite3.connect(DATABASE_PATH)


@app.get("/search")
def search_users():
    query = request.args.get("query", "")
    sql = f"SELECT id, username FROM users WHERE username LIKE '%{query}%'"
    rows = connection().execute(sql).fetchall()
    return jsonify([{"id": row[0], "username": row[1]} for row in rows])


@app.post("/diagnostics/ping")
def ping_host():
    request_data = request.get_json(force=True)
    host = request_data.get("host", "localhost")
    result = subprocess.run(
        f"ping -c 1 {host}",
        shell=True,
        check=False,
        capture_output=True,
        text=True,
    )
    return jsonify({"output": result.stdout})


@app.get("/reports/<path:report_name>")
def download_report(report_name: str):
    return send_file(os.path.join(REPORTS_DIRECTORY, report_name))
'''

README = """# Toy Vulnerable Python API\n\nThis directory is an intentionally vulnerable source-code fixture for VVAH evaluation.\nIt is generated locally, is ignored by Git, and must not be deployed or exposed to a network.\n\nExpected vulnerability classes:\n\n- SQL injection in `GET /search` (CWE-89)\n- OS command injection in `POST /diagnostics/ping` (CWE-78)\n- Path traversal in `GET /reports/<report_name>` (CWE-22)\n"""

REQUIREMENTS = "Flask>=3,<4\n"


def main() -> int:
    if TARGET.exists():
        print(f"Refusing to overwrite existing target: {TARGET}", file=sys.stderr)
        return 1

    TARGET.mkdir(parents=True)
    (TARGET / "app.py").write_text(APP_SOURCE, encoding="utf-8")
    (TARGET / "README.md").write_text(README, encoding="utf-8")
    (TARGET / "requirements.txt").write_text(REQUIREMENTS, encoding="utf-8")
    (TARGET / "reports").mkdir()
    print(f"Created local training target: {TARGET}")
    print("The fixture is source code only. Do not run or deploy it.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
