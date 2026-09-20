import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Constraints

open CpsatScheduler
open CpsatSolver

def atomic : UnitScale := {
  val := 1
  pos := by decide
  nonoverflow := by decide
}

def unit2 : UnitScale := {
  val := 2
  pos := by decide
  nonoverflow := by decide
}

def unit4 : UnitScale := {
  val := 4
  pos := by decide
  nonoverflow := by decide
}

def unitSet : Finset UnitScale := {
  atomic,
  unit2,
  unit4
}

def units : Units := {
  set := unitSet
  has_atomic := by decide
  divisibility := by decide
}

def horizon : Horizon := {
  begin := 0
  end_ := 12
  begin_lt_end := by decide
  begin_safe := by decide
  end_safe := by decide
}

def scales := Timescales.mk units horizon

def demoModel? : Option Model :=
  let result := Builder.run do
    -- `atomic` unit, horizon `[0, 12)`, so valid start buckets are `[0, 11]`.
    let taskA : Task scales :=
      Task.ofBucketRange scales { val := 1 } (Subtype.mk atomic (by decide))
        (kLo := 0) (kHi := 11)
        (hle := by decide)
        (hbegin := by decide)
        (hend := by decide)
        (label := Option.some "task_a")
    let aVar ← Builder.newIntVar taskA.startDomain (some "task_a_start")
    let a : TaskStart scales := {
      task := taskA
      var := aVar.var
      unit_eq := by rw [aVar.eq]
    }
    let taskB : Task scales :=
      Task.ofBucketRange scales { val := 2 } (Subtype.mk unit2 (by decide))
        (kLo := 0) (kHi := 5)
        (hle := by decide)
        (hbegin := by decide)
        (hend := by decide)
        (label := Option.some "task_b")
    let b ← Builder.newIntVar taskB.startDomain (some "task_b_start")
    let c ← Builder.newIntVar d0_3 (some "task_c_start")
    let be := LinearExpr.var b.var
    let rows : Array (Vector CpsatSolver.Int64 2) := #[
      Vector.mk #[CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 1] rfl,
      Vector.mk #[CpsatSolver.Int64.of 1, CpsatSolver.Int64.of 2] rfl,
      Vector.mk #[CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3] rfl,
    ]
    let _ ← Builder.addConstraint .always
      (.allowed_assignments (Vector.mk #[a.var, b.var] rfl) rows)
      (some "task_b_after_a")
    let _ ← Builder.addConstraint .always
      (.bounded_linear (prerequisite.variant c.var a.var (by
        show
          CpsatSolver.Int64.Nonoverflow ((a.var.domain.hull.left : ℤ) + 1) ∧
          CpsatSolver.Int64.Nonoverflow ((a.var.domain.hull.right : ℤ) + 1)
        rw [show a.var.domain = taskA.startDomain from by rw [show a.var = aVar.var from rfl, aVar.eq]]
        decide)))
      (some "task_c_within_task_a")
    Builder.setObjective (.minimize ⟨b.var.domain.hull, be⟩)
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
