Probes for ADR-0166's `@std:` annotation.

They live here rather than under `tests/` because every harness there passes
`--std=` on the command line, derived from the directory — and the annotation
is read *only* when no flag was given, so a case registered by the ordinary
glob could never exercise it. `selfhost/producttest.sh` asserts what each one
does and `tests/checks/coverage.py` drives them with no flag, which is the only
way the scan is reached at all.
