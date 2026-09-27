import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.TaskVars
import CpsatScheduler.ConstrainPrereq
import CpsatScheduler.ConstrainPacking
import CpsatScheduler.ConstrainPERT
import CpsatScheduler.Objective
import CpsatScheduler.Schedule

import Std.Time

open CpsatScheduler
open CpsatScheduler.Schedule
open CpsatSolver
open Scipy
open Std.Time

def runtime : Python.Runtime := { path := ".venv/bin/python3" }

def atomic : UnitScale := UnitScale.mk 1
def unit4 : UnitScale := UnitScale.mk 4
def units : CpsatScheduler.Units := CpsatScheduler.Units.of { atomic, unit4 }

def horizon : Horizon := Horizon.ofDateTime
  (epoch := datetime("2026-01-01T00:00:00"))
  (start := datetime("2026-01-01T00:00:00"))
  («end» := datetime("2026-01-01T04:00:00"))
  900

def scales := Timescales.mk units horizon

def sched : ScheduleMap :=
  ScheduleMap.ofDateTime scales (epoch := datetime("2026-01-01T00:00:00")) (atomicSec := 900)

def blocked : List Alloc :=
  sched.quantizeEventDateTime datetime("2026-01-01T01:30:00") datetime("2026-01-01T01:45:00") unit4

example : totalAlloc blocked = 1 := by decide

@[simp] def taskA : Task scales :=
  sched.task { val := 1 } (Subtype.mk atomic (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T02:45:00"))
    (label := some "task_a")

@[simp] def taskB : Task scales :=
  sched.task { val := 2 } (Subtype.mk unit4 (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T01:00:00"))
    (label := some "task_b")

@[simp] def taskC : Task scales :=
  sched.task { val := 3 } (Subtype.mk unit4 (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T01:00:00"))
    (label := some "task_c")

def configA : Constraint.PERT.Config :=
  { opt := 1.0, exp := 2.0, pes := 5.0, cost := 1000.0, steps := 2, steps_nonzero := by decide }

def configB : Constraint.PERT.Config :=
  { opt := 2.0, exp := 4.0, pes := 9.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

def configC : Constraint.PERT.Config :=
  { opt := 1.0, exp := 3.0, pes := 8.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

def demoModel : IO (Option Model) := do
  let (⟨pA, pB, pC⟩, results) ← PertM.run runtime do
    let pA ← Constraint.PERT.requestCostTable configA
    let pB ← Constraint.PERT.requestCostTable configB
    let pC ← Constraint.PERT.requestCostTable configC
    pure (pA, pB, pC)
  let some tableA := pA.resolve results atomic | do IO.println "table A failed"; pure none
  let some tableB := pB.resolve results unit4 | do IO.println "table B failed"; pure none
  let some tableC := pC.resolve results unit4 | do IO.println "table C failed"; pure none
  pure do
    let blockedValid <- Alloc.checkMany blocked
    let result := Builder.run do
      let a ← TaskVars.of taskA tableA.costHull
      let b ← TaskVars.of taskB tableB.costHull
      let c ← TaskVars.of taskC tableC.costHull
      Constraint.PERT.costByTable a.vars tableA
      Constraint.PERT.costByTable b.vars tableB
      Constraint.PERT.costByTable c.vars tableC
      let _ ← Builder.addConstraint .always
        (.bounded_linear
          (Constraint.prerequisite c.vars.startVar a.vars.startVar
            (by rw [a.start_domain]; decide)))
        (some "task_c_before_a")
      Constraint.packing #[ a.vars, b.vars, c.vars ] blockedValid
      let _ ← Objective.minimizeCostSum #[ a.vars, b.vars, c.vars ]
      pure ()
    result.1.finalize?

def startDateOf (model : Model) (a : Assignment)
    (label : String) (unit : UnitScale) : Option String :=
  a.ints.find? (fun (id, _) => (model.labelOf id).getD id.toPythonName.val = s!"{label}_start")
    |>.map fun p => sched.bucketDateString unit p.2

def main : IO Unit := do
  IO.println "generating model..."
  let model? <- demoModel
  match model? with
  | none => IO.println "invalid model"
  | some model =>
    IO.println "solving..."
    match ← model.solve runtime with
    | .error err => IO.println s!"error: {err}"
    | .ok (.optimal asgn _) =>
      IO.println "optimal schedule:"
      for (label, unit) in [("task_a", atomic), ("task_b", unit4), ("task_c", unit4)] do
        match startDateOf model asgn label unit with
        | some date => IO.println s!"  {label} starts at {date}"
        | none => IO.println s!"  {label}: (no start assigned)"
    | .ok (.feasible _ _) => IO.println "feasible"
    | .ok (.infeasible) => IO.println "infeasible"
    | .ok (.modelInvalid) => IO.println "model invalid"
    | .ok (.unknown) => IO.println "unknown"
