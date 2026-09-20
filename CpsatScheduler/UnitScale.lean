import CpsatScheduler.Defs

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

end CpsatScheduler

