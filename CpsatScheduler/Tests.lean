import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Defs
import CpsatScheduler.Constraints

set_option linter.style.setOption false
set_option linter.style.nativeDecide false
set_option maxHeartbeats 400000

open CpsatSolver
open CpsatScheduler

/-- Sparse domains decide membership by scanning interval endpoints, not by
enumerating every integer in a huge range. -/
example :
    Domain.contains
      (Domain.interval (Interval.ofBounds 0 ((2 : ℤ) ^ 50)
        ⟨by decide, by decide⟩ (by decide)))
      ((2 : ℤ) ^ 50) = true := by
  native_decide

example :
    Domain.contains
      (Domain.union
        (Domain.interval (Interval.ofBounds 0 1 ⟨by decide, by decide⟩ (by decide)))
        (Domain.interval (Interval.ofBounds 5 8 ⟨by decide, by decide⟩ (by decide))))
      3 = false := by
  native_decide

example : Int.tdiv (-7 : ℤ) 3 = -2 := by
  native_decide

example :
    LinearExpr.eval (fun _ => 99) (LinearExpr.const (Int64.of 3)) = 3 := by
  native_decide

example :
    (3 : ℤ) ∈ Interval.fromValue (Int64.of 3) := by
  decide

def emptyModel? : Option Model := RawModel.finalize? {}

example : emptyModel?.isSome = true := by
  native_decide

def emptyModel : Model := emptyModel?.get (by native_decide)

example : emptyModel.satisfiesB ⟨[], []⟩ = true := by
  native_decide

example : emptyModel.evalObjective ⟨[], []⟩ = Option.none := by
  native_decide

example :
    let asgn : Assignment := ⟨[⟨⟨0⟩, 4⟩], []⟩
    asgn.intVal ⟨0⟩ = 4 := by
  native_decide

example : finer UnitScale.atomic UnitScale.atomic = UnitScale.atomic := by
  native_decide

example : (UnitScale.exactRatio
    ⟨2, Nat.succ_pos 1, by decide⟩ UnitScale.atomic (by decide)).val = 2 := by
  native_decide

example : (0 : ℚ) ≤ (1 : ℚ) + 1 :=
  true_le_encoded_add_err (t := (0 : ℚ)) (e := 1) (ε := 1) (by norm_num)

example :
    (([(0, 0, 1)] : List (ℚ × ℚ × ℚ)).map (·.1)).sum ≤
      ([(5, 5, 1)].map (·.1)).sum +
        2 * ([(0, 0, 1)].map (·.2.2)).sum :=
  encodedOptimal_trueCost_le
    ([(0, 0, 1)] : List (ℚ × ℚ × ℚ))
    [(5, 5, 1)]
    (fun p hp => by
      simp only [List.mem_singleton] at hp
      subst hp
      norm_num)
    (fun p hp => by
      simp only [List.mem_singleton] at hp
      subst hp
      norm_num)
    rfl
    (by norm_num)
