import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Constraints

open CpsatScheduler
open CpsatSolver

def d0_3 : NonemptyDomain :=
  NonemptyDomain.interval (Interval.ofBounds 0 6 ⟨by decide, by decide⟩ (by decide))

def demoModel? : Option Model :=
  let atomic : UnitScale := {
    val := 1
    pos := by decide
    nonoverflow := by decide
  }
  let unit2 : UnitScale := {
    val := 2
    pos := by decide
    nonoverflow := by decide
  }
  let unit4 : UnitScale := {
    val := 4
    pos := by decide
    nonoverflow := by decide
  }
  let unitSet : Finset UnitScale := {
    atomic,
    unit2,
    unit4
  }
  let units : Units := {
    set := unitSet
    has_atomic := by decide
    divisibility := by decide
  }
  let horizon : Horizon := {
    begin := 0
    end_ := 12
    begin_lt_end := by decide
    begin_safe := by decide
    end_safe := by decide
  }
  let scales := Timescales.mk units horizon
  let result := Builder.run do
    let taskA : Task scales := {
      id := { val := 1 }
      label := Option.some "task_a"
      unit := Subtype.mk atomic (by decide)
      startDomain := {
        domain := {
          intervals := [
            {
              left := Subtype.mk horizon.begin horizon.begin_safe
              right := Subtype.mk horizon.end_ horizon.end_safe
              left_le_right := by exact Int.le.intro_sub (horizon.end_ + 0) rfl
            }
          ]
          pairwise := by decide
        }
        nonempty := by decide
      }
      bucketsFitHorizon := fun k h_mem => And.intro
        sorry
        (And.intro
          sorry
          (And.intro
            sorry
            sorry))
    }
    let aVar ← Builder.newIntVar taskA.startDomain (some "task_a_start")
    let a : TaskStart scales := {
      task := taskA
      var := aVar
      unit_eq := by refine bif ?_ then ?_ else ?_
    }
    let b ← Builder.newIntVar d0_3 (some "task_b_start")
    let c ← Builder.newIntVar d0_3 (some "task_c_start")
    let be := LinearExpr.var b
    let rows : Array (Vector CpsatSolver.Int64 2) := #[
      Vector.mk #[CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 1] rfl,
      Vector.mk #[CpsatSolver.Int64.of 1, CpsatSolver.Int64.of 2] rfl,
      Vector.mk #[CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3] rfl,
    ]
    let _ ← Builder.addConstraint .always
      (.allowed_assignments (Vector.mk #[a, b] rfl) rows)
      (some "task_b_after_a")
    let _ ← Builder.addConstraint .always
      (some "task_c_within_task_a")
    Builder.setObjective (.minimize ⟨b.domain.hull, be⟩)
    pure ()
  result.1.finalize?

def main : IO Unit := do
  match demoModel? with
  | none => IO.println "invalid model"
  | some model =>
    IO.println "solving..."
    let result ← model.solve { path := ".venv/bin/python3" }
    match result with
    | .error err => IO.println s!"error: {err}"
    | .ok (.optimal asgn _) => IO.println s!"optimal: a={asgn.intVal ⟨0⟩}, b={asgn.intVal ⟨1⟩}"
    | .ok (.feasible _ _) => IO.println "feasible"
    | .ok (.infeasible) => IO.println "infeasible"
    | .ok (.modelInvalid) => IO.println "model invalid"
    | .ok (.unknown) => IO.println "unknown"
