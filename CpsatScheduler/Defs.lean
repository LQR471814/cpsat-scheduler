import CpsatScheduler.CpsatSolver.Defs

import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Interval
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Combinatorics.Digraph.Basic
import Mathlib.Data.Finset.Sort

import CpsatScheduler.Util.Finset
import CpsatScheduler.Util.Graphs

namespace CpsatScheduler

structure Units where
  set : Finset ℤ
  nonzero : ∀ u : set, u.val ≥ 1
  has_atomic : 1 ∈ set
  divisibility : ∀ a b : set, a ≥ b → (a : ℤ) % b = 0
  nonoverflow : ∀ a : set, CpsatSolver.Int64.Proof a
  deriving DecidableEq

abbrev Units.max (units : Units) : units.set :=
  have nonempty := Exists.intro 1 units.has_atomic;
  {
    val := units.set.max' nonempty,
    property := Finset.max'_mem units.set nonempty
  }

abbrev Units.atomic (units : Units) : units.set := {
  val := 1, property := units.has_atomic
}

structure Horizon (units : Units) where
  beginning : ℤ
  ending : ℤ
  begin_ge_0 : beginning ≥ 0
  end_ge_0 : ending ≥ 0
  begin_lt_end : beginning < ending
  begin_divides_max_unit : beginning % units.max = 0
  end_divides_max_unit : ending % units.max = 0
  begin_nonoverflow : CpsatSolver.Int64.Proof (beginning * units.max)
  end_nonoverflow : CpsatSolver.Int64.Proof (ending * units.max)
  deriving DecidableEq

structure Timescales where
  units : Units
  horizon : Horizon units
  deriving DecidableEq

structure Time (scales : Timescales) where
  coeff : ℤ
  unit : scales.units.set
  intValid : CpsatSolver.Int64.Proof (coeff * unit)
  deriving DecidableEq

theorem Timescales.all_ge_atomic {scales : Timescales}
  : ∀ u : scales.units.set, scales.units.atomic ≤ u :=
    scales.units.nonzero

-- ensures no remainder when int division, preventing lossy division
private abbrev Int.losslessDiv (a : ℤ) (b : ℤ) (_ : a % b = 0) :=
  a / b

-- converts from a lesser timescale to a greater one
def Time.convertUp {scales : Timescales}
  (src : Time scales)
  (newUnit : scales.units.set)
  (isGe : newUnit ≥ src.unit) :=
  let scaleFactor := Int.losslessDiv
    newUnit src.unit
    (scales.units.divisibility newUnit src.unit isGe);
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
  (newUnit : scales.units.set)
  (isLe : newUnit ≤ src.unit) :=
  have src_divides_new := scales.units.divisibility src.unit newUnit isLe;
  let newCoeff := Int.losslessDiv src.unit newUnit
    src_divides_new;
  have mul_canceled : newCoeff * newUnit = src.unit :=
    Int.ediv_mul_cancel_of_dvd
      (Int.dvd_of_emod_eq_zero src_divides_new);
  have mul_non_overflow : CpsatSolver.Int64.Proof (newCoeff * newUnit) :=
    Eq.subst (Eq.symm mul_canceled)
      (motive := fun p => CpsatSolver.Int64.Proof p)
      (scales.units.nonoverflow src.unit);
  ({
    coeff := newCoeff
    unit := newUnit
    intValid := mul_non_overflow
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

inductive CostConfiguration (scales : Timescales) where
  | duration (value : Time scales)
  deriving DecidableEq

structure Task (scales : Timescales) where
  name : CpsatSolver.Python.ValidName
  unit : scales.units.set
  startAfter : Option ({ t : Time scales // t.unit = unit })
  startBefore : Option ({ t : Time scales // t.unit = unit })
  deriving DecidableEq

structure TaskSet (scales : Timescales) where
  tasks : Finset (Task scales)
  prereqs : FinDigraph (Task scales)
  prereqsAcyclic : prereqs.IsAcyclic
  -- for any edge, src is the child & dst is the parent
  parents : FinDigraph (Task scales)
  parentsAcyclic : parents.IsAcyclic
  parentsTree : parents.IsTree
  parentsMonotonicUnit :
    ∀ e : parents.edges, e.val.src.val.unit.val < e.val.dst.val.unit.val

#check
  let scales : Timescales := {
    units := {
      set := { 1, 2, 4, 8 }
      nonzero := by decide
      nonoverflow := by decide
      has_atomic := by decide
      divisibility := by decide
    }
    horizon := {
      beginning := 0
      ending := 32
      begin_ge_0 := by decide
      end_ge_0 := by decide
      begin_lt_end := by decide
      begin_divides_max_unit := by decide
      end_divides_max_unit := by decide
      begin_nonoverflow := by decide
      end_nonoverflow := by decide
    }
  };
  let t1 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task1" (by decide)
    unit := { val := 1, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let t2 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task2" (by decide)
    unit := { val := 2, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let t3 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task3" (by decide)
    unit := { val := 2, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let pt1 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "ptask1" (by decide)
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
  let set : TaskSet scales := {
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
  };
  set

end CpsatScheduler
