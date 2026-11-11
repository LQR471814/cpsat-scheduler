import CpsatSolver.Defs
import CpsatSolver.RefVars

namespace CpsatSolver

structure ModelSpec where
  ints : Finset IntVar
  bools : Finset BoolVar
  intervals : Finset FixedSizeIntervalVar
  constraints : Finset Constraint
  objective : Objective

def AllRefsExist {α : Type} [RefVars α]
    (spec : ModelSpec) (set : Finset α) : Prop :=
  ∀ a ∈ set,
    ∀ v ∈ (RefVars.ints a), v ∈ spec.ints ∧
    ∀ v ∈ (RefVars.bools a), v ∈ spec.bools ∧
    ∀ v ∈ (RefVars.fixedSizeIntervals a), v ∈ spec.intervals

structure Model where
  spec : ModelSpec
  refsExist :
    AllRefsExist spec spec.constraints ∧
    AllRefsExist spec { spec.objective }

end CpsatSolver

