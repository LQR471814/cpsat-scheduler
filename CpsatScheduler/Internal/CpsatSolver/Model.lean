module

public import CpsatScheduler.Internal.CpsatSolver.RefVars
public import CpsatScheduler.Internal.CpsatSolver.Encodability

@[expose] public section

namespace CpsatSolver

def FinsetDepElems [HasRepr α] [CpsatType α]
  [DecidableEq α] (s : Finset (Entity α)) :=
  s.image fun x => x.val

structure ModelSpec where
  ints : Finset (Entity IntVar)
  bools : Finset (Entity BoolVar)
  intervals : Finset (Entity FixedSizeIntervalVar)
  constraints : Finset (Entity Constraint)
  objective : Entity Objective
deriving DecidableEq

def AllRefsExist {α : Type} [RefVars α]
    (spec : ModelSpec) (set : Finset α) : Prop :=
  ∀ a ∈ set,
    ∀ v ∈ (RefVars.ints a), v ∈ (FinsetDepElems spec.ints) ∧
    ∀ v ∈ (RefVars.bools a), v ∈ (FinsetDepElems spec.bools) ∧
    ∀ v ∈ (RefVars.fixedSizeIntervals a), v ∈ (FinsetDepElems spec.intervals)

structure Model where
  spec : ModelSpec
  refs_exist :
    AllRefsExist spec (spec.constraints.image fun x => x.val) ∧
    AllRefsExist spec { spec.objective.val }
deriving DecidableEq

def Model.ints (m : Model) := FinsetDepElems m.spec.ints
def Model.bools (m : Model) := FinsetDepElems m.spec.bools
def Model.intervals (m : Model) := FinsetDepElems m.spec.intervals
def Model.constraints (m : Model) := FinsetDepElems m.spec.constraints
def Model.objective (m : Model) := m.spec.objective.val

end CpsatSolver
