# Local training target

`scripts/create_demo_target.py` creates a deliberately vulnerable Python source
fixture under `targets/toy-vulnerable-python-api/`. The generated directory is
ignored by Git and is never started as a service.

The fixture gives the first VVAH evaluation a known, independently reviewable
baseline:

| Expected class | Location | Independent review criterion |
| --- | --- | --- |
| SQL injection (CWE-89) | Search handler | Request input is interpolated into a SQL statement. |
| OS command injection (CWE-78) | Diagnostic handler | Request input reaches a shell command with `shell=True`. |
| Path traversal (CWE-22) | Report download handler | A request path is joined to a filesystem directory without containment validation. |

After the scan, compare VVAH's candidates against these criteria. Count only
findings supported by the generated source as true positives; record unsupported
claims separately as false positives.

The fixture is for source-code analysis only. Do not install its dependencies,
run it, bind it to a port, or expose it to any network.
