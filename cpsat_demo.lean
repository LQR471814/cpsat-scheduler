import CpsatScheduler

import Std.Time

open CpsatScheduler
open CpsatScheduler.Schedule
open CpsatScheduler.Build
open CpsatSolver
open Std.Time

def runtime : Python.Runtime := { path := ".venv/bin/python3" }

def atomic : UnitScale := UnitScale.mk 1
def unit2 : UnitScale := UnitScale.mk 2
def unit4 : UnitScale := UnitScale.mk 4
def unit8 : UnitScale := UnitScale.mk 8
def unit16 : UnitScale := UnitScale.mk 16
def units : CpsatScheduler.Units := CpsatScheduler.Units.of {
  atomic,
  unit2,
  unit4,
  unit8,
  unit16
}

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

def pertSteps : Array Float := Stats.PERT.Distribute.cubic 3

@[simp] def taskA : Task scales :=
  sched.task (Subtype.mk unit4 (by decide))
    (startAfter := datetime("2026-01-01T00:00:00"))
    (startBefore := datetime("2026-01-01T02:45:00"))
    (label := some "task_a")

@[simp] def taskB : Task scales :=
  sched.task (Subtype.mk unit8 (by decide))
    (startAfter := datetime("2026-01-01T00:00:00"))
    (startBefore := datetime("2026-01-01T01:00:00"))
    (label := some "task_b")

@[simp] def taskC : Task scales :=
  sched.task (Subtype.mk unit16 (by decide))
    (startAfter := datetime("2026-01-01T00:00:00"))
    (startBefore := datetime("2026-01-01T01:00:00"))
    (label := some "task_c")

def taskAConfig : PERT.TaskConfig scales := {
  task := taskA
  cost := PERT.Cost.of 1000
  demand := { opt := int 1, exp := int 2, pes := int 4, valid := by decide }
  steps := pertSteps
}

def taskBConfig : PERT.TaskConfig scales := {
  task := taskB
  cost := PERT.Cost.of 1000
  demand := { opt := int 2, exp := int 3, pes := int 8, valid := by decide }
  steps := pertSteps
}

def taskCConfig : PERT.TaskConfig scales := {
  task := taskC
  cost := PERT.Cost.of 1000
  demand := { opt := int 3, exp := int 5, pes := int 9, valid := by decide }
  steps := pertSteps
}

def spec (py : Python.DaemonProcess) : Registrar (BuildSpec scales) := do
  let a ← register py taskAConfig
  let b ← register py taskBConfig
  let c ← register py taskCConfig
  pure {
    tasks := [a, b, c]
    prereqs := [{ succ := a, pred := c }]
    withins := [{ child := a, parent := b }]
    blocked := blockedAllocs
    blockedUnit := unit4
  }

def specFile : String := "schedule.spec.json"
def solutionFile : String := "schedule.solution.json"

def main : IO Unit := do
  IO.println "starting python daemon..."
  let py ← Python.DaemonProcess.spawn runtime #[]
  Stats.PERT.init py
  IO.println "generating model..."
  let result ← buildModel py sched (spec py)
  match result with
  | .error err => IO.println s!"gen model: {err}"
  | .ok (model, refs) =>
    IO.FS.writeFile specFile (specJson sched refs).pretty
    IO.println s!"wrote {specFile}"
    IO.println "solving..."
    match ← model.solve py with
    | .error err => IO.println s!"error: {err}"
    | .ok res =>
      let status := statusLabel res
      match res with
      | .optimal asgn _ | .feasible asgn _ =>
        IO.FS.writeFile solutionFile (solutionJson sched status asgn refs).pretty
        IO.println s!"wrote {solutionFile} (status: {status})"
      | _ => IO.println s!"no solution (status: {status})"
  py.child.kill
