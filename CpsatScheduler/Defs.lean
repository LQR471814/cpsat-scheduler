import CpsatScheduler.CpsatSolver.Defs

import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Interval
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Combinatorics.Digraph.Basic

namespace CpsatScheduler

structure Timescales where
  scales : Finset ℤ
  hasAtomic : 1 ∈ scales
  divisibility : ∀ a b : ℤ, a ∈ scales → b ∈ scales → a ≥ b → a % b = 0
  intValid : ∀ a : ℤ, a ∈ scales → CpsatSolver.Int64.Proof a

structure Time (scales : Timescales) where
  coeff : ℤ
  unit : ℤ
  unitValid : unit ∈ scales.scales
  intValid : CpsatSolver.Int64.Proof (coeff * unit)
  deriving DecidableEq

-- ensures no remainder when int division, preventing lossy division
private def Int.losslessDiv (a : ℤ) (b : ℤ) (_ : a % b = 0) :=
  a / b

-- converts from a lesser timescale to a greater one
def Time.convertUp {scales : Timescales}
  (src : Time scales)
  (newUnit : ℤ)
  (newUnitValid : newUnit ∈ scales.scales)
  (isGe : newUnit ≥ src.unit) :=
  let scaleFactor := Int.losslessDiv newUnit src.unit (
    scales.divisibility newUnit src.unit
      newUnitValid src.unitValid isGe
  );
  let newCoeff := src.coeff * scaleFactor;
  fun (intValid : CpsatSolver.Int64.Proof (newCoeff * newUnit)) =>
  ({
    coeff := newCoeff
    unit := newUnit
    unitValid := newUnitValid
    intValid := intValid
  } : Time scales)

-- converts from a greater timescale to a lesser one
def Time.convertDown {scales : Timescales}
  (src : Time scales)
  (newUnit : ℤ)
  (newUnitValid : newUnit ∈ scales.scales)
  (isLt : newUnit < src.unit) :=
  let newCoeff := Int.losslessDiv src.unit newUnit (
    scales.divisibility src.unit newUnit
      src.unitValid newUnitValid (Std.le_of_lt isLt)
  );
  fun (intValid : CpsatSolver.Int64.Proof (newCoeff * newUnit)) =>
  ({
    coeff := newCoeff
    unit := newUnit
    unitValid := newUnitValid
    intValid := intValid
  } : Time scales)

structure Interval where
  greater : ℤ
  lesser : ℤ
  validLt : lesser ≤ greater
  validGe : CpsatSolver.Int64.Proof greater
  validLe : CpsatSolver.Int64.Proof lesser
  deriving DecidableEq

structure IntervalWithValue (α : Type) where
  interval : Interval
  value : α
  deriving DecidableEq

abbrev Interval.mutuallyExclusive (s : Finset Interval) :=
  ∀ a b : Interval, a ∈ s ∧ b ∈ s →
    (Finset.Icc a.lesser a.greater) ∪ (Finset.Icc b.lesser b.greater) = ∅

structure DiscretizedFunction (α : Type) where
  intervals : Finset (IntervalWithValue α)
  mutuallyExclusive :
    Interval.mutuallyExclusive (Finset.image (·.interval) intervals)
  deriving DecidableEq

inductive CostConfiguration where
  | duration

structure Task (scales : Timescales) where
  name : CpsatSolver.Python.ValidName
  startAfter : Option (Time scales)
  startBefore : Option (Time scales)
  deriving DecidableEq

-- sources:
-- Digraph : https://leanprover-community.github.io/mathlib4_docs/Mathlib/Combinatorics/Digraph/Basic.html
-- Relation.TransGen : https://leanprover-community.github.io/mathlib4_docs/Init/Core.html#Relation.TransGen

/-- for all tasks, there does not exist a chain of adjacent nodes which leads
  to the task itself -/
abbrev TaskSet.AcyclicGraph
  {scales : Timescales}
  {tasks : Finset (Task scales)}
  (graph : Digraph { x // x ∈ tasks }) : Prop :=
    ∀ x : Task scales, (h : x ∈ tasks) →
      let xsub := { val := x, property := h };
      ¬ (Relation.TransGen
          (fun a b => graph.Adj a b)
          xsub xsub)

/-- for all tasks, there exists exactly one node which has it ∈ its .Adj -/
abbrev TaskSet.TreeGraph
  {scales : Timescales}
  {tasks : Finset (Task scales)}
  (graph : Digraph { x // x ∈ tasks }) : Prop :=
  ∀ child : Task scales, (childInTasks : child ∈ tasks) →
    ∃ parent : Task scales, (parentInTasks : parent ∈ tasks) →
      graph.Adj
        { val := parent, property := parentInTasks }
        { val := child, property := childInTasks }

structure TaskSet (scales : Timescales) where
  tasks : Finset (Task scales)
  prereqs : Digraph { x // x ∈ tasks }
  children : Digraph { x // x ∈ tasks }
  prereqsAcyclic : TaskSet.AcyclicGraph prereqs
  childrenAcyclic : TaskSet.AcyclicGraph children
  childrenTree : TaskSet.TreeGraph children

end CpsatScheduler
