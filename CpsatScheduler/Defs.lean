import CpsatScheduler.CpsatSolver.Defs

import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Interval
import Mathlib.Order.ConditionallyCompleteLattice.Basic

namespace CpsatScheduler

structure Timescales where
  scales : Finset ℤ
  hasAtomic : 1 ∈ scales
  divisibility : ∀ a b : ℤ, a ∈ scales → b ∈ scales → a ≥ b → a % b = 0
  intValid : ∀ a : ℤ, a ∈ scales → CpsatSolver.Int64.Proof a

structure Time (scale : Timescales) where
  coeff : ℤ
  unit : ℤ
  unitValid : unit ∈ scale.scales
  intValid : CpsatSolver.Int64.Proof (coeff * unit)

-- ensures no remainder when int division, preventing lossy division
private def Int.losslessDiv (a : ℤ) (b : ℤ) (_ : a % b = 0) :=
  a / b

-- converts from a lesser timescale to a greater one
def Time.convertUp {scale : Timescales}
  (src : Time scale)
  (newUnit : ℤ)
  (newUnitValid : newUnit ∈ scale.scales)
  (isGe : newUnit ≥ src.unit) :=
  let scaleFactor := Int.losslessDiv newUnit src.unit (
    scale.divisibility newUnit src.unit
      newUnitValid src.unitValid isGe
  );
  let newCoeff := src.coeff * scaleFactor;
  fun (intValid : CpsatSolver.Int64.Proof (newCoeff * newUnit)) =>
  ({
    coeff := newCoeff
    unit := newUnit
    unitValid := newUnitValid
    intValid := intValid
  } : Time scale)

-- converts from a greater timescale to a lesser one
def Time.convertDown {scale : Timescales}
  (src : Time scale)
  (newUnit : ℤ)
  (newUnitValid : newUnit ∈ scale.scales)
  (isLt : newUnit < src.unit) :=
  let newCoeff := Int.losslessDiv src.unit newUnit (
    scale.divisibility src.unit newUnit
      src.unitValid newUnitValid (Std.le_of_lt isLt)
  );
  fun (intValid : CpsatSolver.Int64.Proof (newCoeff * newUnit)) =>
  ({
    coeff := newCoeff
    unit := newUnit
    unitValid := newUnitValid
    intValid := intValid
  } : Time scale)

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

structure Task where
  name : CpsatSolver.Python.ValidName
  deriving DecidableEq

end CpsatScheduler
