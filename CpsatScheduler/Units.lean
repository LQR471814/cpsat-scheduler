import CpsatScheduler.Defs
import Mathlib.Data.Finset.Sort

namespace CpsatScheduler

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

def Units.sort (u : Units) : List UnitScale :=
  Finset.sort u.set sortPred

end CpsatScheduler

