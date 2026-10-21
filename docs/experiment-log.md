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

Result: this is the first configuration to pass a candidate through deterministic
evidence enrichment: six deep-dive candidates became one retained finding after
four exclusions and one duplicate collapse. Deep-dive time fell further to about
186 seconds. The retained candidate then reached Step 6, where the remaining
direct OpenAI-compatible `verify` role failed to emit a verdict, leaving zero final
results. The experiment therefore isolates the remaining failure to the verifier
route, rather than the detection/evidence path.

## Experiment 4 — schema-typed verifier

Keep Experiment 3 unchanged and route only the `verify` role through the same
OpenAI-compatible DeepAgents path. This tests whether the retained candidate can
receive a structured verification verdict. The run remains detection-only and
does not enable live exploit verification, remediation, or validation.

Result: no candidate reached verification. The threat model again needed repair
and a hollow-model retry, generated six investigation units, and deep-dive ran for
about 443 seconds. It produced 13 candidates, all rejected by deterministic
evidence enrichment; one unit also failed after its repair response did not parse.
This fails the reproducibility check: the single retained finding from Experiment
3 was not stable under the same configuration.

## Preliminary conclusion

Qwen 3 8B can operate the local VVAH workflow, use read-only tools, and sometimes
produce an evidence-backed candidate. Across repeated scans of the same small,
known training fixture, however, it does not yet produce sufficiently stable,
well-grounded structured output to serve as a dependable primary VVAH scanner.
Keep VVAH's deterministic evidence gate enabled. Treat this environment as a
research baseline and compare it with a stronger model or a deterministic SAST
tool before applying it to an authorized production repository.
