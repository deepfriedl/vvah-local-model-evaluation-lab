#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${PROJECT_ROOT}/targets/toy-vulnerable-python-api"
VVAH_SOURCE_DIR="${HOME}/vvah-lab/visa-vulnerability-agentic-harness"
VVAH_COMMAND="${VVAH_SOURCE_DIR}/.venv/bin/vvaharness"
VVAH_CONFIG="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/default.yaml"
VVAH_OVERLAY="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/config.local.yaml"

if [ ! -x "${VVAH_COMMAND}" ]; then
  echo "VVAH is not installed. Run ./scripts/bootstrap_vvah.sh first." >&2
  exit 1
fi

if [ ! -f "${VVAH_OVERLAY}" ]; then
  echo "VVAH overlay is not installed. Run ./scripts/configure_vvah.sh first." >&2
  exit 1
fi

if [ ! -f "${TARGET_DIR}/app.py" ]; then
  echo "Demo target is absent. Run ./scripts/create_demo_target.py first." >&2
  exit 1
fi

# Ollama requires a non-empty OpenAI-compatible API key value but ignores it.
# These values are exported only to this process; no .env file is created.
export OPENAI_API_KEY="ollama"
export OPENAI_BASE_URL="http://127.0.0.1:11435/v1"

echo "Estimating local demo target scope (no model request):"
"${VVAH_COMMAND}" estimate --repo "${TARGET_DIR}" --config "${VVAH_CONFIG}"

echo
echo "Running detection and reporting only (S0-S9):"
set +e
"${VVAH_COMMAND}" scan \
  --repo "${TARGET_DIR}" \
  --config "${VVAH_CONFIG}" \
  --stop-after s9 \
  --no-auto-step1
SCAN_EXIT_CODE=$?
set -e

echo
echo "Metadata-only scan diagnostics:"
"${PROJECT_ROOT}/scripts/summarize_demo_scan.py" --scan-dir "${TARGET_DIR}/security-scan" || true

exit "${SCAN_EXIT_CODE}"
