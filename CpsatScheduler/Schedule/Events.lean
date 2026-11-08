import Mathlib.Tactic.ApplyFun

import CpsatScheduler.Schedule.Conversion

namespace CpsatScheduler.Schedule

open CpsatSolver

structure Event where
  start : Std.Time.Timestamp
  finish : Std.Time.Timestamp
  in_order : finish ≥ start
deriving DecidableEq

def Event.mapOverUnits (e : Event) (c : Config)
    (u : Unit.Scale)
    (map : Time → α) := fun hs1 hs2 hf1 hf2 =>
  let start := c.toScheduleTime e.start u hs1 hs2
  let finish := c.toScheduleTime e.finish u hf1 hf2
  let rec iter (remaining : ℕ) (rem_in_range :
      remaining ≤ (finish.val - start.val).toNat) :=
    if remaining = 0 then
      List.nil
    else
      let i := finish.val - start.val - remaining
      let cur := map {
        val := i
        unit := u
        nonneg := by
          unfold i
          have finish_ge_start : finish.val ≥ start.val := by
            apply Config.toScheduleTime_val_mono
            exact e.in_order
          have finish_nonneg : finish.val - start.val ≥ 0 := by
            apply Int.sub_nonneg.mpr
            exact finish_ge_start
          apply Int.sub_nonneg.mpr
          rw [← Int.toNat_of_nonneg finish_nonneg]
          exact_mod_cast rem_in_range
        le_max := by
          unfold i
          have h1 : finish.val - start.val - (remaining : ℤ) ≤ finish.val - start.val :=
            Int.sub_le_self _ (Int.natCast_nonneg remaining)
          have h2 : finish.val - start.val ≤ finish.val :=
            Int.sub_le_self _ start.nonneg
          exact Int.le_trans (Int.le_trans h1 h2) finish.le_max
      }
      let next := iter (remaining - 1)
        (Nat.le_trans (Nat.sub_le remaining 1) rem_in_range)
      cur :: next
  iter (finish.val - start.val).toNat

end CpsatScheduler.Schedule

