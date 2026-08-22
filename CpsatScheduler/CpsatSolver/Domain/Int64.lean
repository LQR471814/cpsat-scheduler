import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Star
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Tactic.Linarith.Frontend
import Mathlib.Tactic.NormNum.Ineq
import Mathlib.Algebra.Order.Ring.Star

import CpsatScheduler.CpsatSolver.Domain.Defs

namespace CpsatSolver

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

theorem Int64.proof_of_mul_left {a b : ℤ}
    (hb : b ≠ 0)
    (h₁ : ¬(a = (2 : ℤ) ^ 63 ∧ b = -1))
    (h : Int64.Nonoverflow (a * b)) :
    Int64.Nonoverflow a := by
  obtain ⟨hab_min, hab_max⟩ := h
  constructor
  · by_contra hna
    have ha' : a ≤ -((2 : ℤ) ^ 63) - 1 := by
      unfold min at hna
      omega
    cases lt_or_gt_of_ne hb with
    | inl hbneg =>
      have hb1 : b ≤ -1 := by omega
      have : (2 : ℤ) ^ 63 ≤ a * b := by nlinarith
      unfold max at hab_max
      omega
    | inr hbpos =>
      have hb1 : 1 ≤ b := by omega
      have : a * b ≤ -((2 : ℤ) ^ 63) - 1 := by nlinarith
      unfold min at hab_min
      omega
  · by_contra hna
    have ha' : (2 : ℤ) ^ 63 ≤ a := by
      unfold max at hna
      omega
    cases lt_or_gt_of_ne hb with
    | inl hbneg =>
      have hb1 : b ≤ -1 := by omega
      have hle : a * b ≤ (2 : ℤ) ^ 63 * b := by nlinarith
      have hle' : (2 : ℤ) ^ 63 * b ≤ -((2 : ℤ) ^ 63) := by nlinarith
      have heq_prod : a * b = -((2 : ℤ) ^ 63) := by
        unfold min at hab_min
        omega
      have hb_eq : b = -1 := by nlinarith
      have ha_eq : a = (2 : ℤ) ^ 63 := by nlinarith
      exact h₁ ⟨ha_eq, hb_eq⟩
    | inr hbpos =>
      have hb1 : 1 ≤ b := by omega
      have : (2 : ℤ) ^ 63 ≤ a * b := by nlinarith
      unfold max at hab_max
      omega

theorem Int64.proof_of_mul {a b : ℤ}
    (ha : a ≠ 0)
    (hb : b ≠ 0)
    (h₁ : ¬(a = (2 : ℤ) ^ 63 ∧ b = -1))
    (h₂ : ¬(a = -1 ∧ b = (2 : ℤ) ^ 63))
    (h : Int64.Nonoverflow (a * b)) :
    Int64.Nonoverflow a ∧ Int64.Nonoverflow b :=
  ⟨Int64.proof_of_mul_left hb h₁ h,
   Int64.proof_of_mul_left ha (by
     intro hba
     exact h₂ ⟨hba.2, hba.1⟩) (by simpa [mul_comm] using h)⟩

instance : Coe Int64 ℤ where
  coe proven := proven.val

def Int64.max' (a b : Int64) : Int64 :=
  if (a : ℤ) ≤ b then b else a

def Int64.min' (a b : Int64) : Int64 :=
  if (a : ℤ) ≤ b then a else b

theorem Int64.le_max'_left (a b : Int64) : (a : ℤ) ≤ Int64.max' a b := by
  unfold Int64.max'
  split_ifs with h
  · exact h
  · exact le_rfl

theorem Int64.le_max'_right (a b : Int64) : (b : ℤ) ≤ Int64.max' a b := by
  unfold Int64.max'
  split_ifs with h
  · exact le_rfl
  · exact le_of_not_ge h

theorem Int64.min'_le_left (a b : Int64) : (Int64.min' a b : ℤ) ≤ a := by
  unfold Int64.min'
  split_ifs with h
  · exact le_rfl
  · exact le_of_not_ge h

theorem Int64.min'_le_right (a b : Int64) : (Int64.min' a b : ℤ) ≤ b := by
  unfold Int64.min'
  split_ifs with h
  · exact h
  · exact le_rfl

end CpsatSolver

