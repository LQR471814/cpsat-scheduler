import CpsatScheduler.CpsatSolver.Helpers

import Mathlib.Data.Rat.Star

set_option linter.mathlibStandardSet false

namespace CpsatScheduler

/-- Positive natural unit scale that fits in CP-SAT `Int64`. -/
structure UnitScale where
  val : ℕ
  pos : 0 < val
  nonoverflow : CpsatSolver.Int64.Nonoverflow (val : ℤ)
deriving DecidableEq

instance : Coe UnitScale ℕ where
  coe u := u.val

instance : Coe UnitScale ℤ where
  coe u := u.val

instance : LE UnitScale where
  le a b := a.val ≤ b.val

instance : LT UnitScale where
  lt a b := a.val < b.val

instance : DecidableLE UnitScale :=
  fun a b => inferInstanceAs (Decidable (a.val ≤ b.val))

instance : DecidableLT UnitScale :=
  fun a b => inferInstanceAs (Decidable (a.val < b.val))

def UnitScale.atomic : UnitScale :=
  ⟨1, Nat.succ_pos 0, by decide⟩

structure Units where
  set : Finset UnitScale
  has_atomic : UnitScale.atomic ∈ set
  divisibility :
    ∀ a ∈ set, ∀ b ∈ set, b ≤ a → (b.val : ℕ) ∣ a.val

def Units.atomic (_units : Units) : UnitScale := UnitScale.atomic

/-- Solver-facing quantity indexed by its unit. -/
structure UnitValue (u : UnitScale) where
  coeff : CpsatSolver.Int64
deriving DecidableEq

def UnitValue.add {u : UnitScale} (a b : UnitValue u)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val + b.coeff.val)) :
    UnitValue u :=
  ⟨⟨a.coeff.val + b.coeff.val, nonoverflow⟩⟩

def UnitValue.sub {u : UnitScale} (a b : UnitValue u)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val - b.coeff.val)) :
    UnitValue u :=
  ⟨⟨a.coeff.val - b.coeff.val, nonoverflow⟩⟩

def UnitValue.nsmul {u : UnitScale} (k : ℤ) (a : UnitValue u)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (k * a.coeff.val)) :
    UnitValue u :=
  ⟨⟨k * a.coeff.val, nonoverflow⟩⟩

/-- Exact division by a positive constant that divides the coefficient. -/
def UnitValue.edivConst {u : UnitScale} (a : UnitValue u) (d : ℕ)
    (_hd : 0 < d)
    (_divides : (d : ℤ) ∣ a.coeff.val)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val / d)) :
    UnitValue u :=
  ⟨⟨a.coeff.val / d, nonoverflow⟩⟩

/-- Truncating division toward zero by a positive constant. -/
def UnitValue.tdivConst {u : UnitScale} (a : UnitValue u) (d : ℕ)
    (_hd : 0 < d)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (Int.tdiv a.coeff.val d)) :
    UnitValue u :=
  ⟨⟨Int.tdiv a.coeff.val d, nonoverflow⟩⟩

/-- Rational scale/quantity for arbitrary unit arithmetic. -/
structure RatQuantity where
  coeff : ℤ
  scale : ℚ
  scale_pos : 0 < scale

def RatQuantity.ofUnitValue {u : UnitScale} (v : UnitValue u) : RatQuantity :=
  {
    coeff := v.coeff.val
    scale := u.val
    scale_pos := by
      exact Nat.cast_pos.mpr u.pos
  }

def RatQuantity.mul (a b : RatQuantity) : RatQuantity :=
  {
    coeff := a.coeff * b.coeff
    scale := a.scale * b.scale
    scale_pos := mul_pos a.scale_pos b.scale_pos
  }

/-- Quotient of rational quantities. The scale stays positive by folding the
sign of `b.coeff` into the result coefficient. -/
def RatQuantity.div (a b : RatQuantity) (hb : b.coeff ≠ 0) : RatQuantity :=
  {
    coeff := a.coeff * Int.sign b.coeff
    scale := a.scale / ((b.coeff.natAbs : ℚ) * b.scale)
    scale_pos := by
      have habs : (0 : ℚ) < (b.coeff.natAbs : ℚ) :=
        Nat.cast_pos.mpr (Int.natAbs_pos.mpr hb)
      exact div_pos a.scale_pos (mul_pos habs b.scale_pos)
  }

