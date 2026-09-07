import CpsatScheduler.CpsatSolver.Python
import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs

import Mathlib

namespace CpsatSolver

abbrev Int64.min : ℤ := -(2 : ℤ)^63
abbrev Int64.max : ℤ := (2 : ℤ)^63 - 1
abbrev Int64.Proof (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

/-- Euclidean division by a positive integer preserves the Int64 range. -/
theorem Int64.proof_ediv_of_pos {a divisor : ℤ}
    (ha : Int64.Proof a) (hdivisor : 0 < divisor) :
    Int64.Proof (a / divisor) := by
  constructor
  · change Int64.min ≤ a / divisor
    rw [Int.le_ediv_iff_mul_le hdivisor]
    unfold Int64.min
    nlinarith [ha.1]
  · rw [Int.ediv_le_iff_le_mul hdivisor]
    unfold Int64.max
    nlinarith [ha.2]

/-- If a nonzero integer `b` multiplies `a` into the `Int64` range, then `a` itself
is in range, except for the overflow pair `a = 2^63`, `b = -1`. -/
theorem Int64.proof_of_mul_left {a b : ℤ}
    (hb : b ≠ 0)
    (h₁ : ¬(a = (2 : ℤ)^63 ∧ b = -1))
    (h : Int64.Proof (a * b)) :
    Int64.Proof a := by
  obtain ⟨hab_min, hab_max⟩ := h
  constructor
  · -- `min ≤ a`
    by_contra hna
    have ha' : a ≤ -((2 : ℤ)^63) - 1 := by
      unfold min at hna
      omega
    cases lt_or_gt_of_ne hb with
    | inl hbneg =>
      have hb1 : b ≤ -1 := by omega
      have : (2 : ℤ)^63 ≤ a * b := by nlinarith
      unfold max at hab_max
      omega
    | inr hbpos =>
      have hb1 : 1 ≤ b := by omega
      have : a * b ≤ -((2 : ℤ)^63) - 1 := by nlinarith
      unfold min at hab_min
      omega
  · -- `a ≤ max`
    by_contra hna
    have ha' : (2 : ℤ)^63 ≤ a := by
      unfold max at hna
      omega
    cases lt_or_gt_of_ne hb with
    | inl hbneg =>
      have hb1 : b ≤ -1 := by omega
      have hle : a * b ≤ (2 : ℤ)^63 * b := by nlinarith
      have hle' : (2 : ℤ)^63 * b ≤ -((2 : ℤ)^63) := by nlinarith
      have heq_prod : a * b = -((2 : ℤ)^63) := by
        unfold min at hab_min
        omega
      have hb_eq : b = -1 := by nlinarith
      have ha_eq : a = (2 : ℤ)^63 := by nlinarith
      exact h₁ ⟨ha_eq, hb_eq⟩
    | inr hbpos =>
      have hb1 : 1 ≤ b := by omega
      have : (2 : ℤ)^63 ≤ a * b := by nlinarith
      unfold max at hab_max
      omega

theorem Int64.proof_of_mul {a b : ℤ}
    (ha : a ≠ 0)
    (hb : b ≠ 0)
    (h₁ : ¬(a = (2 : ℤ)^63 ∧ b = -1))
    (h₂ : ¬(a = -1 ∧ b = (2 : ℤ)^63))
    (h : Int64.Proof (a * b)) :
    Int64.Proof a ∧ Int64.Proof b :=
  ⟨Int64.proof_of_mul_left hb h₁ h,
   Int64.proof_of_mul_left ha (by
     intro hba
     exact h₂ ⟨hba.2, hba.1⟩) (by simpa [mul_comm] using h)⟩

structure Int64.Proven where
  val : ℤ
  proof : Int64.Proof val
  deriving DecidableEq

instance : Coe Int64.Proven ℤ where
  coe proven := proven.val

structure Interval where
  min : ℤ
  max : ℤ
  deriving DecidableEq

def Interval.Proof (it : Interval) :=
  it.min ≤ it.max ∧
  Int64.Proof it.min ∧
  Int64.Proof it.max


class Var (α : Type) where
  name (var : α) : CpsatSolver.Python.ValidName


/-- BoolVar is a boolean variable -/
structure BoolVar where
  name : CpsatSolver.Python.ValidName
  deriving DecidableEq

instance : Var BoolVar where
  name var := var.name


-- BoolLit is a CpsatSolver.BoolVar or its negation
inductive BoolLit where
  | var (v : CpsatSolver.BoolVar)
  | neg (v : CpsatSolver.BoolVar)
  deriving DecidableEq


/-- IntVar is an integer variable bounded to a finite domain -/
structure IntVar where
  /-- name is the identifier of the variable -/
  name : CpsatSolver.Python.ValidName
  domain : CpsatSolver.Interval
  deriving DecidableEq

def IntVar.Proof (var : IntVar) :=
  Interval.Proof var.domain

instance : Var IntVar where
  name var := var.name

mutual

/-- LinearExpr is a linear expr that evaluates to an ℤ -/
inductive LinearExpr.Op where
  | var (value : CpsatSolver.IntVar) (H : CpsatSolver.IntVar.Proof value)
  | const (value : ℤ) (H : CpsatSolver.Int64.Proof value)
  | neg (a : LinearExpr.Proven)
  | add (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | mul (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | sub (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  deriving DecidableEq

structure LinearExpr.Proof where
  domain : CpsatSolver.Interval
  domainValid : CpsatSolver.Interval.Proof domain
  deriving DecidableEq

structure LinearExpr.Proven where
  op : LinearExpr.Op
  proof : LinearExpr.Proof
  deriving DecidableEq

end


structure FixedSizeIntervalVar where
  -- name is also the identifier
  name : CpsatSolver.Python.ValidName
  start : LinearExpr.Proven
  size : ℕ
  deriving DecidableEq

instance : Var FixedSizeIntervalVar where
  name var := var.name


inductive BoundedLinearExpr.Op where
  | eq | neq | gt | gte | lt | lte
  deriving DecidableEq

-- BoundedLinearExpr is LinearExpr with some bounding operators applied on it
-- (e.g. >, <, ==)
structure BoundedLinearExpr where
  op : BoundedLinearExpr.Op
  left : LinearExpr.Proven
  right : LinearExpr.Proven
  deriving DecidableEq

inductive Constraint.Enforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))
  deriving DecidableEq

inductive Constraint.Variant where
  /-- Corresponds to <model>.add -/
  | bounded_linear (expr : CpsatSolver.BoundedLinearExpr)
  /-- Corresponds to <model>.add_max_equality -/
  | max_equality (target : LinearExpr.Proven) (exprs : Array LinearExpr.Proven)
  /-- Corresponds to <model>.add_cumulative -/
  | cumulative
    (intervals : Array CpsatSolver.FixedSizeIntervalVar)
    (demands : Array LinearExpr.Proven)
    (capacity : LinearExpr.Proven)
  /-- Corresponds to <model>.add_bool_and -/
  | bool_and (terms : Array CpsatSolver.BoolLit)
  /-- Corresponds to <model>.add_bool_or -/
  | bool_or (terms : Array CpsatSolver.BoolLit)
  /-- Corresponds to <model>.add_implication -/
  | implication (src : CpsatSolver.BoolLit) (dst : CpsatSolver.BoolLit)
  deriving DecidableEq

structure Constraint where
  name : Python.ValidName
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant
  deriving DecidableEq

end CpsatSolver
