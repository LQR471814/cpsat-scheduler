import CpsatScheduler.Defs

namespace CpsatScheduler

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

end CpsatScheduler