def RatQuantity.lower {u : UnitScale} (q : RatQuantity)
    (n : ℤ)
    (_hn : (q.coeff : ℚ) * q.scale = (n : ℚ) * (u.val : ℚ))
    (safe : CpsatSolver.Int64.Nonoverflow n) :
    UnitValue u :=
  ⟨⟨n, safe⟩⟩

/-- Nonnegative atomic-unit half-open horizon `[begin, end)`. -/
structure Horizon where
  begin : ℕ
  end_ : ℕ
  begin_lt_end : begin < end_
  begin_safe : CpsatSolver.Int64.Nonoverflow begin
  end_safe : CpsatSolver.Int64.Nonoverflow end_

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

/-- Nonnegative task start in bucket-index coordinates. -/
structure TaskStart (scales : Timescales) where
  task : Task scales
  var : CpsatSolver.IntVar
  unit_eq : var.domain = task.startDomain

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

theorem true_le_encoded_add_err {t e ε : ℚ} (h : |t - e| ≤ ε) : t ≤ e + ε := by
  have := (abs_le.mp h).2
  linarith

theorem encoded_le_true_add_err {t e ε : ℚ} (h : |t - e| ≤ ε) : e ≤ t + ε := by
  have := (abs_le.mp h).1
  linarith

theorem sum_true_le_sum_enc_add_err (pairs : List (ℚ × ℚ × ℚ))
    (hclose : ∀ p ∈ pairs, |p.1 - p.2.1| ≤ p.2.2) :
    (pairs.map (·.1)).sum ≤ (pairs.map (·.2.1)).sum + (pairs.map (·.2.2)).sum := by
  induction pairs with
  | nil => simp
  | cons p rest ih =>
    rcases p with ⟨t, e, ε⟩
    have hrest : ∀ q ∈ rest, |q.1 - q.2.1| ≤ q.2.2 :=
      fun q hq => hclose q (List.mem_cons.mpr (Or.inr hq))
    have ht := true_le_encoded_add_err
      (hclose ⟨t, e, ε⟩ List.mem_cons_self)
    have ih' := ih hrest
    simp [List.sum_cons] at ih' ⊢
    linarith

theorem sum_enc_le_sum_true_add_err (pairs : List (ℚ × ℚ × ℚ))
    (hclose : ∀ p ∈ pairs, |p.1 - p.2.1| ≤ p.2.2) :
    (pairs.map (·.2.1)).sum ≤ (pairs.map (·.1)).sum + (pairs.map (·.2.2)).sum := by
  induction pairs with
  | nil => simp
  | cons p rest ih =>
    rcases p with ⟨t, e, ε⟩
    have hrest : ∀ q ∈ rest, |q.1 - q.2.1| ≤ q.2.2 :=
      fun q hq => hclose q (List.mem_cons.mpr (Or.inr hq))
    have ht := encoded_le_true_add_err
      (hclose ⟨t, e, ε⟩ List.mem_cons_self)
    have ih' := ih hrest
    simp [List.sum_cons] at ih' ⊢
    linarith

/-- If an encoded-cost vector is optimal among encoded alternatives for the same
tasks, the corresponding true total is at most the true alternative plus twice
the summed error bounds. No claim is made for merely feasible responses. -/
theorem encodedOptimal_trueCost_le
    (chosen alt : List (ℚ × ℚ × ℚ))
    (hclose₀ : ∀ p ∈ chosen, |p.1 - p.2.1| ≤ p.2.2)
    (hclose₁ : ∀ p ∈ alt, |p.1 - p.2.1| ≤ p.2.2)
    (herr : (chosen.map (·.2.2)).sum = (alt.map (·.2.2)).sum)
    (hopt : (chosen.map (·.2.1)).sum ≤ (alt.map (·.2.1)).sum) :
    (chosen.map (·.1)).sum ≤ (alt.map (·.1)).sum + 2 * (chosen.map (·.2.2)).sum := by
  have hch := sum_true_le_sum_enc_add_err chosen hclose₀
  have halt := sum_enc_le_sum_true_add_err alt hclose₁
  linarith

