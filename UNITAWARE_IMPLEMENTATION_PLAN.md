# UnitAware and CP-SAT Model Refactor Plan

## Goal

Refactor the generic CP-SAT and `UnitAware` layers so generated scheduler models have explicit unit semantics, safe integer arithmetic, complete reference checking, executable constraint-satisfaction semantics, and a scheduler API based on bucket indices and half-open bucket occupancy.

The implementation should proceed incrementally and keep `lake build` passing at each checkpoint where practical.

## Agreed design decisions

- Unit scales are positive natural numbers, include atomic scale `1`, fit in CP-SAT `Int64`, and form a divisibility hierarchy: every larger allowed scale is exactly divisible by every smaller allowed scale.
- Solver-facing values and expressions are indexed by their unit. Operations requiring equal units express that requirement in their types.
- Normalization is explicit. A helper may normalize two values or expressions losslessly to their minimum/finer unit.
- Finer conversion is exact multiplication. Coarser conversion uses truncation toward zero and is a model-building operation introducing an auxiliary quotient variable plus a positive-constant division-equality constraint.
- Only positive constant division is required initially. Exact and truncating division are distinct APIs.
- Binary quantity-by-quantity multiplication and division do not belong in the solver-facing API. Arbitrary unit products and quotients belong in a separate rational arithmetic layer, with explicit proofs required to re-enter allowed integer solver units.
- Low-level numeric variable domains are closed. Scheduling horizons and bucket occupancy are half-open.
- A task start value is a bucket index `k`; with bucket size `u`, its physical bucket is `[k*u, (k+1)*u)`.
- Every allowed task bucket must fit fully within the horizon, and its boundary arithmetic must be `Int64` safe.
- A prerequisite conservatively requires the successor bucket start to be at or after the predecessor bucket end.
- Generic bucket containment permits equal units but requires `child.unit <= parent.unit`. Scheduler parent edges require strict unit growth.
- Scheduler parents form a forest with multiple roots. Prerequisites form an acyclic directed graph.
- `timeDemanded` replaces `duration`. It is measured in atomic units, may be zero, must not exceed the task bucket size, and is reserved across the entire task bucket.
- A cumulative item pairs its interval and demand. All item intervals share a timeline unit; all demands and capacity share another unit. Demands and capacity are nonnegative.
- Quantized task costs are represented by a nonempty finite table of allowed `(timeDemanded, encodedCost)` pairs. Demand keys are unique.
- Each task cost table has rational true-cost semantics and one uniform nonnegative error bound.
- The scheduler objective is currently minimization of the sum of task costs. The low-level layer supports no objective, minimization, and maximization.
- Solver objects use opaque builder-allocated IDs from one global namespace. Labels are separate from identity and are used only for diagnostics.
- A complete returned assignment is checked in Lean for constraint satisfaction. The claim of global optimality remains trusted at the process boundary.
- Structural well-formedness and cheap presolve sanity checks are mandatory. The library does not attempt to prove that a satisfying assignment exists.
- Obvious-contradiction checks apply to unconditional constraints. Contradictory enforced bodies remain legal because they can intentionally force enforcement literals false.

## Phase 1: Canonical domains and conservative bounds

Primary file: `CpsatScheduler/CpsatSolver/Defs.lean`

- Replace `Interval.set := Finset.Icc ...` as the representation of variable domains.
- Define a closed interval primitive over `Int64`.
- Define `Domain` as a canonical array of sorted, disjoint, nonadjacent closed intervals.
- Permit the empty domain internally so intersection and filtering are total operations.
- Require a `NonemptyDomain` subtype for declared `IntVar`s.
- Implement membership, minimum, maximum, intersection, union, singleton, and interval-hull operations without enumerating all integers.
- Rename the interval attached to `LinearExpr` to `Bounds` and treat it as a sound over-approximation, not an exact value set.
- Update expression constructors to calculate conservative bounds and prove `eval_mem_bounds` for domain-respecting assignments.
- Preserve explicit `Int64.Nonoverflow` proofs for every serialized coefficient and calculated bound.

