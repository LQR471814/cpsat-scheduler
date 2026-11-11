import CpsatSolver.Defs
import CpsatScheduler.Util.Finset

namespace CpsatSolver

/-- A concrete model: the finite sets of declared variables/intervals, the
    constraints, and an objective.

    Identity is structural (`Encodable`), so a constraint or expression can
    only "reference" a variable by *being* that variable's structure. There is
    therefore no separate well-formedness invariant that references resolve —
    any `IntVar`/`BoolVar`/`FixedSizeIntervalVar` mentioned by a constraint is,
    by definition, the same object as its declaration if and only if their
    structures coincide. Declaring a variable in the spec simply means the
    solver will emit it. -/
structure ModelSpec where
  ints : Finset IntVar
  bools : Finset BoolVar
  intervals : Finset FixedSizeIntervalVar
  constraints : Finset Constraint
  objective : Objective

/-- Deterministically order a finite set of encodable elements by their
    structural identity (`Encodable.encode`), yielding a computable `List`.

    `Encodable.encode` is injective, so the ordering is a genuine linear order
    on the set and the resulting list contains exactly the set's elements
    (see `Finset.mem_sortByKey`). -/
def Finset.sortedByEncode {α : Type} [DecidableEq α] [Encodable α]
    (s : Finset α) : List α :=
  Finset.sortByKey s (fun x => Encodable.encode x.val)
    (fun a b h => Subtype.ext (Encodable.encode_injective h))

/-- A model is currently just a `ModelSpec`. Kept as a distinct wrapper so the
    `model.spec` accessor and future invariants have a stable home. -/
structure Model where
  spec : ModelSpec

end CpsatSolver
