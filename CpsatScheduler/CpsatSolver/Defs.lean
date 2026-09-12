import CpsatScheduler.CpsatSolver.Python
import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs
import Mathlib.Order.Defs.LinearOrder

import Mathlib

namespace CpsatSolver

abbrev Int64.min : ℤ := -(2 : ℤ)^63
abbrev Int64.max : ℤ := (2 : ℤ)^63 - 1
abbrev Int64.Nonoverflow (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

/-- Euclidean division by a positive integer preserves the Int64 range. -/
theorem Int64.proof_ediv_of_pos {a divisor : ℤ}
    (ha : Int64.Nonoverflow a) (hdivisor : 0 < divisor) :
    Int64.Nonoverflow (a / divisor) := by
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
    (h : Int64.Nonoverflow (a * b)) :
    Int64.Nonoverflow a := by
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
    (h : Int64.Nonoverflow (a * b)) :
    Int64.Nonoverflow a ∧ Int64.Nonoverflow b :=
  ⟨Int64.proof_of_mul_left hb h₁ h,
   Int64.proof_of_mul_left ha (by
     intro hba
     exact h₂ ⟨hba.2, hba.1⟩) (by simpa [mul_comm] using h)⟩

structure Int64 where
  val : ℤ
  nonoverflow : Int64.Nonoverflow val
deriving DecidableEq

instance : Coe Int64 ℤ where
  coe proven := proven.val

-- this is a closed interval
structure Interval where
  left : Int64
  right : Int64
  left_le_right : (left : ℤ) ≤ right
deriving DecidableEq

noncomputable def Interval.set (i : Interval) : Finset ℤ :=
  Finset.Icc (i.left : ℤ) i.right

def Interval.fromValue (v : Int64) : { x : Interval // x.set = {v.val} } :=
  {
    val := {
      left := v
      right := v
      left_le_right := by exact Int.le_refl v.val
    }
    property := Finset.Icc_self v.val
  }

instance : Membership Int64 Interval where
  mem i m := (m : ℤ) ≥ i.left ∧ (m : ℤ) ≤ i.right

def Interval.neg (i : Interval)
  (h :
    Int64.Nonoverflow (-i.right : ℤ) ∧
    Int64.Nonoverflow (-i.left : ℤ))
  : { x : Interval // x.set = i.set.map (Equiv.neg ℤ).toEmbedding } :=
  {
    val := {
      left := {
        val := -(i.right : ℤ),
        nonoverflow := h.left
      }
      right := {
        val := -(i.left : ℤ),
        nonoverflow := h.right
      }
      left_le_right := by
        refine Int.neg_le_neg i.left_le_right
    }
    property := by
      ext x
      simp [Interval.set]
      omega
  }

def Interval.ofBounds (left right : ℤ)
    (nonoverflow : Int64.Nonoverflow left ∧ Int64.Nonoverflow right)
    (left_le_right : left ≤ right) :
    { x : Interval // x.set = Finset.Icc left right } :=
  {
    val := {
      left := { val := left, nonoverflow := nonoverflow.1 }
      right := { val := right, nonoverflow := nonoverflow.2 }
      left_le_right := left_le_right
    }
    property := rfl
  }

def Interval.add (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow ((a.left : ℤ) + b.left) ∧
      Int64.Nonoverflow ((a.right : ℤ) + b.right)) :
    { x : Interval //
      x.set = Finset.Icc
        ((a.left : ℤ) + b.left)
        ((a.right : ℤ) + b.right) } :=
  Interval.ofBounds
    ((a.left : ℤ) + b.left)
    ((a.right : ℤ) + b.right)
    nonoverflow
    (add_le_add a.left_le_right b.left_le_right)

def Interval.sub (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow ((a.left : ℤ) - b.right) ∧
      Int64.Nonoverflow ((a.right : ℤ) - b.left)) :
    { x : Interval //
      x.set = Finset.Icc
        ((a.left : ℤ) - b.right)
        ((a.right : ℤ) - b.left) } :=
  Interval.ofBounds
    ((a.left : ℤ) - b.right)
    ((a.right : ℤ) - b.left)
    nonoverflow
    (by linarith [a.left_le_right, b.left_le_right])

def Interval.mulLower (a b : Interval) : ℤ :=
  min
    (min ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right))
    (min ((a.right : ℤ) * b.left) ((a.right : ℤ) * b.right))

def Interval.mulUpper (a b : Interval) : ℤ :=
  max
    (max ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right))
    (max ((a.right : ℤ) * b.left) ((a.right : ℤ) * b.right))

theorem Interval.mulLower_le_mulUpper (a b : Interval) :
    a.mulLower b ≤ a.mulUpper b := by
  unfold mulLower mulUpper
  calc
    min (min ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right))
        (min ((a.right : ℤ) * b.left) ((a.right : ℤ) * b.right))
        ≤ (a.left : ℤ) * b.left :=
          (min_le_left _ _).trans (min_le_left _ _)
    _ ≤ max ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right) := le_max_left _ _
    _ ≤ max (max ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right))
        (max ((a.right : ℤ) * b.left) ((a.right : ℤ) * b.right)) := le_max_left _ _

