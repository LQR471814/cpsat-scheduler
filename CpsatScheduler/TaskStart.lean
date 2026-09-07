import CpsatScheduler.Defs

import Mathlib.Data.Int.Star
import Mathlib.Algebra.Order.Ring.Star

-- TODO:
-- formalize "unit-aware task start"
--
-- namely, prevent user from constructing invalid comparison
-- between task start variables without unit alignment
--
-- use operator overloading to make construction easier

namespace CpsatScheduler

private def Task.startAfterTime {scales : Timescales}
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

private def Task.startBeforeTime {scales : Timescales} (t : Task scales) : Time scales.units :=
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

structure Task.StartVar (scales : Timescales) where
  mkRaw ::
  task : Task scales
  var : CpsatSolver.IntVar

private def Task.startVar {scales : Timescales} (t : Task scales) :=
  curryValidName s! "{t.name.val}_start" (fun name => ({
    name := name
    domain := {
      min := t.startBeforeTime.coeff * t.startAfterTime.unit
      max := t.startAfterTime.coeff * t.startAfterTime.unit
    }
  } : CpsatSolver.IntVar))

def Task.StartVar.mk {scales : Timescales} (task : Task scales) :=
  fun hname =>
    ({
      task := task,
      var := task.startVar hname
    } : Task.StartVar scales)

end CpsatScheduler
