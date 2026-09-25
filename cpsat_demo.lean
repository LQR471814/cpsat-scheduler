import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.TaskVars
import CpsatScheduler.ConstrainPrereq
import CpsatScheduler.ConstrainPacking

open CpsatScheduler
open CpsatSolver

def atomic : UnitScale := UnitScale.mk 1
def unit2 : UnitScale := UnitScale.mk 2
def unit4 : UnitScale := UnitScale.mk 4

def unitSet : Finset UnitScale := { atomic, unit2, unit4 }

def units : CpsatScheduler.Units := CpsatScheduler.Units.of unitSet

def horizon : Horizon := Horizon.mk 0 12

def scales := Timescales.mk units horizon

-- `atomic` unit, horizon `[0, 12)`, so valid start buckets are `[0, 11]`.
@[simp] def taskA : Task scales :=
  Task.ofBucketRange scales { val := 1 } (Subtype.mk atomic (by decide))
    (kLo := 0) (kHi := 11)
    (label := Option.some "task_a")

@[simp] def taskB : Task scales :=
  Task.ofBucketRange scales { val := 2 } (Subtype.mk unit2 (by decide))
    (kHi := 4)
    (label := Option.some "task_b")

@[simp] def taskC : Task scales :=
  Task.ofBucketRange scales { val := 3 } (Subtype.mk unit2 (by decide))
    (label := Option.some "task_b")

def demoModel? : Option Model :=
  let result := Builder.run do
    let a <- TaskVars.of taskA
    let b <- TaskVars.of taskB
    let c <- TaskVars.of taskC
    let be := LinearExpr.var b.vars.startVar
    let rows : Array (Vector CpsatSolver.Int64 2) := #[
      Vector.mk #[CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 1] rfl,
      Vector.mk #[CpsatSolver.Int64.of 1, CpsatSolver.Int64.of 2] rfl,
      Vector.mk #[CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3] rfl,
    ]
    let _ ← Builder.addConstraint .always
      (.bounded_linear
        (Constraint.prerequisite
          c.vars.startVar a.vars.startVar
          (by
            rw [a.start_domain]
            simp only [NonemptyDomain.hull, Domain.hullOf, TaskVars.startDomain, taskA,
              Task.ofBucketRange, NonemptyDomain.interval, Domain.interval, Interval.of,
              List.head_cons, List.getLast_singleton, zero_add, Int.reduceAdd]
            decide)))
      (some "task_c_before_a")
    let _ <- (Constraint.packing #[ a.vars, b.vars, c.vars ])
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
    | .ok (.optimal asgn _) =>
      let assignments := asgn.ints.map (fun pair => s!"{pair.1.val}={pair.2}");
      IO.println s!"optimal: {assignments.foldl (s!"{·} {·}") ""}"
    | .ok (.feasible _ _) => IO.println "feasible"
    | .ok (.infeasible) => IO.println "infeasible"
    | .ok (.modelInvalid) => IO.println "model invalid"
    | .ok (.unknown) => IO.println "unknown"
