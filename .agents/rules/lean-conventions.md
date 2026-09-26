---
trigger: always_on
---

# Lean conventions (cpsat-scheduler)

Toolchain: `leanprover/lean4:v4.34.0-rc2`. Mathlib `v4.34.0-rc2`. lean-regex `v4.32.0`.
lakefile.toml enables `weak.linter.mathlibStandardSet`, `relaxedAutoImplicit = false`.
Follow Mathlib standard-set lint.

## Structure design pattern

- Structures carry proof obligations as fields (e.g. `UnitScale.pos`,
  `.nonoverflow`; `Horizon.begin_lt_end`; `Task.bucketsFitHorizon`;
  `Model.references`, `.variantsWF`, `.presolve`).
- Provide a `mkRaw ::` raw constructor + a smart `def X.mk` / `X.of` that
  discharges proofs via `:= by decide` default args. Match this pattern for new
  types. Callers should never fill proofs manually when `decide` suffices.
- Smart range/aggregate constructors derive per-element obligations by
  monotonicity (see `Task.ofBucketRange`). Prefer deriving over per-item proof.

## Nonoverflow discipline

- All solver-facing integers must satisfy `CpsatSolver.Int64.Nonoverflow`.
  Thread nonoverflow proofs through arithmetic (`LinearExpr` is indexed by
  `Bounds`; add/sub/mul/neg each take a nonoverflow hypothesis).
- No `Float` in the model. Convert with `Scipy.Convert.floatToRat` /
  `roundToInt64?` and track error via `errorBound` (see `CostTable`,
  `roundingErrorBound`).

## IDs and serialization

- `EntityId` allocated from single `Builder.freshId` counter (StateM). Uniqueness
  proven in `Model.uniqueInts/Bools/...`.
- Python identifiers come from IDs, never labels: `EntityId.toPythonName = "e_" ++ id`.
- `Python.ValidName` requires `ValidName.Proof` (not reserved keyword + valid
  ident); construct via `ValidName.of "name"` (proof by `decide`).
- Build Python via the typed AST (`Python.Expr`, `Statement`, `Script`), never raw
  string concatenation.

## Proof style

- Prefer `by decide` for finite/decidable obligations; `nlinarith`/`linarith` for
  the integer-bound arithmetic (as in `Task.ofBucketRange`).
- Mutual recursive `repr` uses `termination_by sizeOf` + `decreasing_by`.
- `namespace CpsatScheduler` for domain, `CpsatSolver` for IR, `Python` for AST,
  `Scipy` for scipy path. Keep new defs in the matching namespace.

## Adding a module

1. Create `CpsatScheduler/<Name>.lean` in the correct namespace.
2. Add `import CpsatScheduler.<Name>` to `CpsatScheduler.lean` if it's public API.
3. Build to verify (see build-and-test rule).
