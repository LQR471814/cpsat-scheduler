import Mathlib.Data.Rat.Defs
import Mathlib.Data.Rat.Star
import CpsatScheduler.CpsatSolver.Domain.Defs

namespace Scipy.Convert

def roundToInt (f : Float) : ℤ :=
  f.round.toInt64.toInt

def floatToRat (f : Float) (decimals : ℕ := 6) : ℚ :=
  let scale := 10 ^ decimals
  mkRat (roundToInt (f * scale.toFloat)) scale

def int64? (n : ℤ) : Option CpsatSolver.Int64 :=
  if h : CpsatSolver.Int64.Nonoverflow n then some ⟨n, h⟩ else none

def roundToInt64? (f : Float) : Option CpsatSolver.Int64 :=
  int64? (roundToInt f)

def roundingErrorBound : ℚ := mkRat 1 2

theorem roundingErrorBound_nonneg : (0 : ℚ) ≤ roundingErrorBound := by decide

end Scipy.Convert
