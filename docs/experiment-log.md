# Experiment Log

## Decision record

Use a dedicated VVAH Ollama container and volume, publishing only
`127.0.0.1:11435`. VVAH will use its OpenAI-compatible API endpoint. The project
does not depend on, name, or modify unrelated services or workloads.

The first VVAH configuration uses the direct OpenAI-compatible route to the
loopback-only Ollama endpoint. It limits agentic work to one model session at a
time and keeps remediation, remediation validation, and live exploit verification
disabled. No credentials are stored in files: the required non-empty Ollama API-key
placeholder and endpoint are exported only for the VVAH process.

## Next measurement

Start the dedicated model container, download `qwen3:8b`, and run the three harmless
capability probes: model listing, structured JSON output, and tool calling.

## Baseline 1 — high-effort agentic scan

The first detection-only scan completed through S9 against the local training
fixture. The deep-dive stage produced six candidates, but the deterministic
evidence-enrichment gate rejected every candidate; the final SARIF contained zero
results. Metadata-only diagnostics recorded three `VVAH-E003` degenerate-response
events in S2/S4. The gate remains enabled: zero accepted findings is the correct
outcome when the model does not provide valid, re-anchorable evidence.

## Experiment 2 — reduced reasoning effort

The next run keeps the target, model, endpoint, stages, and safety limits unchanged.
It changes only `step2.effort` and `step4.effort` from their VVAH default of `high`
to `low`. This tests whether Qwen 3 8B produces more usable structured evidence
when it spends fewer tokens on native reasoning. Compare accepted findings, S5
exclusions, `VVAH-E003` count, runtime, and GPU utilization with Baseline 1.

Result: the threat model completed without a hollow-retry and produced three
grounded threats. Deep-dive time fell from about 419 seconds to 296 seconds, and
only one new degenerate-response event occurred. However, all five candidate
findings still failed deterministic evidence enrichment. Reduced effort improves
stability and runtime, but does not make the direct OpenAI-compatible route
sufficiently structured for accepted findings.

## Experiment 3 — schema-typed agentic route

Keep the reduced-effort settings and use VVAH's `deepagents` route, resolved to
the existing OpenAI-compatible endpoint, for only the threat-model and deep-dive
roles. This route gives those agentic roles VVAH's schema-typed tool path instead
of direct OpenAI-compatible structured output. The endpoint, Qwen model, target,
single-session limit, and detection-only safety boundary remain unchanged.
