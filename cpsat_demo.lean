import CpsatScheduler.CpsatSolver.Model

open CpsatSolver

def d0_3 : NonemptyDomain :=
  NonemptyDomain.interval (Interval.ofBounds 0 3 ⟨by decide, by decide⟩ (by decide))

def demoModel? : Option Model :=
  let result := Builder.run do
    let a ← Builder.newIntVar d0_3 (some "task_a_start")
    let b ← Builder.newIntVar d0_3 (some "task_b_start")
    let be := LinearExpr.var b
    let rows : Array (Vector CpsatSolver.Int64 2) := #[
      Vector.mk #[CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 1] rfl,
      Vector.mk #[CpsatSolver.Int64.of 1, CpsatSolver.Int64.of 2] rfl,
      Vector.mk #[CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3] rfl]
    let _ ← Builder.addConstraint .always
      (.allowedAssignments (Vector.mk #[a, b] rfl) rows)
      (some "task_b_after_a")
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
