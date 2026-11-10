import CpsatSolver.Defs

namespace CpsatSolver

/-- A concrete model: the finite sets of declared variables/intervals, the
    constraints, and an objective.

    Identity is structural (`Encodable`), so a constraint or expression can
    only "reference" a variable by *being* that variable's structure. There is
    therefore no separate well-formedness invariant that references resolve —
    any `IntVar`/`BoolVar`/`FixedSizeIntervalVar` mentioned by a constraint is,
    by definition, the same object as its declaration if and only if their
    structures coincide. Declaring a variable in the spec simply means the
    solver will emit it; a constraint mentioning an undeclared (structurally
    distinct) variable will cause that variable to be emitted lazily by the
    code generator, not a malformed reference. -/
structure ModelSpec where
  ints : Array IntVar
  bools : Array BoolVar
  intervals : Array FixedSizeIntervalVar
  constraints : Array Constraint
  objective : Objective

/-- A model is currently just a `ModelSpec`. Kept as a distinct wrapper so the
    `model.spec` accessor and future invariants have a stable home. -/
structure Model where
  spec : ModelSpec

end CpsatSolver