/-- Lossless normalization of two operands to their minimum/finer unit. -/
def finer (a b : UnitScale) : UnitScale :=
  if a.val ≤ b.val then a else b

theorem UnitScale.ratio_nonoverflow (u v : UnitScale) :
    CpsatSolver.Int64.Nonoverflow ((u.val / v.val : ℕ) : ℤ) := by
  have hu := u.nonoverflow
  have hnn : (0 : ℤ) ≤ ((u.val / v.val : ℕ) : ℤ) := Nat.cast_nonneg _
  have hle : ((u.val / v.val : ℕ) : ℤ) ≤ (u.val : ℤ) := by
    exact_mod_cast Nat.div_le_self u.val v.val
  constructor
  · have hmin : CpsatSolver.Int64.min ≤ 0 := by decide
    exact le_trans hmin hnn
  · exact le_trans hle hu.2

def UnitScale.exactRatio (u v : UnitScale) (_hv : v.val ∣ u.val) :
    CpsatSolver.Int64 :=
  ⟨u.val / v.val, UnitScale.ratio_nonoverflow u v⟩

namespace UnitAware

structure IntVar (u : UnitScale) where
  var : CpsatSolver.IntVar

structure LinearExpr (u : UnitScale) where
  bounds : CpsatSolver.Bounds
  cpsat : CpsatSolver.LinearExpr bounds

def LinearExpr.var {u : UnitScale} (v : IntVar u) : LinearExpr u :=
  { bounds := v.var.domain.hull, cpsat := CpsatSolver.LinearExpr.var v.var }

def LinearExpr.add {u : UnitScale} (a b : LinearExpr u)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((a.bounds.left : ℤ) + b.bounds.left) ∧
      CpsatSolver.Int64.Nonoverflow ((a.bounds.right : ℤ) + b.bounds.right)) :
    LinearExpr u :=
  {
    bounds := a.bounds.add b.bounds nonoverflow
    cpsat := CpsatSolver.LinearExpr.add a.cpsat b.cpsat nonoverflow
  }

def LinearExpr.sub {u : UnitScale} (a b : LinearExpr u)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((a.bounds.left : ℤ) - b.bounds.right) ∧
      CpsatSolver.Int64.Nonoverflow ((a.bounds.right : ℤ) - b.bounds.left)) :
    LinearExpr u :=
  {
    bounds := a.bounds.sub b.bounds nonoverflow
    cpsat := CpsatSolver.LinearExpr.sub a.cpsat b.cpsat nonoverflow
  }

/-- Exact conversion from a coarser unit `u` to a finer unit `v` by multiplying
by the integral scale ratio `u/v`. -/
def LinearExpr.rescaleExact {u v : UnitScale}
    (e : LinearExpr u) (hv : v.val ∣ u.val)
    (mul_nonoverflow :
      CpsatSolver.Int64.Nonoverflow
        (e.bounds.mulLower (CpsatSolver.Interval.fromValue (UnitScale.exactRatio u v hv))) ∧
      CpsatSolver.Int64.Nonoverflow
        (e.bounds.mulUpper (CpsatSolver.Interval.fromValue (UnitScale.exactRatio u v hv)))) :
    LinearExpr v :=
  let ratio := UnitScale.exactRatio u v hv
  {
    bounds := e.bounds.mul (CpsatSolver.Interval.fromValue ratio) mul_nonoverflow
    cpsat := CpsatSolver.LinearExpr.mul e.cpsat ratio mul_nonoverflow
  }

structure FixedSizeInterval (u : UnitScale) where
  start : LinearExpr u
  size : CpsatSolver.Int64
  size_nonneg : (0 : ℤ) ≤ size

structure CumulativeItem (timeline demandU : UnitScale) where
  interval : FixedSizeInterval timeline
  demand : LinearExpr demandU

end UnitAware

inductive TaskRel where
  | bucketContainedIn
  | prerequisite
deriving DecidableEq

end CpsatScheduler