Acceptance checkpoint:

- Sparse domains and very large intervals can be constructed without materializing their members.
- Existing linear-expression evaluation theorems are migrated and `lake build` passes.

## Phase 2: Opaque identity, builder state, and certified models

Primary files: `CpsatScheduler/CpsatSolver/Defs.lean`, `CpsatScheduler/CpsatSolver/Model.lean`

- Introduce an opaque solver entity ID allocated from one monotonically increasing builder counter.
- Use IDs for integer variables, Boolean variables, intervals, constraints, and auxiliary objects.
- Store optional/unrestricted labels separately from IDs.
- Generate collision-free Python identifiers from IDs; do not use labels as Python identifiers.
- Introduce an incomplete `RawModel`/builder state and a certified `Model` accepted by serialization.
- Check global ID uniqueness and all reference classes:
  - integer variables referenced by expressions;
  - Boolean variables referenced by Boolean literals and enforcement;
  - interval variables referenced by cumulative constraints;
  - integer variables referenced by interval start expressions;
  - variables referenced by solve outputs and objectives.
- Prefer composing builder actions before finalization. Retire the current name-based `Model.union` initially; add alpha-renaming of independently finalized models only if a concrete use case appears.

Acceptance checkpoint:

- User labels can duplicate and can contain text unsuitable for Python identifiers.
- Dangling references cannot reach script generation.
- Generated Python identifiers are globally unique across entity categories.

## Phase 3: Extend and regularize the low-level AST

Primary files: `CpsatScheduler/CpsatSolver/Defs.lean`, `CpsatScheduler/CpsatSolver/Model.lean`

- Add sparse-domain variable serialization.
- Add positive-constant truncating division equality.
- Add `allowedAssignments` with fixed arity in the type:
  - columns are `Vector IntVar n`;
  - rows are finite `Vector Int64 n` values;
  - row arity is structural;
  - row coordinates must belong to the corresponding exact variable domains.
- Refactor cumulative constraints to use paired `(interval, demand)` items instead of parallel arrays.
- Treat fixed-size intervals as half-open `[start, start + size)` and retain nonnegative size.
- Add explicit objectives: none, minimize a linear expression, or maximize one.
- Separate `Variant.WellFormed` from an enclosing `Constraint.PassesPresolveSanityChecks`.
- Require sanity checks for unconditional constraints only. Checks should be cheap, variant-specific necessary conditions rather than existential satisfiability searches.
- Permit empty/contradictory bodies when enforcement is present.

Acceptance checkpoint:

- The AST can express the task cost table and truncating coarsening without raw Python escape hatches.
- Conditional contradictory tables and relations remain representable.

## Phase 4: Assignment and satisfaction semantics

Primary files: `CpsatScheduler/CpsatSolver/Defs.lean`, `CpsatScheduler/CpsatSolver/Model.lean`

- Define complete integer and Boolean assignments keyed by opaque IDs.
- Define exact evaluation for linear expressions, Boolean literals, and enforcement conjunctions.
- Define `Constraint.Holds assignment` for every variant:
  - bounded linear relations;
  - max equality;
  - positive-constant truncating division using Lean `Int.tdiv` semantics;
  - allowed assignments;
  - Boolean and/or/implication;
  - half-open cumulative capacity.
- Define `Model.Satisfies assignment` as domain membership plus satisfaction of every active constraint.
- Define exact objective evaluation.
- For executable cumulative checking, inspect the finite set of assigned interval start boundaries rather than enumerating an entire horizon, and prove equivalence with the half-open load semantics.
- Do not define or require `exists assignment, Model.Satisfies assignment` during model construction.

Acceptance checkpoint:

- Known satisfying and violating assignments are accepted/rejected in Lean without invoking OR-Tools.

