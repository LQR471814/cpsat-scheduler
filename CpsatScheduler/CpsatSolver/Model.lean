import CpsatScheduler.CpsatSolver.Defs
import CpsatScheduler.CpsatSolver.Entity

namespace CpsatSolver

structure ModelSpec where
  ints : Array IntVar := #[]
  bools : Array BoolVar := #[]
  intervals : Array FixedSizeIntervalVar := #[]
  constraints : Array Constraint := #[]
  objective : Objective := .none

abbrev UniqueEntityIDs {α : Type} [Entity α] (arr : Array α) : Prop :=
  ∀ a b : Fin arr.size, a ≠ b → Entity.id arr[a] ≠ Entity.id arr[b]

abbrev AllRefsExist {α : Type} [RefVars α] (spec : ModelSpec)
    (arr : Array α) : Prop :=
  ∀ a ∈ arr,
    ∀ v ∈ (RefVars.intVars a), v ∈ spec.ints ∧
    ∀ v ∈ (RefVars.boolVars a), v ∈ spec.bools ∧
    ∀ v ∈ (RefVars.fixedSizeIntervalVar a), v ∈ spec.intervals

structure Model where
  spec : ModelSpec
  uniqueIds :
    UniqueEntityIDs spec.ints ∧
    UniqueEntityIDs spec.bools ∧
    UniqueEntityIDs spec.intervals ∧
    UniqueEntityIDs spec.constraints
  refsExist :
    AllRefsExist spec spec.constraints ∧
    AllRefsExist spec #[spec.objective]

end CpsatSolver

