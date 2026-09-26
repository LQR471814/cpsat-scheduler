---
trigger: always_on
---

# cpsat-scheduler — project overview

Purpose: formally-verified time scheduler. Model scheduling in Lean 4 + Mathlib,
prove well-formedness/optimality/nonoverflow, emit correct Python that drives
Google CP-SAT (ortools) or SciPy.

## Domain (see docs/PHILOSOPHY.md, docs/DESIGN.md, docs/MATHEMATICS.md)

- Task = target of time allocations. Has id, unit, start-bucket domain, deadline,
  prerequisites, cost function.
- Solver quantizes time into buckets `[k*u, (k+1)*u)`. Chooses allocations +
  child task timeframes to minimize expected cost.
- Constraints: prerequisite, bucket-contained-in, packing/cumulative, cost table.
- Hard rule: NO floating point in the solver model. Use fixed-point / rational
  (`RatQuantity`, `mkRat`) approximation. CP-SAT ints must fit `Int64`
  (`CpsatSolver.Int64.Nonoverflow`).

## Layout

- `CpsatScheduler.lean` — root import aggregator.
- `CpsatScheduler/Defs.lean` — core domain types: `UnitScale`, `Units`,
  `UnitValue`, `RatQuantity`, `Horizon`, `Timescales`, `Task`, `CostTable`.
- `CpsatScheduler/Task.lean` — `Task.ofBucketRange` smart constructor (derives
  per-bucket horizon-fit + nonoverflow proofs).
- `CpsatScheduler/Constrain*.lean` — constraint builders (PERT, Bucket, Prereq,
  Packing).
- `CpsatScheduler/CostTable.lean`, `Objective.lean`, `Optimality.lean`.
- `CpsatScheduler/UnitScale.lean`, `UnitValue.lean`, `UnitAware.lean`,
  `RatQuantity.lean` — unit system.
- `CpsatScheduler/CpsatSolver/` — CP-SAT IR + serialization:
  - `Defs.lean` — `EntityId`, `BoolVar`, `IntVar`, `LinearExpr` (bounds-indexed),
    `FixedSizeIntervalVar`, `Constraint`, `Objective`.
  - `Model.lean` — `RawModel`, `Model` (with WF proofs), `Builder` (StateM),
    assignment checking, Python serialization.
  - `LinearExpr.lean`, `WellFormed.lean`, `EntityId.lean`, `ToPython.lean`,
    `Domain/` (Domain, Interval, NonemptyDomain, Bounds).
- `CpsatScheduler/Python/Basic.lean` + `Python.lean` — typed Python AST
  (`Expr`, `Literal`, `Statement`, `Import`, `Script`) with `ValidName` (proven
  valid identifier, not reserved keyword). Emits real Python source.
- `CpsatScheduler/Scipy/` — SciPy linprog path (Basic, Batch, PERT, Convert).
- `src/cpsatscheduler/` — Python runtime side (frontend/schedule.py, pert.py,
  units.py; backend/config.py, config_builder.py, print.py). Packaged via uv,
  built to onefile with nuitka.
- `docs/` — DESIGN, PHILOSOPHY, MATHEMATICS, CONSTRAINT_FLEXIBILITY, cp_model.proto.
- `tests/cpsat/*.py` — CP-SAT feature reference demos. `tests/test_cpsat_outputs.py`.

## Data flow

Lean domain (`Task`, `Timescales`) → CP-SAT IR (`Model`) → typed Python AST
(`Python.Script`) → executed via `Script.exec` against ortools/scipy → JSON result.
