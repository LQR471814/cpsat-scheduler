import CpsatScheduler.CpsatSolver

import Mathlib.Data.Rat.Star

namespace CpsatScheduler


/-- Rational scale/quantity for arbitrary unit arithmetic. -/
structure RatQuantity where
  coeff : ℤ
  scale : ℚ
  scale_pos : 0 < scale

/-- Nonnegative atomic-unit half-open horizon `[begin, end`. -/
structure Horizon where
  mkRaw ::
  begin : ℕ
  end_ : ℕ
  begin_lt_end : begin < end_
  begin_safe : CpsatSolver.Int64.Nonoverflow begin
  end_safe : CpsatSolver.Int64.Nonoverflow end_

def Horizon.mk
  (begin end_ : ℕ)
  (begin_lt_end : begin < end_ := by native_decide)
  (begin_safe : CpsatSolver.Int64.Nonoverflow begin := by native_decide)
  (end_safe : CpsatSolver.Int64.Nonoverflow end_ := by native_decide) :
    Horizon :=
  ⟨begin, end_, begin_lt_end, begin_safe, end_safe⟩

structure Timescales where
  units : Units
  horizon : Horizon

structure TaskId where
  val : Nat
deriving DecidableEq

structure Task (scales : Timescales) where
  label : Option String := none
  unit : { u : UnitScale // u ∈ scales.units.set }
  startDomain : CpsatSolver.NonemptyDomain
  /-- Every permitted bucket `[k*u,(k+1)*u)` fits in the horizon with `Int64`
  boundaries. -/
  bucketsFitHorizon :
    ∀ k : ℤ, k ∈ startDomain.domain →
      (scales.horizon.begin : ℤ) ≤ k * unit.val.val ∧
      (k + 1) * unit.val.val ≤ scales.horizon.end_ ∧
      CpsatSolver.Int64.Nonoverflow (k * unit.val.val) ∧
      CpsatSolver.Int64.Nonoverflow ((k + 1) * unit.val.val)

end CpsatScheduler
