import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.TaskVars
import CpsatScheduler.ConstrainPrereq
import CpsatScheduler.ConstrainPacking
import CpsatScheduler.ConstrainPERT
import CpsatScheduler.Objective
import CpsatScheduler.Schedule
import CpsatScheduler.StandardUnits

import Std.Time

open CpsatScheduler
open CpsatScheduler.Schedule
open CpsatScheduler.StandardUnits
open CpsatSolver
open Scipy
open Std.Time

def horizon : Horizon := Horizon.mk 0 12
def scales := Timescales.mk units horizon

def sched : ScheduleMap :=
  ScheduleMap.ofDateTime scales (epoch := datetime("2026-01-01T00:00:00")) (atomicSec := 900)

@[simp] def taskA : Task scales :=
  sched.task { val := 1 } (Subtype.mk atomic (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T02:45:00"))
    (label := some "task_a")

def blockedAllocs : List Alloc :=
  sched.quantizeEventDateTime
    datetime("2026-01-01T00:30:00")
    datetime("2026-01-01T01:15:00")
    four_hour

example : totalAlloc blockedAllocs = 3 := by decide

def configA : Constraint.PERT.Config :=
  { opt := 1.0, exp := 2.0, pes := 5.0, cost := 1000.0, steps := 2, steps_nonzero := by decide }

def configB : Constraint.PERT.Config :=
  { opt := 2.0, exp := 4.0, pes := 9.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

def configC : Constraint.PERT.Config :=
  { opt := 1.0, exp := 3.0, pes := 8.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

def demoModel? (tableA : CostTable atomic) (tableB : CostTable four_hour)
    (tableC : CostTable four_hour) : Option Model :=
  let result := Builder.run do
    let a ← TaskVars.of taskA tableA.costHull
    let b ← TaskVars.of taskB tableB.costHull
    let c ← TaskVars.of taskC tableC.costHull
    let _ ← Builder.addConstraint .always
      (.bounded_linear
        (Constraint.prerequisite c.vars.startVar a.vars.startVar
          (by rw [a.start_domain]; decide)))
      (some "task_c_before_a")
    Constraint.packing #[ a.vars, b.vars, c.vars ]
    Constraint.PERT.costByTable a.vars tableA
    Constraint.PERT.costByTable b.vars tableB
    Constraint.PERT.costByTable c.vars tableC
    let _ ← Objective.minimizeCostSum #[ a.vars, b.vars, c.vars ]
    pure ()
  result.1.finalize?

def startDateOf (model : Model) (a : Assignment)
    (label : String) (unit : UnitScale) : Option String :=
  a.ints.find? (fun (id, _) => (model.labelOf id).getD id.toPythonName.val = s!"{label}_start")
    |>.map fun p => sched.bucketDateString unit p.2

def main : IO Unit := do
  let runtime : Python.Runtime := { path := ".venv/bin/python3" };
  IO.println "generating model..."
  let (⟨hA, hB, hC⟩, results) ← PertM.run runtime do
    let hA ← Constraint.PERT.requestCostTable configA
    let hB ← Constraint.PERT.requestCostTable configB
    let hC ← Constraint.PERT.requestCostTable configC
    pure (hA, hB, hC)
  let some tableA := hA.resolve results atomic | IO.println "table A failed"
  let some tableB := hB.resolve results four_hour | IO.println "table B failed"
  let some tableC := hC.resolve results four_hour | IO.println "table C failed"
  match demoModel? tableA tableB tableC with
  | none => IO.println "invalid model"
  | some model =>
    IO.println "solving..."
    match ← model.solve runtime with
    | .error err => IO.println s!"error: {err}"
    | .ok (.optimal asgn _) =>
      IO.println "optimal schedule:"
      for (label, unit) in [("task_a", atomic), ("task_b", four_hour), ("task_c", four_hour)] do
        match startDateOf model asgn label unit with
        | some date => IO.println s!"  {label} starts at {date}"
        | none => IO.println s!"  {label}: (no start assigned)"
    | .ok (.feasible _ _) => IO.println "feasible"
    | .ok (.infeasible) => IO.println "infeasible"
    | .ok (.modelInvalid) => IO.println "model invalid"
    | .ok (.unknown) => IO.println "unknown"
