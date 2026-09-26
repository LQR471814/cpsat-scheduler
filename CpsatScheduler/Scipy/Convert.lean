import Mathlib.Data.Rat.Defs
import Mathlib.Data.Rat.Star
import CpsatScheduler.CpsatSolver.Domain.Defs

/-!
# Float → Int64 / ℚ conversion helpers

Pure helpers bridging Python-produced `Float` values into the project's
`CpsatSolver.Int64` (for `CostPoint`) and into exact `ℚ` values (for
`TaskCostTable.trueCost`).

`Float` is not reasoned about symbolically: every conversion collapses to a
concrete `ℤ`/`ℚ`, and any `CpsatSolver.Int64.Nonoverflow` obligation is either
discharged by `decide` on the concrete integer at the use site or guarded by an
`Option`-returning smart constructor here.
-/

namespace Scipy.Convert

open CpsatSolver

/-- Round a `Float` to the nearest integer (`ℤ`), routing through core
`Float.round`/`Float.toInt64`. -/
@[inline] def floatToInt (f : Float) : ℤ :=
  f.round.toInt64.toInt

/-- Fixed-point decimal scale `10 ^ precision`, as a positive natural. -/
@[inline] def scaleNat (precision : ℕ) : ℕ := 10 ^ precision

/-- `10 ^ precision` rendered as a `Float`. -/
@[inline] def scaleFloat (precision : ℕ) : Float :=
  (scaleNat precision).toFloat

/-- Exact rational approximation of a `Float` at `precision` decimal digits.

Computes `round(f * 10^p) / 10^p : ℚ`. This is the value we treat as the PERT
model's ground-truth cost for a demand point (`trueCost`); the encoded cost is a
further rounding of it to the nearest integer, so `|trueCost - encodedCost| ≤ 1/2`. -/
@[inline] def floatToRat (f : Float) (precision : ℕ := 6) : ℚ :=
  let s : ℕ := scaleNat precision
  let scaled : ℤ := floatToInt (f * scaleFloat precision)
  mkRat scaled s

/-- Guarded construction of a `CpsatSolver.Int64` from an arbitrary `ℤ`.
Returns `none` when `n` would overflow the 64-bit range. -/
@[inline] def int64? (n : ℤ) : Option CpsatSolver.Int64 :=
  if h : CpsatSolver.Int64.Nonoverflow n then
    some ⟨n, h⟩
  else
    none

/-- Round a `Float` to the nearest `CpsatSolver.Int64`, or `none` on overflow. -/
@[inline] def roundToInt64? (f : Float) : Option CpsatSolver.Int64 :=
  int64? (floatToInt f)

/-- Rounding error bound: nearest-integer rounding is always within `1/2`. This is
the `errorBound` used by PERT-generated cost tables. -/
def roundingErrorBound : ℚ := mkRat 1 2

theorem roundingErrorBound_nonneg : (0 : ℚ) ≤ roundingErrorBound := by
  unfold roundingErrorBound
  decide

end Scipy.Convert