def Interval.mul (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow (a.mulLower b) ∧
      Int64.Nonoverflow (a.mulUpper b)) :
    { x : Interval //
      x.set = Finset.Icc (a.mulLower b) (a.mulUpper b) } :=
  Interval.ofBounds
    (a.mulLower b)
    (a.mulUpper b)
    nonoverflow
    (a.mulLower_le_mulUpper b)

def Interval.divLower (a b : Interval) : ℤ :=
  min ((a.left : ℤ) / b.left) ((a.right : ℤ) / b.right)

def Interval.divUpper (a b : Interval) : ℤ :=
  max ((a.left : ℤ) / b.left) ((a.right : ℤ) / b.right)

def Interval.div (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow (a.divLower b) ∧
      Int64.Nonoverflow (a.divUpper b)) :
    { x : Interval //
      x.set = Finset.Icc (a.divLower b) (a.divUpper b) } :=
  Interval.ofBounds
    (a.divLower b)
    (a.divUpper b)
    nonoverflow
    min_le_max

def Interval.intersect (a b : Interval) left_le_right :=
  let fst := if (a.left : ℤ) ≤ b.left then a else b;
  let snd := if fst = a then b else a;
  ({
    left := {
      val := max fst.left (snd.left : ℤ)
      nonoverflow := max_ind
        (fun _ => fst.left.nonoverflow)
        (fun _ => snd.left.nonoverflow)
    }
    right := {
      val := min fst.right (snd.right : ℤ)
      nonoverflow := min_ind
        (fun _ => fst.right.nonoverflow)
        (fun _ => snd.right.nonoverflow)
    }
    left_le_right := left_le_right
  } : Interval)

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

instance : Var IntVar where
  name var := var.name

inductive LinearExpr where
  | fromVar (value : IntVar)
  | fromConst (value : Int64)
  | fromNeg (a : LinearExpr) (domain : CpsatSolver.Interval)
  | fromAdd (a b : LinearExpr) (domain : CpsatSolver.Interval)
  | fromMul (a b : LinearExpr) (domain : CpsatSolver.Interval)
  | fromSub (a b : LinearExpr) (domain : CpsatSolver.Interval)
deriving DecidableEq

def LinearExpr.domain (l : LinearExpr) : CpsatSolver.Interval :=
  match l with
  | .fromVar int => int.domain
  | .fromConst const => Interval.fromValue const
  | .fromNeg _ domain => domain
  | .fromAdd _ _ domain => domain
  | .fromMul _ _ domain => domain
  | .fromSub _ _ domain => domain

structure FixedSizeIntervalVar where
  -- name is also the identifier
  name : CpsatSolver.Python.ValidName
  start : LinearExpr
  size : Int64
  nonzero : size ≥ (0 : ℤ)
deriving DecidableEq

instance : Var FixedSizeIntervalVar where
  name var := var.name


inductive BoundedLinearExpr.Op where
  | eq | neq | gt | gte | lt | lte
deriving DecidableEq

def BoundedLinearExpr.NoContradict
  (op : BoundedLinearExpr.Op) (left right : LinearExpr) : Prop :=
  let L := left.domain;
  let R := right.domain;
  match op with
  -- ¬ (left ∩ right = ∅)
  | .eq => ∃ x : ℤ, (L.left : ℤ) ≤ x ∧ x ≤ L.right ∧
      (R.left : ℤ) ≤ x ∧ x ≤ R.right
  -- ¬ (left = right)
  | .neq => L ≠ R
  -- ¬ (∀ x ∈ left, ∀ y ∈ right, x ≤ y)
  | .gt => ∃ x ∈ L, ∃ y ∈ R, (x : ℤ) > y
  -- ¬ (∀ x ∈ left, ∀ y ∈ right, x < y)
  | .gte => ∃ x ∈ L, ∃ y ∈ R, (x : ℤ) ≥ y
  -- ¬ (∀ x ∈ left, ∀ y ∈ right, x ≥ y)
  | .lt => ∃ x ∈ L, ∃ y ∈ R, (x : ℤ) < y
  -- ¬ (∀ x ∈ left, ∀ y ∈ right, x > y)
  | .lte => ∃ x ∈ L, ∃ y ∈ R, (x : ℤ) ≤ y

-- TODO: determine whether int variable definitions are necessary
-- 1. in scenarios where an int var = linear expr, they should be unnecessary
-- 2. "add_max_equality" or "add_sum" require intermediate int var to store result
--
-- in general?
--
-- expressions whose values need to be modulated with constraints

-- BoundedLinearExpr is LinearExpr with some bounding operators applied on it
-- (e.g. >, <, ==)
structure BoundedLinearExpr where
  op : BoundedLinearExpr.Op
  left : LinearExpr
  right : LinearExpr
  no_contradict : BoundedLinearExpr.NoContradict op left right
deriving DecidableEq

inductive Constraint.Enforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))
deriving DecidableEq

inductive Constraint.Variant where
  /-- Corresponds to <model>.add -/
  | bounded_linear (expr : CpsatSolver.BoundedLinearExpr)
  /-- Corresponds to <model>.add_max_equality -/
  | max_equality (target : LinearExpr) (exprs : Array LinearExpr)
  /-- Corresponds to <model>.add_cumulative -/
  | cumulative
    (intervals : Array CpsatSolver.FixedSizeIntervalVar)
    (demands : Array LinearExpr)
    (capacity : LinearExpr)
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
