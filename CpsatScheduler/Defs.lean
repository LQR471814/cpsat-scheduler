import CpsatScheduler.CpsatSolver.Defs

import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Interval
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Combinatorics.Digraph.Basic
import Mathlib.Data.Finset.Sort

import CpsatScheduler.Util.Finset
import CpsatScheduler.Util.Graphs

namespace CpsatScheduler

structure Timescales where
  units : Finset ℤ
  hasAtomic : 1 ∈ units
  divisibility : ∀ a b : units, a ≥ b → (a : ℤ) % b = 0
  intValid : ∀ a : units, CpsatSolver.Int64.Proof a

structure Time (scales : Timescales) where
  coeff : ℤ
  unit : scales.units
  intValid : CpsatSolver.Int64.Proof (coeff * unit)
  deriving DecidableEq

-- ensures no remainder when int division, preventing lossy division
private def Int.losslessDiv (a : ℤ) (b : ℤ) (_ : a % b = 0) :=
  a / b

-- converts from a lesser timescale to a greater one
def Time.convertUp {scales : Timescales}
  (src : Time scales)
  (newUnit : scales.units)
  (isGe : newUnit ≥ src.unit) :=
  let scaleFactor := Int.losslessDiv newUnit src.unit (
    scales.divisibility newUnit src.unit isGe
  );
  let newCoeff := src.coeff * scaleFactor;
  fun (intValid : CpsatSolver.Int64.Proof (newCoeff * newUnit)) =>
  ({
    coeff := newCoeff
    unit := newUnit
    intValid := intValid
  } : Time scales)

-- converts from a greater timescale to a lesser one
def Time.convertDown {scales : Timescales}
  (src : Time scales)
  (newUnit : scales.units)
  (isLt : newUnit < src.unit) :=
  let newCoeff := Int.losslessDiv src.unit newUnit (
    scales.divisibility src.unit newUnit (Std.le_of_lt isLt)
  );
  fun (intValid : CpsatSolver.Int64.Proof (newCoeff * newUnit)) =>
  ({
    coeff := newCoeff
    unit := newUnit
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
  unit : scales.units
  startAfter : Option (Time scales)
  startBefore : Option (Time scales)
  deriving DecidableEq

structure TaskSet (scales : Timescales) where
  tasks : Finset (Task scales)
  prereqs : FinDigraph (Task scales)
  prereqsAcyclic : prereqs.IsAcyclic
  -- for any edge, src is the child & dst is the parent
  parents : FinDigraph (Task scales)
  parentsAcyclic : parents.IsAcyclic
  parentsTree : parents.IsTree
  parentsMonotonicUnit : ∀ e : parents.edges, e.val.src.val.unit.val < e.val.dst.val.unit.val

#eval
  let scales : Timescales := {
    units := { 1, 2, 4, 8 }
    intValid := by decide
    hasAtomic := by decide
    divisibility := by decide
  };
  let t1 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task1" (by native_decide)
    unit := { val := 1, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let t2 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task2" (by native_decide)
    unit := { val := 2, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let t3 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task3" (by native_decide)
    unit := { val := 2, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let pt1 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "ptask1" (by native_decide)
    unit := { val := 4, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let tasks : Finset (Task scales) := {
    t1,
    t2,
    t3,
    pt1
  };
  ({
    tasks := tasks
    prereqs := {
      nodes := tasks
      edges := {
        {
          src := { val := t1, property := by decide },
          dst := { val := t2, property := by decide },
        },
        {
          src := { val := t1, property := by decide },
          dst := { val := t3, property := by decide },
        },
        {
          src := { val := t2, property := by decide },
          dst := { val := t3, property := by decide },
        }
      }
    },
    parents := {
      nodes := tasks
      edges := {
        {
          src := { val := t3, property := by decide },
          dst := { val := pt1, property := by decide }
        }
      }
    }
    -- prove every edge strictly increases or decreases an order
    -- prove that given a cycle, this contradicts the previous
    prereqsAcyclic := by decide
    parentsAcyclic := by decide
    parentsTree := by decide
    parentsMonotonicUnit := by decide
  } : TaskSet scales)

end CpsatScheduler
