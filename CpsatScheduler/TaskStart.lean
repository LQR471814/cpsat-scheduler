import CpsatScheduler.Defs
import CpsatScheduler.CpsatSolver.Helpers

import Mathlib.Data.Int.Star
import Mathlib.Algebra.Order.Ring.Star

namespace CpsatScheduler

def Task.startAfterTime {scales : Timescales}
  (t : Task scales) : Time scales.units :=
  let units := scales.units;
  let horizon := scales.horizon;
  match t.startAfter with
  | Option.none =>
    {
      coeff := {
        val := (horizon.beginning.convertLossy t.unit).val
        proof := by
          have hunit : horizon.beginning.unit ≤ t.unit := by
            rw [horizon.begin_is_atomic]
            exact units.nonzero t.unit
          exact Time.convertLossy_coeff_proof horizon.beginning t.unit hunit
      }
      unit := t.unit
    }
  | Option.some time => time.val

def Task.startBeforeTime {scales : Timescales} (t : Task scales) : Time scales.units :=
  let units := scales.units;
  let horizon := scales.horizon;
  match t.startBefore with
  | Option.none =>
    {
      coeff := {
        val := (horizon.ending.convertLossy t.unit).val
        proof := by
          have hunit : horizon.ending.unit ≤ t.unit := by
            rw [horizon.end_is_atomic]
            exact units.nonzero t.unit
          exact Time.convertLossy_coeff_proof horizon.ending t.unit hunit

      },
      unit := units.atomic,
    }
  | Option.some time => time.val

end CpsatScheduler
