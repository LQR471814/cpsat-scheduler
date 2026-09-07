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

private theorem Task.atomic_boundary_int_valid
    {scales : Timescales}
    (x : ℤ)
    (x_ge_0 : 0 ≤ x)
    (x_mul_max_le :
      x * scales.units.max ≤ CpsatSolver.Int64.max) :
    CpsatSolver.Int64.Proof
      (x * scales.units.atomic) :=
  let units := scales.units
  have atomic_le_max : units.atomic ≤ units.max :=
    units.nonzero units.max
  have right :
      x * units.atomic ≤ CpsatSolver.Int64.max :=
    LE.le.trans
      (mul_le_mul_of_nonneg_left
        atomic_le_max
        x_ge_0)
      x_mul_max_le
  have min_le_zero : CpsatSolver.Int64.min ≤ 0 :=
    of_decide_eq_true rfl
  have atomic_ge_zero : 0 ≤ units.atomic.val :=
    of_decide_eq_true rfl
  have prod_ge_zero : 0 ≤ x * units.atomic :=
    Eq.subst
      (motive := fun zero => zero ≤ x * ↑units.atomic)
      (mul_zero x)
      (mul_le_mul_of_nonneg_left
        atomic_ge_zero
        x_ge_0)
  have left :
      CpsatSolver.Int64.min ≤ x * units.atomic :=
    LE.le.trans min_le_zero prod_ge_zero
  And.intro left right

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
      coeff := horizon.ending,
      unit := units.atomic,
      intValid :=
        Task.atomic_boundary_int_valid
          horizon.ending
          horizon.end_ge_0
          horizon.end_nonoverflow.right
    }
  | Option.some time => time.val.convertDown
    scales.units.atomic
    (Timescales.all_ge_atomic time.val.unit)

structure Task.StartVar (scales : Timescales) where
  mkRaw ::
  task : Task scales
  var : CpsatSolver.IntVar

private def Task.startVar {scales : Timescales} (t : Task scales) :=
  curryValidName s! "{t.name.val}_start" (fun name => ({
    name := name
    domain := {
      -- TODO: scale this to the task's unit
      min :=
        have unit_ge_atomic : scales.units.atomic ≤ t.unit :=
          scales.units.nonzero t.unit;
        have start_after_is_atomic
          : t.startAfterTime.unit = scales.units.atomic :=
          sorry
        t.startAfterTime.convertUp
          t.unit
          unit_ge_atomic
      max := t.startBeforeTime.coeff * t.startBeforeTime.unit
    }
  } : CpsatSolver.IntVar))

def Task.StartVar.mk {scales : Timescales} (task : Task scales) :=
  fun hname =>
    ({
      task := task,
      var := task.startVar hname
    } : Task.StartVar scales)

-- instance : HAdd Task.StartVar

end CpsatScheduler
