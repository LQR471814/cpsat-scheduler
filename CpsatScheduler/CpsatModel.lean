import CpsatScheduler.Defs

import Mathlib.Data.Int.Star
import Mathlib.Algebra.Order.Ring.Star

namespace CpsatScheduler

def Task.startAfterTime {scales : Timescales} (t : Task scales) : Time scales :=
  let units := scales.units;
  let horizon := scales.horizon;
  match t.startAfter with
  | Option.none =>
    {
      coeff := horizon.beginning,
      unit := units.atomic,
      intValid :=
        have s1 : units.atomic ≤ units.max :=
          units.nonzero units.max;
        have s2 : horizon.beginning * units.atomic
            ≤ horizon.beginning * units.max :=
          mul_le_mul_of_nonneg_left
            s1
            horizon.begin_ge_0;
        have min_le_zero : CpsatSolver.Int64.min ≤ 0 := by decide;
        have atomic_ge_zero : 0 ≤ units.atomic.val := (by decide : 0 ≤ (1 : ℤ));
        have left : CpsatSolver.Int64.min ≤ (horizon.beginning * units.atomic) :=
          -- 0 ≤ int64_min
          -- ∧ 0 ≤ units.atomic
          -- ∧ 0 ≤ horizon.beginning
          -- → 0 ≤ units.atomic * horizon.beginning
          -- → int64_min ≤ units.atomic * horizon.beginning
          --
          -- a * b ≤ a * c (if b ≤ c)
          -- a = horizon.beginning
          -- b = 0
          -- c = units.atomic
          have prod_ge_0 := mul_le_mul_of_nonneg_left
            (a := horizon.beginning)
            (b := 0)
            (c := units.atomic)
            atomic_ge_zero
            horizon.begin_ge_0;
          have simplified :=
            Eq.subst
              (motive := fun zero => zero ≤ horizon.beginning * ↑units.atomic)
              (mul_zero horizon.beginning)
              prod_ge_0;
          LE.le.trans min_le_zero simplified;
        let right : horizon.beginning * ↑units.atomic ≤ CpsatSolver.Int64.max :=
          have one_le_max_int : 1 ≤ CpsatSolver.Int64.max :=
            by decide;
          have atomic_le_max_int : units.atomic ≤ CpsatSolver.Int64.max :=
            one_le_max_int;
          have one_le_max_unit : units.atomic ≤ units.max :=
            units.nonzero units.max;
          have one_le_atomic : (1 : ℤ) ≤ units.atomic :=
            Eq.le rfl;
          have atomic_eq_one : units.atomic = (1 : ℤ) := rfl;
          have begin_times_umax_lt_imax
            : horizon.beginning * ↑scales.units.max ≤ CpsatSolver.Int64.max
              := horizon.begin_nonoverflow.right;
          have begin_lt_max : horizon.beginning ≤ CpsatSolver.Int64.max :=
            by grind
          have mul_ident : horizon.beginning * units.atomic = horizon.beginning :=
            mul_one horizon.beginning;
          by grind
        let result : CpsatSolver.Int64.Proof
          (horizon.beginning * units.atomic) :=
          And.intro
            left
            right
        result
    }
  | Option.some time => time.val.convertDown
    scales.units.atomic
    (Timescales.all_ge_atomic time.val.unit)

def Task.startBeforeTime {scales : Timescales} (t : Task scales) : Time scales :=
  let units := scales.units;
  let horizon := scales.horizon;
  match t.startBefore with
  | Option.none =>
    {
      coeff := horizon.ending,
      unit := units.atomic,
      intValid :=
        have s1 : units.atomic ≤ units.max :=
          units.nonzero units.max;
        have s2 : horizon.ending * units.atomic
            ≤ horizon.ending * units.max :=
          mul_le_mul_of_nonneg_left
            s1
            horizon.end_ge_0;
        have minLe0 : CpsatSolver.Int64.min ≤ 0 := by decide;
        have atomicGe0 : 0 ≤ units.atomic.val := (by decide : 0 ≤ (1 : ℤ));
        have left : CpsatSolver.Int64.min ≤ (horizon.ending * units.atomic) :=
          -- 0 ≤ int64_min
          -- ∧ 0 ≤ units.atomic
          -- ∧ 0 ≤ horizon.ending
          -- → 0 ≤ units.atomic * horizon.ending
          -- → int64_min ≤ units.atomic * horizon.ending
          --
          -- a * b ≤ a * c (if b ≤ c)
          -- a = horizon.ending
          -- b = 0
          -- c = units.atomic
          have prod_ge_0 := mul_le_mul_of_nonneg_left
            (a := horizon.ending)
            (b := 0)
            (c := units.atomic)
            atomicGe0
            horizon.end_ge_0;
          have simplified :=
            Eq.subst
              (motive := fun zero => zero ≤ horizon.ending * ↑units.atomic)
              (mul_zero horizon.ending)
              prod_ge_0;
          LE.le.trans minLe0 simplified;
        let right : horizon.ending * ↑units.atomic ≤ CpsatSolver.Int64.max :=
          have one_le_max_int : 1 ≤ CpsatSolver.Int64.max :=
            by decide;
          have atomic_le_max_int : units.atomic ≤ CpsatSolver.Int64.max :=
            one_le_max_int;
          have one_le_max_unit : units.atomic ≤ units.max :=
            units.nonzero units.max;
          have one_le_atomic : (1 : ℤ) ≤ units.atomic :=
            Eq.le rfl;
          have atomic_eq_one : units.atomic = (1 : ℤ) := rfl;
          have begin_times_umax_lt_imax
            : horizon.ending * ↑scales.units.max ≤ CpsatSolver.Int64.max
              := horizon.end_nonoverflow.right;
          have begin_lt_max : horizon.ending ≤ CpsatSolver.Int64.max :=
            by grind
          have mul_ident : horizon.ending * units.atomic = horizon.ending :=
            mul_one horizon.ending;
          by grind
        let result : CpsatSolver.Int64.Proof
          (horizon.ending * units.atomic) :=
          And.intro
            left
            right
        result
    }
  | Option.some time => time.val.convertDown
    scales.units.atomic
    (Timescales.all_ge_atomic time.val.unit)

def Task.startVar {scales : Timescales} (t : Task scales) :=
  let newName := s! "{t.name.val}_start";
  let curried (name_valid : CpsatSolver.Python.ValidName.Proof newName)
    : CpsatSolver.IntVar :=
    {
      name := { val := newName, proof := name_valid }
      domain := {
        min := t.startAfterTime.coeff * t.startAfterTime.unit
        max := t.startBeforeTime.coeff * t.startBeforeTime.unit
      }
    };
  curried

def Task.costVar {scales : Timescales} (t : Task scales)
  (min max : ℤ) :=
  let newName := s! "{t.name.val}_cost";
  let curried (name_valid : CpsatSolver.Python.ValidName.Proof newName)
    : CpsatSolver.IntVar :=
    {
      name := { val := newName, proof := name_valid }
      domain := {
        min := min
        max := max
      }
    };
  curried

def Task.durationVar {scales : Timescales} (t : Task scales) :=
  sorry

end CpsatScheduler
