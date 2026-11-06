#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL=""
RUN_DIR=""
PROFILE="direct-low"
VVAH_SOURCE_DIR="${HOME}/vvah-lab/visa-vulnerability-agentic-harness"
VVAH_COMMAND="${VVAH_SOURCE_DIR}/.venv/bin/vvaharness"
VVAH_CONFIG="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/default.yaml"
VVAH_OVERLAY="${VVAH_SOURCE_DIR}/vvaharness/config/profiles/config.local.yaml"
BASE_OVERLAY="${PROJECT_ROOT}/config/vvah-ollama-overlay.yaml"
TARGET_DIR="${PROJECT_ROOT}/targets/toy-vulnerable-python-api"
BACKUP_OVERLAY=""
RESTORE_MODE=""

usage() {
  echo "Usage: VVAH_REMOTE_OPENAI_BASE_URL=https://endpoint/v1 $0 --model MODEL [--profile direct-low|direct-medium|typed-all] [--run-dir DIRECTORY]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)
      MODEL="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
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

if [ -z "${MODEL}" ] || [ -z "${VVAH_REMOTE_OPENAI_BASE_URL:-}" ]; then
  usage
  exit 2
fi

if [[ ! "${MODEL}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
  echo "Invalid model identifier." >&2
  exit 2
fi

if [[ ! "${VVAH_REMOTE_OPENAI_BASE_URL}" =~ ^https?://[^[:space:]]+/v1/?$ ]]; then
  echo "VVAH_REMOTE_OPENAI_BASE_URL must be an HTTP(S) OpenAI-compatible /v1 URL." >&2
  exit 2
fi

case "${PROFILE}" in
  direct-low|direct-medium|typed-all)
    ;;
  *)
    echo "Invalid profile. Choose direct-low, direct-medium, or typed-all." >&2
    exit 2
    ;;
esac

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
  RUN_DIR="${PROJECT_ROOT}/private/remote-benchmarks/${SAFE_MODEL}-$(date -u +%Y%m%dT%H%M%SZ)"
fi

mkdir -p "${RUN_DIR}"
echo "Remote benchmark artifacts: ${RUN_DIR}"

cleanup() {
  if [ "${RESTORE_MODE}" = "restore" ] && [ -n "${BACKUP_OVERLAY}" ] && [ -f "${BACKUP_OVERLAY}" ]; then
    install -m 600 "${BACKUP_OVERLAY}" "${VVAH_OVERLAY}"
  elif [ "${RESTORE_MODE}" = "remove" ]; then
    rm -f "${VVAH_OVERLAY}"
  fi
  if [ -n "${BACKUP_OVERLAY}" ]; then
    rm -f "${BACKUP_OVERLAY}"
  fi
  BACKUP_OVERLAY=""
  RESTORE_MODE=""
}

interrupted() {
  local signal_name="$1"
  local exit_code="$2"
  printf 'signal=%s\ninterrupted_utc=%s\n' "${signal_name}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${RUN_DIR}/interrupted.txt"
  cleanup
  trap - EXIT HUP INT TERM
  exit "${exit_code}"
}

trap cleanup EXIT
trap 'interrupted HUP 129' HUP
trap 'interrupted INT 130' INT
trap 'interrupted TERM 143' TERM

BACKUP_OVERLAY="$(mktemp)"
if [ -f "${VVAH_OVERLAY}" ]; then
  cp "${VVAH_OVERLAY}" "${BACKUP_OVERLAY}"
  RESTORE_MODE="restore"
else
  RESTORE_MODE="remove"
fi

# This placeholder supports clients that require a non-empty OpenAI API key.
# It is never written to disk.
export OPENAI_API_KEY="${VVAH_REMOTE_OPENAI_API_KEY:-unused}"
export OPENAI_BASE_URL="${VVAH_REMOTE_OPENAI_BASE_URL%/}"

printf 'model=%s\nprofile=%s\nstarted_utc=%s\n' "${MODEL}" "${PROFILE}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${RUN_DIR}/run-metadata.txt"

echo "Running minimal model-listing and generation preflight..."
if ! python3 "${PROJECT_ROOT}/scripts/probe_model.py" \
  --model "${MODEL}" \
  --base-url "${OPENAI_BASE_URL}" \
  --mode minimal | tee "${RUN_DIR}/probe-minimal.log"; then
  echo "Minimal generation preflight failed. No VVAH scan was started; the prior overlay is being restored." >&2
  exit 1
fi

echo "Recording the source-only scope estimate (no model request)..."
"${VVAH_COMMAND}" estimate --repo "${TARGET_DIR}" --config "${VVAH_CONFIG}" > "${RUN_DIR}/scope-estimate.log" 2>&1

VARIANT_DIR="${RUN_DIR}/${PROFILE}"
mkdir -p "${VARIANT_DIR}"
python3 "${PROJECT_ROOT}/scripts/render_benchmark_overlay.py" \
  --base "${BASE_OVERLAY}" \
  --model "${MODEL}" \
  --variant "${PROFILE}" \
  --output "${VARIANT_DIR}/config.local.yaml"
install -m 600 "${VARIANT_DIR}/config.local.yaml" "${VVAH_OVERLAY}"

echo "Running ${PROFILE} (detection-only S0-S9)..."
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
  echo "${PROFILE} exited ${SCAN_EXIT_CODE}. The prior overlay is being restored." >&2
  exit "${SCAN_EXIT_CODE}"
fi

echo "Remote benchmark complete. Local-only artifacts: ${RUN_DIR}"
