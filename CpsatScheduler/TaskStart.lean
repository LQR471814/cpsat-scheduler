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
      coeff :=
        {
          val := (horizon.beginning.convertLossy t.unit).val
          proof := by
            have hunit : horizon.beginning.unit ≤ t.unit := by
              rw [horizon.begin_is_atomic]
              exact units.nonzero t.unit
            have hsize :=
              Time.convertLossy_coeff_abs_le horizon.beginning t.unit hunit
            have hXpos : 0 < horizon.beginning.unit.val :=
              lt_of_lt_of_le Int.zero_lt_one (units.nonzero horizon.beginning.unit)
            obtain ⟨k, hk⟩ : ∃ k : ℤ, t.unit.val = horizon.beginning.unit.val * k :=
              Int.dvd_iff_emod_eq_zero.mpr
                (units.divisibility t.unit horizon.beginning.unit hunit)
            have hkpos : 0 < k := by
              have hYpos : 0 < t.unit.val :=
                lt_of_lt_of_le Int.zero_lt_one (units.nonzero t.unit)
              rw [hk] at hYpos
              nlinarith
            have hconverted :
                (horizon.beginning.convertLossy t.unit).val = horizon.beginning.coeff.val / k := by
              simp only [Time.convertLossy]
              rw [hk]
              calc
                horizon.beginning.coeff.val * horizon.beginning.unit.val /
                    (horizon.beginning.unit.val * k) =
                    horizon.beginning.unit.val * horizon.beginning.coeff.val /
                      (horizon.beginning.unit.val * k) := by rw [mul_comm]
                _ = horizon.beginning.coeff.val / k :=
                  Int.mul_ediv_mul_of_pos _ _ hXpos
            constructor
            · have hcoeff_abs : |horizon.beginning.coeff.val| ≤ (2 : ℤ)^63 := by
                obtain ⟨hmin, hmax⟩ := horizon.beginning.coeff.proof
                by_cases hcoeff_nonneg : 0 ≤ horizon.beginning.coeff.val
                · rw [abs_of_nonneg hcoeff_nonneg]
                  unfold CpsatSolver.Int64.max at hmax
                  omega
                · rw [abs_of_neg (lt_of_not_ge hcoeff_nonneg)]
                  unfold CpsatSolver.Int64.min at hmin
                  omega
              unfold CpsatSolver.Int64.min
              calc
                -((2 : ℤ)^63) ≤ -|horizon.beginning.coeff.val| := by omega
                _ ≤ -|(horizon.beginning.convertLossy t.unit).val| := by omega
                _ ≤ (horizon.beginning.convertLossy t.unit).val := neg_abs_le _
            · by_cases hconverted_nonpos : (horizon.beginning.convertLossy t.unit).val ≤ 0
              · exact hconverted_nonpos.trans (by
                  unfold CpsatSolver.Int64.max
                  omega)
              · have hconverted_pos : 0 < (horizon.beginning.convertLossy t.unit).val :=
                  lt_of_not_ge hconverted_nonpos
                have hcoeff_nonneg : 0 ≤ horizon.beginning.coeff.val := by
                  by_contra hcoeff_nonneg
                  have hcoeff_neg : horizon.beginning.coeff.val < 0 :=
                    lt_of_not_ge hcoeff_nonneg
                  rw [hconverted] at hconverted_pos
                  exact (not_lt_of_ge (le_of_lt
                    (Int.ediv_neg_of_neg_of_pos hcoeff_neg hkpos))) hconverted_pos
                rw [hconverted]
                exact (Int.ediv_le_self _ hcoeff_nonneg).trans
                  horizon.beginning.coeff.proof.2
        }
      unit := t.unit
    }
    -- horizon.beginning.convertUp
    --   t.unit
    --   (have unit_ge_atomic : t.unit ≥ units.atomic :=
    --       units.nonzero t.unit
    --     have atomic_is_horizon_begin : units.atomic = horizon.beginning.unit :=
    --       Eq.symm horizon.begin_is_atomic;
    --     have result : t.unit ≥ horizon.beginning.unit :=
    --       Eq.subst
    --         atomic_is_horizon_begin
    --         unit_ge_atomic
    --     result)
    --   (let newCoeff := t.unit.val / horizon.beginning.unit * horizon.beginning.coeff;
    --     sorry
    -- )
  | Option.some time =>
    time.val

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
