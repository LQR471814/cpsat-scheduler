import CpsatScheduler.CpsatSolver.Defs
import CpsatScheduler.CpsatSolver.Entity

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
    ∀ v ∈ (RefVars.intVars a), v ∈ spec.ints ∧
    ∀ v ∈ (RefVars.boolVars a), v ∈ spec.bools ∧
    ∀ v ∈ (RefVars.fixedSizeIntervalVar a), v ∈ spec.intervals

structure Model where
  spec : ModelSpec
  refsExist :
    AllRefsExist spec spec.constraints ∧
    AllRefsExist spec { spec.objective }

end CpsatSolver

