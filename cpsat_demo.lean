import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.Constraints

open CpsatScheduler
open CpsatSolver

def atomic : UnitScale := UnitScale.mk 1
def unit2 : UnitScale := UnitScale.mk 2
def unit4 : UnitScale := UnitScale.mk 4

def unitSet : Finset UnitScale := { atomic, unit2, unit4 }

def units : CpsatScheduler.Units := CpsatScheduler.Units.mk unitSet

def horizon : Horizon := Horizon.mk 0 12

def scales := Timescales.mk units horizon

-- `atomic` unit, horizon `[0, 12)`, so valid start buckets are `[0, 11]`.
def taskA : Task scales :=
  Task.ofBucketRange scales { val := 1 } (Subtype.mk atomic (by decide))
    (kLo := 0) (kHi := 11)
    (label := Option.some "task_a")

def taskB : Task scales :=
  Task.ofBucketRange scales { val := 2 } (Subtype.mk unit2 (by decide))
    (kHi := 4)
    (label := Option.some "task_b")

def taskC : Task scales :=
  Task.ofBucketRange scales { val := 3 } (Subtype.mk unit2 (by decide))
    (label := Option.some "task_b")

def demoModel? : Option Model :=
  let result := Builder.run do
    let aVar ← Builder.newIntVar taskA.startDomain (some "task_a_start")
    let a : TaskVars scales := {
      task := taskA
      var := aVar.var
      unit_eq := by rw [aVar.eq]
    }
    let bVar ← Builder.newIntVar taskB.startDomain (some "task_b_start")
    let b : TaskVars scales := {
      task := taskB
      var := bVar.var
      unit_eq := by rw [bVar.eq]
    }
    let cVar ← Builder.newIntVar taskC.startDomain (some "task_c_start")
    let c : TaskVars scales := {
      task := taskC
      var := cVar.var
      unit_eq := by rw [cVar.eq]
    }
    let be := LinearExpr.var bVar.var
    let rows : Array (Vector CpsatSolver.Int64 2) := #[
      Vector.mk #[CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 1] rfl,
      Vector.mk #[CpsatSolver.Int64.of 1, CpsatSolver.Int64.of 2] rfl,
      Vector.mk #[CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3] rfl,
    ]
    let _ ← Builder.addConstraint .always
      (.allowed_assignments (Vector.mk #[a.var, bVar.var] rfl) rows)
      (some "task_b_after_a")
    let _ ← Builder.addConstraint .always
      (.bounded_linear
        (Constraint.prerequisite
          cVar.var a.var
          (by
            show
              CpsatSolver.Int64.Nonoverflow ((a.var.domain.hull.left : ℤ) + 1) ∧
              CpsatSolver.Int64.Nonoverflow ((a.var.domain.hull.right : ℤ) + 1)
            rw [
              show a.var.domain = taskA.startDomain from by
                rw [show a.var = aVar.var from rfl, aVar.eq]
            ]
            decide)))
      (some "task_c_within_task_a")
    let _ <- Builder.addConstraint .always
      (packScaleCumulative )
    Builder.setObjective (.minimize ⟨bVar.var.domain.hull, be⟩)
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
