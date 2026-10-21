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
