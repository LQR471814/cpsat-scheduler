---
trigger: always_on
---

# Lean conventions

Toolchain `leanprover/lean4:v4.34.0-rc2`, Mathlib `v4.34.0-rc2`.
lakefile enables `weak.linter.mathlibStandardSet`,
`relaxedAutoImplicit = false`. Follow standard-set lint.

- No comments; let code speak. Simplify after finishing.
- Structures carry proof fields. If necessary, provide smart
  `mk`/`of` that discharge proofs via `:= by decide` defaults.
  Derive per-element proofs by monotonicity
  (`Task.ofBucketRange`), never per-item.
- All solver ints satisfy `CpsatSolver.Int64.Nonoverflow`; thread
  proofs through arithmetic. No `Float` in model — convert via
  `Scipy.Convert.floatToRat`/`roundToInt64?`, track `errorBound`.
- IDs from single `Builder.freshId` (StateM); uniqueness proven in
  `Model.unique*`. Python names from IDs
  (`EntityId.toPythonName`), never labels. Build Python via typed
  AST, never string concat. `Python.ValidName` via `ValidName.of`
  (proof by `decide`).
- Prefer `by decide` over `native_decide`. Mutual `repr` uses
  `termination_by sizeOf`. Namespaces: `CpsatScheduler` domain,
  `CpsatSolver` IR, `Python` AST, `Scipy` scipy.

## Adding a module

1. Create `CpsatScheduler/<Name>.lean` in correct namespace.
2. Add `import CpsatScheduler.<Name>` to `CpsatScheduler.lean` if
   public.
3. `lake build` to verify.