## Phase 5: Python serialization and solver responses

Primary file: `CpsatScheduler/CpsatSolver/Model.lean`

- Serialize canonical domains through the OR-Tools domain API.
- Serialize allowed assignments, division equality, paired cumulative constraints, and objectives.
- Emit declarations before constraints regardless of builder action order.
- Return values for every declared integer and Boolean variable, including auxiliaries.
- Parse results into an assignment keyed by opaque IDs.
- Recompute the exact integer objective in Lean from the returned assignment.
- Keep OR-Tools' floating objective value only as optional diagnostic metadata, if retained at all.
- Replace a single weak response validity predicate with status-specific results:
  - infeasible/model-invalid/unknown carry no schedule;
  - feasible carries a checked satisfying assignment;
  - optimal carries a checked satisfying assignment plus a trusted optimality boundary claim.

Acceptance checkpoint:

- Round-trip tests cover all AST variants and reject malformed or constraint-violating result payloads.

## Phase 6: Unit foundations and rational arithmetic

Primary file: `CpsatScheduler/Defs.lean`; split into dedicated unit modules if the dependency graph becomes clearer.

- Define positive natural `UnitScale` values with `Int64` representability.
- Refactor `Units` around a finite set of `UnitScale`s, atomic scale `1`, and the global divisibility hierarchy.
- Make `UnitValue` indexed by its unit.
- Support same-unit addition/subtraction, dimensionless integer multiplication, exact positive-constant division, and truncating positive-constant division under distinct names.
- Remove incorrect binary `UnitValue.mul` and `UnitValue.div`.
- Introduce a separate rational scale/quantity representation for arbitrary unit arithmetic.
- Keep rational normalization explicit.
- Require proofs of allowed-unit membership, integral coefficient, and `Int64` safety before lowering rational quantities into solver values.

Acceptance checkpoint:

- Unit multiplication/division produces arithmetically correct rational scales.
- No solver-facing operation falsely claims that multiplying two quantities preserves the original unit.

## Phase 7: Type-indexed `UnitAware`

Primary file: `CpsatScheduler/Defs.lean`; consider moving this namespace into `CpsatScheduler/UnitAware.lean`.

- Index `UnitAware.IntVar`, `LinearExpr`, and interval types by their unit.
- Make equal-unit addition, subtraction, and comparison type-correct without runtime equality fields.
- Implement explicit lossless normalization of two operands to their minimum/finer unit.
- Implement finer conversion as multiplication by the proved integral scale ratio.
- Implement coarser conversion as a builder operation that allocates an auxiliary variable and emits positive-constant truncating division equality.
- Distinguish exact rescaling and truncating quantization in names and return types.
- Add unit-aware fixed-size intervals.
- Add generic unit-aware cumulative construction with separate timeline and demand/capacity unit indices and paired items.
- Carry conservative bounds and nonoverflow proofs through all conversions.

Acceptance checkpoint:

- Mixed-unit arithmetic cannot occur implicitly.
- Exact normalization generates no auxiliary variable; coarsening visibly does.

## Phase 8: Scheduler horizon, tasks, and structural constraints

Primary files: `CpsatScheduler/Defs.lean`, `CpsatScheduler/Constraints.lean`

- Separate opaque `TaskId` from unrestricted task labels.
- Define a nonnegative atomic-unit half-open horizon `[begin, end)` with `begin < end`.
- Replace `startAfter`/`startBefore` with a resolved nonempty exact domain of bucket indices.
- Provide a convenience constructor for the largest horizon-derived start domain using directed ceiling/floor projection.
- Intersect optional explicit user bucket-index domains during construction rather than retaining optional bounds in the core task.
- Require, for every permitted bucket index `k` and task unit `u`:
  - `horizon.begin <= k*u`;
  - `(k+1)*u <= horizon.end`;
  - both bucket boundaries are `Int64` representable.
