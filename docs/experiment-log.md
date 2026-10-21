# Experiment Log

## Decision record

Use a dedicated VVAH Ollama container and volume, publishing only
`127.0.0.1:11435`. VVAH will use its OpenAI-compatible API endpoint. The project
does not depend on, name, or modify unrelated services or workloads.

## Next measurement

Start the dedicated model container, download `qwen3:8b`, and run the three harmless
capability probes: model listing, structured JSON output, and tool calling.
