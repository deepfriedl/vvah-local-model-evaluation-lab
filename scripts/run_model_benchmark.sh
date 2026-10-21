#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL=""
RUN_DIR=""
VVAH_SOURCE_DIR="${HOME}/vvah-lab/visa-vulnerability-agentic-harness"
VVAH_COMMAND="${VVAH_SOURCE_DIR}/.venv/bin/vvaharness"
VVAH_CONFIG="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/default.yaml"
VVAH_OVERLAY="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/config.local.yaml"
BASE_OVERLAY="${PROJECT_ROOT}/config/vvah-ollama-overlay.yaml"
TARGET_DIR="${PROJECT_ROOT}/targets/toy-vulnerable-python-api"
VARIANTS=(direct-high direct-low typed-detection typed-full)
BACKUP_OVERLAY=""
RESTORE_MODE=""

usage() {
  echo "Usage: $0 --model MODEL [--run-dir DIRECTORY]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --run-dir)
      RUN_DIR="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ -z "${MODEL}" ]; then
  usage
  exit 2
fi

if [[ ! "${MODEL}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
  echo "Invalid model tag. Use only letters, digits, dot, underscore, colon, and hyphen." >&2
  exit 2
fi

if [ ! -x "${VVAH_COMMAND}" ]; then
  echo "VVAH is not installed. Run ./scripts/bootstrap_vvah.sh first." >&2
  exit 1
fi

if [ ! -f "${TARGET_DIR}/app.py" ]; then
  echo "Demo target is absent. Run ./scripts/create_demo_target.py first." >&2
  exit 1
fi

if [ -z "${RUN_DIR}" ]; then
  SAFE_MODEL="${MODEL//[:.]/-}"
  RUN_DIR="${PROJECT_ROOT}/private/benchmarks/${SAFE_MODEL}-$(date -u +%Y%m%dT%H%M%SZ)"
fi

mkdir -p "${RUN_DIR}"

cleanup() {
  if [ "${RESTORE_MODE}" = "restore" ]; then
    install -m 600 "${BACKUP_OVERLAY}" "${VVAH_OVERLAY}"
  elif [ "${RESTORE_MODE}" = "remove" ]; then
    rm -f "${VVAH_OVERLAY}"
  fi
  if [ -n "${BACKUP_OVERLAY}" ]; then
    rm -f "${BACKUP_OVERLAY}"
  fi
}
trap cleanup EXIT INT TERM

BACKUP_OVERLAY="$(mktemp)"
if [ -f "${VVAH_OVERLAY}" ]; then
  cp "${VVAH_OVERLAY}" "${BACKUP_OVERLAY}"
  RESTORE_MODE="restore"
else
  RESTORE_MODE="remove"
fi

# Ollama requires a non-empty API key value but ignores its contents. These values
# exist only in this benchmark process; no .env file is written.
export OPENAI_API_KEY="ollama"
export OPENAI_BASE_URL="http://127.0.0.1:11435/v1"

printf 'model=%s\nstarted_utc=%s\n' "${MODEL}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${RUN_DIR}/run-metadata.txt"

echo "Pulling ${MODEL} into the isolated VVAH Ollama container..."
docker exec vvah-ollama ollama pull "${MODEL}"

echo "Running harmless compatibility probes..."
if ! python3 "${PROJECT_ROOT}/scripts/probe_model.py" --model "${MODEL}" | tee "${RUN_DIR}/probe.log"; then
  echo "Probe failed. No VVAH scans were started." >&2
  exit 1
fi

echo "Recording the source-only scope estimate (no model request)..."
"${VVAH_COMMAND}" estimate --repo "${TARGET_DIR}" --config "${VVAH_CONFIG}" > "${RUN_DIR}/scope-estimate.log" 2>&1

for variant in "${VARIANTS[@]}"; do
  VARIANT_DIR="${RUN_DIR}/${variant}"
  COMPLETE_MARKER="${VARIANT_DIR}/complete"
  mkdir -p "${VARIANT_DIR}"

  if [ -f "${COMPLETE_MARKER}" ]; then
    echo "Skipping completed variant: ${variant}"
    continue
  fi

  python3 "${PROJECT_ROOT}/scripts/render_benchmark_overlay.py" \
    --base "${BASE_OVERLAY}" \
    --model "${MODEL}" \
    --variant "${variant}" \
    --output "${VARIANT_DIR}/config.local.yaml"
  install -m 600 "${VARIANT_DIR}/config.local.yaml" "${VVAH_OVERLAY}"

  echo "Running ${variant} (detection-only S0-S9)..."
  set +e
  "${VVAH_COMMAND}" scan \
    --repo "${TARGET_DIR}" \
    --config "${VVAH_CONFIG}" \
    --stop-after s9 \
    --no-auto-step1 2>&1 | tee "${VARIANT_DIR}/scan.log"
  SCAN_EXIT_CODE="${PIPESTATUS[0]}"
  set -e

  printf 'exit_code=%s\nfinished_utc=%s\n' "${SCAN_EXIT_CODE}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${VARIANT_DIR}/status.txt"
  if [ "${SCAN_EXIT_CODE}" -ne 0 ]; then
    echo "${variant} exited ${SCAN_EXIT_CODE}; stopping the batch. Re-run with --run-dir to retry it." >&2
    exit "${SCAN_EXIT_CODE}"
  fi
  : > "${COMPLETE_MARKER}"
done

echo "Benchmark complete. Local-only artifacts: ${RUN_DIR}"
