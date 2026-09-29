import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.TaskProofs
import CpsatScheduler.TaskVars
import CpsatScheduler.ConstrainPrereq
import CpsatScheduler.ConstrainBucket
import CpsatScheduler.ConstrainPacking
import CpsatScheduler.PERT
import CpsatScheduler.Objective
import CpsatScheduler.Schedule

import Std.Time
import Lean.Data.Json

open CpsatScheduler
open CpsatScheduler.Schedule
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

/-- Homogeneous, dependent-index-free record captured once a task is built. -/
structure SolvedTaskRef where
  taskId : Nat
  label : String
  unit : UnitScale
  startId : EntityId
  costId : EntityId
  demandId : EntityId

/-- Everything the model builder needs for one registered task: the concrete
`Task` and the builder action producing its variables. The id is threaded from
the registry counter. -/
structure Registered where
  taskId : TaskId
  task : Task scales
  build : Builder (TaskVars scales)

private def freshTaskId : StateT Nat IO TaskId := do
  let n ← get
  set (n + 1)
  pure ⟨n⟩

/-- A task config builder. Concrete window/unit/demand literals live at the
definition site (placeholder id `0`) so `Task.ofBucketRange` and
`DemandEstimate.valid` discharge by `decide`. The registry rewrites the id. -/
abbrev ConfigFor := PERT.TaskConfig scales

/-- Register a task: allocate a fresh id, rewrite it onto the concrete config,
and run the Python-backed cost-table construction. The id appears in no proof,
so overriding it preserves every proof field. -/
def registerTask (py : Python.DaemonProcess) (base : ConfigFor) :
    StateT Nat IO (Except String Registered) := do
  let id ← freshTaskId
  let cfg : PERT.TaskConfig scales := PERT.TaskConfig.setId base id
  let built ← PERT.Task.of py cfg
  pure do
    let builder ← built
    pure {
      taskId := id
      task := cfg.task
      build := do
        let t ← builder
        pure t.taskVars.vars
    }

/-- A prerequisite edge: `pred` must finish before `succ` starts. -/
structure PrereqEdge where
  succ : TaskId
  pred : TaskId

