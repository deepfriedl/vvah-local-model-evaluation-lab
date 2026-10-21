#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VVAH_SOURCE_DIR="${HOME}/vvah-lab/visa-vulnerability-agentic-harness"
SOURCE_OVERLAY="${PROJECT_ROOT}/config/vvah-ollama-overlay.yaml"
DESTINATION_OVERLAY="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/config.local.yaml"

if [ ! -x "${VVAH_SOURCE_DIR}/.venv/bin/vvaharness" ]; then
  echo "VVAH is not installed. Run ./scripts/bootstrap_vvah.sh first." >&2
  exit 1
fi

install -m 600 "${SOURCE_OVERLAY}" "${DESTINATION_OVERLAY}"

echo "Installed VVAH Qwen/Ollama overlay: ${DESTINATION_OVERLAY}"
echo "The overlay keeps remediation, validation, and exploit verification disabled."
