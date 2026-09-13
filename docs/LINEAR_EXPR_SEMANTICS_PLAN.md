# Linear expression semantics implementation plan

## Goal

Give `CpsatSolver.LinearExpr` arithmetic semantics over every valuation of its
integer variables. Expose those
semantics using ordinary Lean `Set`s so identities such as
`-(-a) = a` and `(a + b) - b = a` can be proved as set equalities.

The existing interval index remains a conservative bound used to prevent
Int64 overflow. CP-SAT itself is a trusted external component.

## Agreed design

1. Keep a single proof-carrying `LinearExpr` AST. Do not introduce a second
   representable-expression structure.
2. Define evaluation structurally over `ℤ`. Constructor overflow proofs are
   used when constructing expressions; evaluation ignores proof fields.
3. Evaluate expressions under an arbitrary valuation `IntVar → ℤ`. The solver
   chooses the valuation; domain membership is supplied separately by theorems
   that need it.
4. Define the primary semantics as a standard set of valuation/value pairs:

   ```lean
   Set ((IntVar → ℤ) × ℤ)
   ```

   Keeping the valuation in the set preserves correlations. For example,
   `x` and `-x` can have the same possible output values without having the
   same value under the same valuation.
5. Derive `possibleValues : Set ℤ` from the primary semantics by projection.
6. Treat expression domains as conservative bounds, not exact possible-value
   sets.
7. Trust CP-SAT according to an explicit contract at the process-execution
   boundary. Raw JSON parsing alone provides no solver-correctness guarantee.
8. Retain primitive negation. Remove multiplication of two expressions;
   introduce scalar multiplication only if a current caller needs it.
9. Defer affine normalization. Structural evaluation plus `simp`/`ring` is
   sufficient for the first arithmetic identities.

## Implementation sequence

### 1. Correct the expression grammar

Files:

- `CpsatScheduler/CpsatSolver/Defs.lean`
- `CpsatScheduler/CpsatSolver/Helpers.lean`
- `CpsatScheduler/Defs.lean`

Tasks:

- Remove expression-by-expression multiplication from `LinearExpr`.
- Add scalar multiplication if required by existing scheduling code.
- Correct the current constructor/helper mismatch: `fromMul` currently carries
  subtraction bounds and `fromSub` carries multiplication bounds.
- Ensure Python generation contains only operations accepted as CP-SAT linear
  expressions.

### 2. Collect referenced integer variables

Define a recursive function similar to:

```lean
LinearExpr.intVars : LinearExpr D → Finset IntVar
```

Add reference collection for:

- bounded linear expressions;
- fixed-size interval start expressions;
- constraints;
- solve-request expressions.

A small `HasIntVars` type class may provide a uniform interface for containers,
but recursive collection from `LinearExpr` should remain an ordinary function.

### 3. Define well-formed references

Define propositions stating that collected variables belong to `model.ints`.
Cover both:

- expressions referenced by `Model` constraints and fixed-size intervals;
- expressions added by `SolveRequest`.

Decide during implementation whether these proofs become structure fields or
are bundled in validated wrappers. In either case, invalid models and requests
must not reach the trusted solve interface.

### 4. Define valuations and evaluation

Define `LinearExpr.eval` recursively over `ℤ` for variables, constants,
negation, addition, subtraction, and scalar multiplication if present.

Add simplification lemmas for each evaluator case.

### 5. Define standard `Set` semantics

Define the primary meaning as the graph of evaluation over all valuations:

```lean
LinearExpr.meaning : Set ((IntVar → ℤ) × ℤ)
```

Define:

```lean
LinearExpr.possibleValues : Set ℤ
```

as the projection of `meaning` onto its result component.

Require or consume the expression's reference-well-formedness proof where it
is needed to connect these definitions to the model.

### 6. Prove semantic and bounds results

Initial semantic theorems:

- double negation;
- `(a + b) - b = a`;
- `a - a = 0`;
- addition associativity and commutativity where all intermediate expressions
  are constructible.

State these as equality of `meaning` sets. Use `simp` and `ring` after exposing
evaluation.

Prove domain soundness:

```text
If an expression's variables respect their domains, evaluating it under a
domain-respecting valuation produces a value in the expression's conservative
interval.
```

This theorem must not claim that every value in the interval is attainable.

### 7. Integrate model and request validation

Update all model and request constructors, including `TestCpsatSolver.lean`, to
supply the new reference-well-formedness evidence. Preserve the existing
unique-name checks and add category prefixes separately to prevent generated
Python identifier collisions.

### 8. Mark the trusted solver boundary

Define a validity predicate for feasible or optimal responses saying that there
exists one domain-respecting, constraint-satisfying valuation for which
every returned request value equals `LinearExpr.eval` on the corresponding
requested expression.

Associate this trusted contract with `Model.solve`, not with
`Model.parseScriptOutput`, because the parser can consume arbitrary JSON.
Clearly mark any axiom or opaque trusted assumption used for the external
CP-SAT process.

### 9. Repair and clarify bounds contradiction checks

Keep `BoundedLinearExpr.NoContradict` as a conservative bounds-level check, not
a satisfiability proof. In particular, replace the current `.neq => L ≠ R`:
equal nonsingleton intervals do not make `x ≠ y` contradictory.

Document the intended behavior and add examples for equal singleton, equal
nonsingleton, disjoint, and overlapping intervals.

### 10. Verify

Run the full Lean build and add focused checks covering:

- evaluation of every constructor;
- the initial semantic set equalities;
- conservative-domain soundness;
- rejection of undeclared variable references;
- Python output for the corrected linear grammar;
- existing model/script generation behavior.

## Important implementation caveat

Per-node overflow checking can reject an expression such as `(a + b) - b` when
the intermediate `a + b` bound overflows, even though the simplified result
`a` is safe. Keep the existing per-constructor policy initially. If this blocks
real callers, revisit affine normalization as a later, separate change.

## Completion criteria

The work is complete when:

- `LinearExpr` has no expression-by-expression multiplication;
- every model/request expression references declared integer variables;
- solver-validity predicates enforce declared variable domains;
- `eval`, `meaning`, and `possibleValues` are available;
- double-negation and add/subtract cancellation are proved as `Set` equalities;
- evaluation is proved to stay inside its conservative interval;
- the CP-SAT trust boundary is explicit;
- `NoContradict.neq` is corrected;
- the repository builds and relevant tests pass.