@[simp] def taskA : Task scales :=
  sched.task ⟨0⟩ (Subtype.mk unit4 (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T02:45:00"))
    (label := some "task_a")

@[simp] def taskB : Task scales :=
  sched.task ⟨0⟩ (Subtype.mk unit8 (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T01:00:00"))
    (label := some "task_b")

@[simp] def taskC : Task scales :=
  sched.task ⟨0⟩ (Subtype.mk unit16 (by decide))
    (startAfterSec := plainDateTimeToSecUTC datetime("2026-01-01T00:00:00"))
    (startBeforeSec := plainDateTimeToSecUTC datetime("2026-01-01T01:00:00"))
    (label := some "task_c")

def taskAConfig : ConfigFor := {
  task := taskA
  cost := PERT.Cost.of 1000
  demand := { opt := i64 1, exp := i64 2, pes := i64 4, valid := by decide }
  steps := pertSteps
}

def taskBConfig : ConfigFor := {
  task := taskB
  cost := PERT.Cost.of 1000
  demand := { opt := i64 2, exp := i64 3, pes := i64 8, valid := by decide }
  steps := pertSteps
}

def taskCConfig : ConfigFor := {
  task := taskC
  cost := PERT.Cost.of 1000
  demand := { opt := i64 3, exp := i64 5, pes := i64 9, valid := by decide }
  steps := pertSteps
}

def configs : List ConfigFor := [taskAConfig, taskBConfig, taskCConfig]

/-- Prerequisite edges by task id (ids are assigned by registration order:
task_a=0, task_b=1, task_c=2). "C before A": succ=A, pred=C. -/
def prereqEdges : List PrereqEdge := [
  { succ := ⟨0⟩, pred := ⟨2⟩ }
]

def demoModel (py : Python.DaemonProcess) :
    IO (Except String (Model × List SolvedTaskRef)) := do
  let blockedNonoverflow ← match Alloc.checkMany blockedAllocs with
    | .some b => pure (Except.ok b)
    | .none => pure (Except.error "allocs were not valid")
  let (registeredResults, _) ← (configs.mapM (registerTask py ·)).run 0
  let registered : Except String (List Registered) := registeredResults.mapM id
  pure do
    let blocked ← blockedNonoverflow
    let regBuilders ← registered
    let ⟨rawModel, refs⟩ := Builder.run do
      -- build every task's variables, capturing homogeneous refs + TaskVars
      let built ← regBuilders.mapM (fun r => do
        let vars ← r.build
        let ref : SolvedTaskRef := {
          taskId := r.taskId.val
          label := r.task.label.getD s!"task_{r.taskId.val}"
          unit := r.task.unit.val
          startId := vars.startVar.id
          costId := vars.costVar.id
          demandId := vars.timeDemandedVar.id
        }
        pure (r, vars, ref))
      let varsArr : Array (TaskVars scales) := (built.map (·.2.1)).toArray
      -- prerequisites (generic nonoverflow proof, no per-edge decide)
      for edge in prereqEdges do
        match built.find? (fun b => b.1.taskId == edge.succ),
              built.find? (fun b => b.1.taskId == edge.pred) with
        | some s, some p =>
          let succVar := s.2.1.startVar
          let predVar := p.2.1.startVar
          let _ ← Builder.addConstraint .always
            (.bounded_linear
              (Constraint.prerequisite succVar predVar
                (Task.prereq_nonoverflow p.2.1.task predVar p.2.1.unit_eq)))
            (some s!"prereq_{p.1.taskId.val}_before_{s.1.taskId.val}")
        | _, _ => pure ()
      -- containment ("within"): child bucket inside parent bucket.
      -- `ratio = parentUnit / childUnit`; the bound `ratio ≤ parentUnit` then
      -- holds generically by `Int.ediv_le_self`, and scaled-endpoint safety
      -- comes from the `Task.within_*` lemmas — no `decide` on solver vars or
      -- runtime units.
      match built with
      | childB :: parentB :: _ =>
        let childVars := childB.2.1
        let parentVars := parentB.2.1
        let pu : ℤ := (parentVars.task.unit.val.val : ℤ)
        let cu : ℤ := (childVars.task.unit.val.val : ℤ)
        have hpu0 : 0 ≤ pu := Int.natCast_nonneg _
        have hpuMax : pu ≤ CpsatSolver.Int64.max := parentVars.task.unit.val.nonoverflow.2
        have hratio0 : 0 ≤ pu / cu := Int.ediv_nonneg hpu0 (Int.natCast_nonneg _)
        have hratioLe : pu / cu ≤ pu := by exact Int.ediv_le_self _ hpu0
        let ratio : CpsatSolver.Int64 :=
          ⟨pu / cu, ⟨le_trans (by decide) hratio0, le_trans hratioLe hpuMax⟩⟩
        let hc := childVars.unit_eq
        let hp := parentVars.unit_eq
        let hr0 : 0 ≤ (ratio : ℤ) := hratio0
        let hru : (ratio : ℤ) ≤ (parentVars.task.unit.val.val : ℤ) := hratioLe
        let add₁ := Task.prereq_nonoverflow parentVars.task parentVars.startVar hp
        let pair := Constraint.bucketContainedIn childVars.startVar parentVars.startVar ratio
            (Task.within_mul_group parentVars.task parentVars.startVar ratio hp hr0 hru)
            add₁
            (Task.within_succ_mul_group parentVars.task parentVars.startVar ratio hp hr0 hru add₁)
            (Task.prereq_nonoverflow childVars.task childVars.startVar hc)
        let _ ← Builder.addConstraint .always (.bounded_linear pair.1)
          (some s!"within_{childB.1.taskId.val}_in_{parentB.1.taskId.val}_lo")
        let _ ← Builder.addConstraint .always (.bounded_linear pair.2)
          (some s!"within_{childB.1.taskId.val}_in_{parentB.1.taskId.val}_hi")
      | _ => pure ()
      Constraint.packing varsArr blocked
      let _ ← Objective.minimizeCostSum varsArr
      pure (built.map (·.2.2))
    let model ← rawModel.finalize?
      |> Except.mapError (s!"finalize model: {·}")
    pure (model, refs)

/-- Build the task-specification JSON (independent of any solution). -/
def specJson (refs : List SolvedTaskRef) : Lean.Json :=
  Lean.Json.mkObj (refs.map fun r =>
    (toString r.taskId, Lean.Json.mkObj [
      ("label", Lean.Json.str r.label),
      ("unit", Lean.Json.num (r.unit.val : Int))
    ]))

/-- Build the solution JSON: per-task solved datetime, cost, and demand. -/
def solutionJson (status : String) (asgn : Assignment) (refs : List SolvedTaskRef) :
    Lean.Json :=
  Lean.Json.mkObj [
    ("status", Lean.Json.str status),
    ("tasks", Lean.Json.mkObj (refs.map fun r =>
      (toString r.taskId, Lean.Json.mkObj [
        ("datetime", Lean.Json.str (sched.bucketDateString r.unit (asgn.intVal r.startId))),
        ("cost", Lean.Json.num (asgn.intVal r.costId)),
        ("demand", Lean.Json.num (asgn.intVal r.demandId))
      ])))
  ]

def specFile : String := "schedule.spec.json"
def solutionFile : String := "schedule.solution.json"

def main : IO Unit := do
  IO.println "starting python daemon..."
  let py ← Python.DaemonProcess.spawn runtime #[]
  Stats.PERT.init py
  IO.println "generating model..."
  let result ← demoModel py
  match result with
  | .error err => IO.println s!"gen model: {err}"
  | .ok (model, refs) =>
    IO.FS.writeFile specFile (specJson refs).pretty
    IO.println s!"wrote {specFile}"
    IO.println "solving..."
    match ← model.solve py with
    | .error err => IO.println s!"error: {err}"
    | .ok res =>
      let write (status : String) (asgn : Assignment) : IO Unit := do
        IO.FS.writeFile solutionFile (solutionJson status asgn refs).pretty
        IO.println s!"wrote {solutionFile} (status: {status})"
      match res with
      | .optimal asgn _ => write "optimal" asgn
      | .feasible asgn _ => write "feasible" asgn
      | .infeasible => IO.println "infeasible"
      | .modelInvalid => IO.println "model invalid"
      | .unknown => IO.println "unknown"
  py.child.kill
