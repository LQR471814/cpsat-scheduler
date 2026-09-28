import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.TaskVars
import CpsatScheduler.ConstrainPrereq
import CpsatScheduler.ConstrainPacking
import CpsatScheduler.PERT
import CpsatScheduler.Objective
import CpsatScheduler.Schedule

import Std.Time

open CpsatScheduler
open CpsatScheduler.Schedule
open CpsatSolver
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

def blockedAllocs : List Alloc :=
  sched.quantizeEventDateTime datetime("2026-01-01T01:30:00") datetime("2026-01-01T01:45:00") unit4

example : totalAlloc blockedAllocs = 1 := by decide

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

def pertSteps : Array Float := Stats.PERT.Distribute.cubic 3

def demoModel (py : Python.DaemonProcess) : IO (Except String Model) := do
  let blockedAllocs ← match Alloc.checkMany blockedAllocs with
    | .some b => .ok b
    | .none => .error "allocs were not valid"
  let cfgA := {
    task := taskA
    cost := PERT.Cost.of 1000
    demand := ⟨1.0, 2.0, 5.0⟩
    steps := pertSteps
  }
  let buildTaskA ← PERT.Task.of py cfgA
  let cfgB := {
    task := taskB
    cost := PERT.Cost.of 1000
    demand := ⟨2.0, 4.0, 9.0⟩
    steps := pertSteps
  }
  let buildTaskB ← PERT.Task.of py cfgB
  let cfgC := {
    task := taskC
    cost := PERT.Cost.of 1000
    demand := ⟨1.0, 3.0, 8.0⟩
    steps := pertSteps
  }
  let buildTaskC ← PERT.Task.of py cfgC
  let result : Except String Model := do
    let a ← buildTaskA
    let b ← buildTaskB
    let c ← buildTaskC
    let ⟨model, _⟩ := Builder.run do
      let a ← a;
      let b ← b;
      let c ← c;
      let _ ← Builder.addConstraint .always
        (.bounded_linear
          (Constraint.prerequisite c.taskVars.vars.startVar a.taskVars.vars.startVar
            (by
              rw [a.taskVars.start_domain]
              dsimp [cfgA]
              decide)))
        (some "task_c_before_a")
      Constraint.packing #[
        a.taskVars.vars,
        b.taskVars.vars,
        c.taskVars.vars
      ] blockedAllocs
      let _ ← Objective.minimizeCostSum #[ a.taskVars.vars, b.taskVars.vars, c.taskVars.vars ]
      pure ()
    let model ← model.finalize?
      |> .mapError (s!"finalize model: {·}")
    pure model
  .ok result

def startDateOf (model : Model) (a : Assignment)
    (label : String) (unit : UnitScale) : Option String :=
  a.ints.find? (fun (id, _) => (model.labelOf id).getD id.toPythonName.val = s!"{label}_start")
    |>.map fun p => sched.bucketDateString unit p.2

def main : IO Unit := do
  IO.println "starting python daemon..."
  let py ← Python.DaemonProcess.spawn runtime #[]
  Stats.PERT.init py
  IO.println "generating model..."
  let model ← demoModel py
  match model with
  | .error err => IO.println s!"gen model: {err}"
  | .ok model =>
    IO.println "solving..."
    match ← model.solve py with
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
  py.child.kill
