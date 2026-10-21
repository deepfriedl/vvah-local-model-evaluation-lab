#!/usr/bin/env bash
set -euo pipefail

LAB_ROOT="${HOME}/vvah-lab"
VVAH_SOURCE_DIR="${LAB_ROOT}/visa-vulnerability-agentic-harness"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required." >&2
  exit 1
fi

python3 - <<'PY'
import sys
if sys.version_info < (3, 11):
    raise SystemExit("Python 3.11 or newer is required.")
PY

mkdir -p "${LAB_ROOT}"

if [ -e "${VVAH_SOURCE_DIR}" ]; then
  echo "Refusing to replace existing directory: ${VVAH_SOURCE_DIR}" >&2
  exit 1
fi

git clone https://github.com/visa/visa-vulnerability-agentic-harness.git "${VVAH_SOURCE_DIR}"
python3 -m venv "${VVAH_SOURCE_DIR}/.venv"
"${VVAH_SOURCE_DIR}/.venv/bin/python" -m pip install --upgrade pip
"${VVAH_SOURCE_DIR}/.venv/bin/pip" install "${VVAH_SOURCE_DIR}"
"${VVAH_SOURCE_DIR}/.venv/bin/vvaharness" setup

echo
echo "VVAH installed in: ${VVAH_SOURCE_DIR}"
echo "No model configuration or source scan has been performed."
