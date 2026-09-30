---
trigger: always_on
---

# Build / test / lint

Two toolchains: Lean (lake) + Python (uv). `.nu` scripts wrap
commands.

## Lean

- `lake build` (target `CpsatScheduler`; exe `TestCpsatSolver`).
  Run: `lake exe TestCpsatSolver`.
- After ANY Lean change → `lake build` to verify proofs; fix
  errors before reporting done.
- First build after dep change is slow (Mathlib). Don't edit
  `.lake/packages/`.

## Python

- uv-managed, Python >= 3.13.

## Per change

- Lean → `lake build` (+ `lake exe TestCpsatSolver` if solver
  logic).
- Don't commit/push unless asked (CI runs `lean_action_ci.yml`).
- `tests/cpsat/*.py` = ortools API reference; consult before
  modeling new constraint.
