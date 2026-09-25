import CpsatScheduler.CpsatSolver

import Mathlib.Data.Rat.Star

namespace CpsatScheduler

/-- Positive natural unit scale that fits in CP-SAT `Int64`. -/
structure UnitScale where
  mkRaw ::
  val : ℕ
  pos : 0 < val
  nonoverflow : CpsatSolver.Int64.Nonoverflow (val : ℤ)
deriving DecidableEq

def UnitScale.mk
  (val : ℕ)
  (pos : 0 < val := by decide)
  (nonoverflow
    : CpsatSolver.Int64.Nonoverflow (val : ℤ)
    := by decide) : UnitScale :=
  ⟨val, pos, nonoverflow⟩

instance : Coe UnitScale ℕ where
  coe u := u.val

instance : Coe UnitScale ℤ where
  coe u := u.val

instance : LE UnitScale where
  le a b := a.val ≤ b.val

instance : LT UnitScale where
  lt a b := a.val < b.val

@[simp] def UnitScale.atomic : UnitScale :=
  ⟨1, Nat.succ_pos 0, by decide⟩

abbrev Units.Divisibility (set : Finset UnitScale) :=
  ∀ a ∈ set, ∀ b ∈ set, b ≤ a → (b.val : ℕ) ∣ a.val

structure Units where
  set : Finset UnitScale
  has_atomic : UnitScale.atomic ∈ set
  divisibility : Units.Divisibility set

@[simp] def Units.of
  (set : Finset UnitScale)
  (has_atomic : UnitScale.atomic ∈ set := by decide)
  (divisibility : Units.Divisibility set := by decide) : Units :=
  ⟨set, has_atomic, divisibility⟩

@[simp] def Units.atomic (_units : Units) : UnitScale := UnitScale.atomic

/-- Solver-facing quantity indexed by its unit. -/
structure UnitValue (u : UnitScale) where
  coeff : CpsatSolver.Int64
deriving DecidableEq

/-- Rational scale/quantity for arbitrary unit arithmetic. -/
structure RatQuantity where
  coeff : ℤ
  scale : ℚ
  scale_pos : 0 < scale

/-- Nonnegative atomic-unit half-open horizon `[begin, end)`. -/
structure Horizon where
  mkRaw ::
  begin : ℕ
  end_ : ℕ
  begin_lt_end : begin < end_
  begin_safe : CpsatSolver.Int64.Nonoverflow begin
  end_safe : CpsatSolver.Int64.Nonoverflow end_

@[simp] def Horizon.mk
  (begin end_ : ℕ)
  (begin_lt_end : begin < end_ := by decide)
  (begin_safe : CpsatSolver.Int64.Nonoverflow begin := by decide)
  (end_safe : CpsatSolver.Int64.Nonoverflow end_ := by decide) :
    Horizon :=
  ⟨begin, end_, begin_lt_end, begin_safe, end_safe⟩

structure Timescales where
  units : Units
  horizon : Horizon

structure TaskId where
  val : Nat
deriving DecidableEq

structure Task (scales : Timescales) where
  id : TaskId
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

structure CostPoint where
  timeDemanded : CpsatSolver.Int64
  encodedCost : CpsatSolver.Int64
deriving DecidableEq

structure TaskCostTable {scales : Timescales} (task : Task scales) where
  points : Array CostPoint
  nonempty : 0 < points.size
  uniqueDemand :
    ∀ i j : Fin points.size, i ≠ j →
      points[i].timeDemanded ≠ points[j].timeDemanded
  demandBounds :
    ∀ p ∈ points,
      (0 : ℤ) ≤ p.timeDemanded.val ∧
      p.timeDemanded.val ≤ task.unit.val.val
  trueCost : ℤ → ℚ
  errorBound : ℚ
  error_nonneg : 0 ≤ errorBound
  encodedClose :
    ∀ p ∈ points,
      |trueCost p.timeDemanded.val - p.encodedCost.val| ≤ errorBound

inductive TaskRel where
  | bucketContainedIn
  | prerequisite
deriving DecidableEq

end CpsatScheduler
