---
trigger: always_on
---

# Build / test / lint (cpsat-scheduler)

Two toolchains: Lean (lake) + Python (uv). Nushell scripts (`.nu`) wrap commands.

## Lean

- Build lib + exe: `lake build`. Default target `CpsatScheduler`; exe target
  `TestCpsatSolver` (root `TestCpsatSolver.lean`).
- Run solver test exe: `lake exe TestCpsatSolver`.
- After ANY Lean change, run `lake build` to verify proofs compile before
  reporting done. Fix errors before finishing.
- First build after dependency change is slow (Mathlib). `.lake/packages/` holds
  mathlib, batteries, aesop, Qq, Regex, etc — do not edit.

## Python

- Managed by `uv`. Workspace member `test`. Runtime deps: ortools, scipy, grpcio,
  python-dateutil. Requires Python >= 3.13.
- Type check: `uv run ty check`.
- Lint + autofix: `uv run ruff check . --fix`  (= `lint.nu`).
- Tests: `uv run pytest` (or `tests/test_cpsat_outputs.py`).
- Build daemon binary: `uv run nuitka --mode=onefile ./src/solver/daemon.py`
  (= `build.nu`). Clean artifacts with `clean.nu`.

## Verification checklist per change

- Lean edit → `lake build` (and `lake exe TestCpsatSolver` if solver logic).
- Python edit → `uv run ty check` + `uv run ruff check . --fix` + `uv run pytest`.
- Do not commit unless user asks. Do not push to remote (CI runs
  `.github/workflows/lean_action_ci.yml`).

## Notes

- `tests/cpsat/*.py` are ortools API reference demos — consult when modeling a new
  CP-SAT constraint before implementing the Lean IR + serializer.
- `git_daemon.nu` starts a local git daemon; not needed for normal dev.
