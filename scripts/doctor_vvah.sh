#!/usr/bin/env bash
set -euo pipefail

VVAH_SOURCE_DIR="${HOME}/vvah-lab/visa-vulnerability-agentic-harness"
VVAH_COMMAND="${VVAH_SOURCE_DIR}/.venv/bin/vvaharness"
VVAH_CONFIG="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/default.yaml"

if [ ! -x "${VVAH_COMMAND}" ]; then
  echo "VVAH is not installed. Run ./scripts/bootstrap_vvah.sh first." >&2
  exit 1
fi

if [ ! -f "${VVAH_SOURCE_DIR}/vvaharness/config/profiles/config.local.yaml" ]; then
  echo "VVAH overlay is not installed. Run ./scripts/configure_vvah.sh first." >&2
  exit 1
fi

# Ollama requires a non-empty OpenAI-compatible API key value but ignores it.
# These values are exported only to this process; no .env file is created.
export OPENAI_API_KEY="ollama"
export OPENAI_BASE_URL="http://127.0.0.1:11435/v1"

exec "${VVAH_COMMAND}" doctor --config "${VVAH_CONFIG}"
