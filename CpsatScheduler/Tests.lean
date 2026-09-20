import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.Optimality
import CpsatScheduler.Constraints

set_option linter.style.setOption false
set_option linter.style.nativeDecide false
set_option maxHeartbeats 400000

open CpsatSolver
open CpsatScheduler

/-- Lossless normalization of two operands to their minimum/finer unit. -/
def finer (a b : UnitScale) : UnitScale :=
  if a.val ≤ b.val then a else b

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

/-- `Task.ofBucketRange` works for a coarse unit `u = 4` (exercising the generic
`u > 1` arithmetic, not just the atomic case). Horizon `[0, 24)` admits start
buckets `[0, 5]`, since `(5 + 1) * 4 = 24 ≤ 24`. -/
def coarseTask :
    let unit4 : UnitScale := ⟨4, by decide, by decide⟩
    let units : Units :=
      { set := {UnitScale.atomic, unit4}
        has_atomic := by decide
        divisibility := by decide }
    let horizon : Horizon :=
      { begin := 0, end_ := 24, begin_lt_end := by decide,
        begin_safe := by decide, end_safe := by decide }
    Task (Timescales.mk units horizon) :=
  Task.ofBucketRange _ { val := 7 } (Subtype.mk ⟨4, by decide, by decide⟩ (by decide))
    (kLo := 0) (kHi := 5)
    (hle := by decide)
    (hbegin := by decide)
    (hend := by decide)
    (label := some "coarse_task")

/-- Bucket index `5` is the last valid start for the coarse task. -/
example : (5 : ℤ) ∈ coarseTask.startDomain.domain := by native_decide

/-- Bucket index `6` overflows the horizon and is excluded. -/
example : (6 : ℤ) ∉ coarseTask.startDomain.domain := by native_decide
