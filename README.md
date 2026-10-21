# VVAH Local Model Evaluation Lab

This repository is a reproducible, local-only research environment for evaluating
[Visa Vulnerability Agentic Harness (VVAH)](https://github.com/visa/visa-vulnerability-agentic-harness)
with Qwen 3 8B.

The project asks a practical question: can a small, locally served model provide
useful vulnerability-discovery signal when a structured, agentic application-security
pipeline supplies the surrounding workflow?

## Scope and safety

- Scan only repositories and running targets for which you have explicit authorization.
- Initial scans are source-code analysis only, stopping at VVAH step S9. They do not
  remediate code and do not send live exploit-verification traffic.
- Findings are triage candidates. A human must validate each finding before action.
- The VVAH Ollama service binds only to `127.0.0.1:11435`; it is not LAN- or
  internet-accessible.

## Architecture

```text
authorized local source checkout
            |
            v
    VVAH Python environment
            |
            | OpenAI-compatible API, loopback only
            v
Docker: vvah-ollama (Qwen 3 8B)
127.0.0.1:11435/v1/
```

The VVAH model server has its own container and model volume. This keeps model
experiments isolated from other local workloads.

## Phases

1. Start an isolated Qwen endpoint with `deployment/docker-compose.yml`.
2. Run `scripts/probe_model.py` and record API, JSON-schema, and tool-call behavior.
3. Install VVAH from Visa's official repository in an isolated virtual environment.
4. Create a VVAH OpenAI-compatible configuration after the probes pass.
5. Generate a local, intentionally vulnerable training target, then run a
   detection-only assessment against that authorized checkout.
6. Record findings, completion status, timing, and GPU utilization for comparison.

## Current status

- [x] Local deployment design documented.
- [x] Dedicated VVAH Qwen service started.
- [x] Qwen compatibility probes completed.
- [x] VVAH installed and configured.
- [x] First authorized, detection-only scan completed.
- [ ] Diagnose the evidence-enrichment exclusions before treating local-model results as findings.

## Repository layout

- `deployment/docker-compose.yml` — complete, isolated model-server definition.
- `scripts/probe_model.py` — harmless endpoint capability checks.
- `scripts/bootstrap_vvah.sh` — installs VVAH in an isolated virtual environment.
- `scripts/create_demo_target.py` — creates an ignored, source-only training target.
- `scripts/scan_demo_target.sh` — estimates and scans that target through S9 only.
- `scripts/summarize_demo_scan.py` — prints metadata-only artifact diagnostics; it never prints source or report excerpts.
- `scripts/run_model_benchmark.sh` — sequentially probes and evaluates one model through the four Qwen 3 experiment configurations; all logs and generated overlays remain local under `private/benchmarks/`.
- `scripts/render_benchmark_overlay.py` — renders a complete, credential-free overlay for one benchmark variant.
- `config/vvah-ollama-overlay.yaml` — complete, conservative VVAH model overlay.
- `scripts/configure_vvah.sh` — installs the overlay into the local VVAH checkout.
- `scripts/doctor_vvah.sh` — performs VVAH's live, token-spending backend check.
- `docs/` — experiment notes and results, excluding credentials and target-source code.

## Never commit

Do not commit `.env` files, API keys, target repositories, reports containing sensitive
source excerpts, Docker volumes, or local Python environments.
