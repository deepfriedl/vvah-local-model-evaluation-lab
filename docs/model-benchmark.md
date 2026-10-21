# Local Model Benchmark

Run one model at a time through the same four VVAH configurations used in the
initial Qwen 3 evaluation. The benchmark is intentionally sequential: the RTX
3050 has 8 GB of VRAM, so concurrent scans or loaded models would invalidate the
comparison and risk memory pressure.

## Safety boundary

- The benchmark scans only the locally generated training fixture.
- Every scan stops after S9 and disables AI auto-exclusion.
- Remediation, remediation validation, and live exploit verification remain
  disabled in every rendered overlay.
- The runner backs up and restores the active VVAH `config.local.yaml` overlay,
  including after interruption.
- All generated overlays, logs, status files, and summaries go beneath
  `private/benchmarks/`, which Git ignores. Do not commit them.

## Run a model

```bash
./scripts/run_model_benchmark.sh --model qwen2.5-coder:7b-instruct
```

The runner pulls the requested model into the dedicated VVAH Ollama container,
runs the harmless API/JSON/tool-call probes, and stops before scanning if a probe
fails. It then executes these variants in order:

1. `direct-high` — direct OpenAI-compatible route with high effort.
2. `direct-low` — direct route with low effort.
3. `typed-detection` — DeepAgents route for threat-modeling and deep-dive; direct verification.
4. `typed-full` — DeepAgents route for threat-modeling, deep-dive, and verification.

## Models without Ollama thinking support

Some tool-capable models reject VVAH's direct OpenAI-compatible reasoning setting
before a scan begins. Do not describe their results as like-for-like with the four
standard variants. Instead, use the explicitly labeled compatibility profile:

```bash
./scripts/run_model_benchmark.sh --model hermes3:8b --profile typed-all
```

It runs only `typed-all`: every active detection role uses the OpenAI-compatible
DeepAgents route, which omits the unsupported direct-route reasoning parameter.
It remains detection-only and uses the same local target and safety boundaries.

Each completed variant creates a local `complete` marker. To resume an interrupted
batch, copy the actual directory shown in the opening `Benchmark artifacts:` line;
the path below is an illustration only and must be replaced:

```bash
./scripts/run_model_benchmark.sh --model qwen2.5-coder:7b-instruct --run-dir /absolute/path/printed/by/the/script
```

The model weights are kept in the isolated VVAH Ollama volume. They are not
committed or published.
