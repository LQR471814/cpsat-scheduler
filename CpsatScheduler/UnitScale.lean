import CpsatScheduler.Defs

import Mathlib.Data.Finset.Sort

namespace CpsatScheduler

instance : DecidableLE UnitScale :=
  fun a b => inferInstanceAs (Decidable (a.val ≤ b.val))

instance : DecidableLT UnitScale :=
  fun a b => inferInstanceAs (Decidable (a.val < b.val))

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

instance : Coe UnitScale CpsatSolver.Int64 where
  coe v := Subtype.mk (v.val : ℤ) v.nonoverflow

private def sortPred (a b : UnitScale) : Prop :=
  a.val ≤ b.val

instance : Std.Antisymm sortPred where
  antisymm a b rab rba : a = b := by
    dsimp [sortPred] at rab
    dsimp [sortPred] at rba
    apply LE.le.eq_or_lt at rab
    apply LE.le.eq_or_lt at rba
    cases a
    cases b
    simp only [UnitScale.mkRaw.injEq]
    simp only at rab
    simp only at rba
    cases rab with
    | inl heq =>
      cases rba with
      | inl _ =>
        cases heq
        rfl
      | inr _ =>
        by_contra
        contradiction
    | inr a_lt_b =>
      cases rba with
      | inl heq =>
        cases heq
        rfl
      | inr b_lt_a =>
        apply LT.lt.asymm at a_lt_b
        contradiction

instance : DecidableRel sortPred :=
  fun a b => inferInstanceAs (Decidable (a.val ≤ b.val))

instance : IsTrans UnitScale sortPred where
  trans _ _ _ rab rbc := LE.le.trans rab rbc

instance : Std.Total sortPred where
  total a b := le_total a.val b.val

def UnitScale.sort (s : Finset UnitScale) : List UnitScale :=
  Finset.sort s sortPred

theorem UnitScale.mem_sort {us : Finset UnitScale}
  (u : UnitScale) (u_in_list : u ∈ UnitScale.sort us) :
    u ∈ us := by
      dsimp [sort] at u_in_list
      apply (us.mem_sort sortPred).mp at u_in_list
      exact u_in_list

end CpsatScheduler