- Add a specialized nonnegative `TaskStart` wrapper while keeping generic unit-aware integer variables signed.
- Replace `TaskConstrain.afterTask` with distinct generic relations:
  - `bucketContainedIn child parent`, requiring `child.unit <= parent.unit` and local domain compatibility;
  - `prerequisite successor predecessor`, requiring successor start after predecessor bucket end.
- Encode containment in child coordinates using the exact ratio:
  - `parentStart * ratio <= childStart`;
  - `childStart + 1 <= (parentStart + 1) * ratio`.
- Encode prerequisites after exact normalization to the finer unit.
- Represent scheduler parents as a forest with multiple roots, at most one immediate parent per child, and strict unit growth on every edge.
- Represent prerequisites as a graph with a mandatory acyclicity proof.

Acceptance checkpoint:

- Parent and prerequisite constraints have separate semantics and generated names/labels.
- Examples with misaligned horizons, multiple roots, mixed units, and impossible local domains are covered.

## Phase 9: Demand, cumulative scheduling, and quantized cost

Primary files: `CpsatScheduler/Defs.lean`, `CpsatScheduler/Constraints.lean`

- Rename `durationVar` to `timeDemanded`.
- Measure `timeDemanded` in atomic units.
- Represent each task's permitted demand/cost relation as a nonempty finite table.
- Require unique demand keys and prove `0 <= demand <= task.unit` for every point; zero remains allowed.
- Derive exact sparse domains for demand and encoded cost from the table.
- Emit a direct allowed-assignments constraint between those two variables.
- For each bucket scale, construct one scheduler-specific cumulative constraint:
  - each task interval has size one in bucket-index coordinates;
  - each task demand is atomic-unit `timeDemanded`;
  - capacity is the bucket scale expressed in atomic units;
  - demand is reserved for the entire bucket.
- Store rational true-cost semantics and one uniform nonnegative error bound per task curve.
- Prove every encoded point is within its task's error bound.
- Build the minimization objective as the sum of all task cost variables.
- Prove that, for an encoded-optimal returned schedule, true total cost is at most true optimum plus twice the sum of task error bounds.
- Make no near-optimality claim for merely feasible solver responses.

Acceptance checkpoint:

- A small multi-scale model exercises containment, prerequisites, bucket cumulative packing, sparse demand choices, and objective minimization end to end.

## Phase 10: Migration, cleanup, and verification

Primary files: `CpsatScheduler/Defs.lean`, `CpsatScheduler/Constraints.lean`, `CpsatScheduler.lean`, `TestCpsatSolver.lean`

- Remove the abandoned `LinearExpr.valueSet` and unresolved `convertUnit` stub.
- Remove the old `DiscretizedFunction` interval abstraction from task costs.
- Remove obsolete `startAfterTime`, `startBeforeTime`, `durationVar`, and vestigial `afterTask` APIs.
- Migrate examples and tests to opaque IDs, the builder, sparse domains, and certified models.
- Add Lean tests for:
  - domain canonicalization and nonenumerating membership;
  - expression-bound soundness;
  - truncation toward zero for negative numerators;
  - finer normalization and coarser auxiliary-variable generation;
  - full-bucket horizon containment;
  - parent forests and prerequisite cycles;
  - allowed-assignment uniqueness and pairing;
  - half-open cumulative boundary behavior;
  - complete assignment checking;
  - exact objective evaluation and rational error guarantees.
- Run direct Lean compilation, `lake build`, and generated Python integration tests against the pinned OR-Tools version.

## Recommended implementation order

Do not begin with the scheduler structures. Complete phases 1 through 5 first so `UnitAware` can target stable low-level domain, identity, AST, semantics, and serialization APIs. Then implement phases 6 and 7 before rebuilding task-level behavior in phases 8 and 9. Perform removals only after their replacements compile and have tests.

## Baseline

At the time this plan was written, an incremental `lake build` completed successfully. No implementation changes described above had yet been made.
