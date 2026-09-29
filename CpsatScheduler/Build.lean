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

import Lean.Data.Json

namespace CpsatScheduler.Build

open CpsatScheduler
open CpsatScheduler.Schedule
open CpsatSolver

structure SolvedTaskRef where
  taskId : Nat
  label : String
  unit : UnitScale
  startId : EntityId
  costId : EntityId
  demandId : EntityId

structure Registered (scales : Timescales) where
  taskId : TaskId
  task : Task scales
  build : Builder (TaskVars scales)

abbrev Registrar := StateT Nat (ExceptT String IO)

def register {scales : Timescales}
    (py : Python.DaemonProcess) (cfg : PERT.TaskConfig scales) :
    Registrar (Registered scales) := do
  let n ← get
  set (n + 1)
  let built ← PERT.Task.of py cfg
  match built with
  | .error e => throw e
  | .ok builder =>
    pure {
      taskId := ⟨n⟩
      task := cfg.task
      build := do
        let t ← builder
        pure t.taskVars.vars
    }

structure PrereqEdge (scales : Timescales) where
  succ : Registered scales
  pred : Registered scales

structure WithinEdge (scales : Timescales) where
  child : Registered scales
  parent : Registered scales

structure BuildSpec (scales : Timescales) where
  tasks : List (Registered scales)
  prereqs : List (PrereqEdge scales) := []
  withins : List (WithinEdge scales) := []
  blocked : List Alloc := []
  blockedUnit : UnitScale

private abbrev Built (scales : Timescales) :=
  Registered scales × TaskVars scales × SolvedTaskRef

private def capture {scales : Timescales} (r : Registered scales) :
    Builder (Built scales) := do
  let vars ← r.build
  let ref : SolvedTaskRef := {
    taskId := r.taskId.val
    label := r.task.label.getD s!"task_{r.taskId.val}"
    unit := r.task.unit.val
    startId := vars.startVar.id
    costId := vars.costVar.id
    demandId := vars.timeDemandedVar.id
  }
  pure (r, vars, ref)

private def find? {scales : Timescales}
    (built : List (Built scales)) (id : TaskId) : Option (Built scales) :=
  built.find? (fun b => b.1.taskId == id)

private def addPrerequisite {scales : Timescales}
    (s p : TaskVars scales) (succId predId : Nat) : Builder Unit := do
  let _ ← Builder.addConstraint .always
    (.bounded_linear
      (Constraint.prerequisite s.startVar p.startVar
        (Task.prereq_nonoverflow p.task p.startVar p.unit_eq)))
    (some s!"prereq_{predId}_before_{succId}")
  pure ()

private def addWithin {scales : Timescales}
    (child parent : TaskVars scales) (childId parentId : Nat) : Builder Unit := do
  let pu : ℤ := (parent.task.unit.val.val : ℤ)
  let cu : ℤ := (child.task.unit.val.val : ℤ)
  have hpu0 : 0 ≤ pu := Int.natCast_nonneg _
  have hpuMax : pu ≤ CpsatSolver.Int64.max := parent.task.unit.val.nonoverflow.2
  have hratio0 : 0 ≤ pu / cu := Int.ediv_nonneg hpu0 (Int.natCast_nonneg _)
  have hratioLe : pu / cu ≤ pu := Int.ediv_le_self _ hpu0
  let ratio : CpsatSolver.Int64 :=
    ⟨pu / cu, ⟨le_trans (by decide) hratio0, le_trans hratioLe hpuMax⟩⟩
  let hp := parent.unit_eq
  let hc := child.unit_eq
  let hr0 : 0 ≤ (ratio : ℤ) := hratio0
  let hru : (ratio : ℤ) ≤ (parent.task.unit.val.val : ℤ) := hratioLe
  let add₁ := Task.prereq_nonoverflow parent.task parent.startVar hp
  let pair := Constraint.bucketContainedIn child.startVar parent.startVar ratio
    (Task.within_mul_group parent.task parent.startVar ratio hp hr0 hru)
    add₁
    (Task.within_succ_mul_group parent.task parent.startVar ratio hp hr0 hru add₁)
    (Task.prereq_nonoverflow child.task child.startVar hc)
  let _ ← Builder.addConstraint .always (.bounded_linear pair.1)
    (some s!"within_{childId}_in_{parentId}_lo")
  let _ ← Builder.addConstraint .always (.bounded_linear pair.2)
    (some s!"within_{childId}_in_{parentId}_hi")
  pure ()

def buildModel {scales : Timescales}
    (py : Python.DaemonProcess)
    (sched : ScheduleMap)
    (spec : Registrar (BuildSpec scales)) :
    IO (Except String (Model × List SolvedTaskRef)) := do
  let _ := (py, sched)
  let specResult ← (spec.run 0).run
  pure do
    let (built, _) ← specResult
    let blocked ← match Alloc.checkMany built.blocked with
      | .some b => .ok b
      | .none => .error "blocked allocations were not valid"
    let ⟨rawModel, refs⟩ := Builder.run do
      let builtTasks ← built.tasks.mapM capture
      let varsArr : Array (TaskVars scales) := (builtTasks.map (·.2.1)).toArray
      for edge in built.prereqs do
        match find? builtTasks edge.succ.taskId, find? builtTasks edge.pred.taskId with
        | some s, some p => addPrerequisite s.2.1 p.2.1 edge.succ.taskId.val edge.pred.taskId.val
        | _, _ => pure ()
      for edge in built.withins do
        match find? builtTasks edge.child.taskId, find? builtTasks edge.parent.taskId with
        | some c, some p => addWithin c.2.1 p.2.1 edge.child.taskId.val edge.parent.taskId.val
        | _, _ => pure ()
      Constraint.packing varsArr blocked built.blockedUnit
      let _ ← Objective.minimizeCostSum varsArr
      pure (builtTasks.map (·.2.2))
    let model ← rawModel.finalize?
      |> Except.mapError (s!"finalize model: {·}")
    pure (model, refs)

def statusLabel {model : Model} : SolveResult model → String
  | .optimal _ _ => "optimal"
  | .feasible _ _ => "feasible"
  | .infeasible => "infeasible"
  | .modelInvalid => "model_invalid"
  | .unknown => "unknown"

def specJson (sched : ScheduleMap) (refs : List SolvedTaskRef) : Lean.Json :=
  let hBegin : Int := (sched.scales.horizon.begin : Int)
  let hEnd : Int := (sched.scales.horizon.end_ : Int)
  Lean.Json.mkObj [
    ("atomicSec", Lean.Json.num sched.atomicSec),
    ("horizon", Lean.Json.mkObj [
      ("beginBucket", Lean.Json.num hBegin),
      ("endBucket", Lean.Json.num hEnd),
      ("begin", Lean.Json.str (sched.bucketDateString UnitScale.atomic hBegin)),
      ("end", Lean.Json.str (sched.bucketDateString UnitScale.atomic hEnd))
    ]),
    ("tasks", Lean.Json.mkObj (refs.map fun r =>
      (toString r.taskId, Lean.Json.mkObj [
        ("label", Lean.Json.str r.label),
        ("unit", Lean.Json.num (r.unit.val : Int))
      ])))
  ]

def solutionJson (sched : ScheduleMap) (status : String)
    (asgn : Assignment) (refs : List SolvedTaskRef) : Lean.Json :=
  Lean.Json.mkObj [
    ("status", Lean.Json.str status),
    ("tasks", Lean.Json.mkObj (refs.map fun r =>
      (toString r.taskId, Lean.Json.mkObj [
        ("datetime", Lean.Json.str (sched.bucketDateString r.unit (asgn.intVal r.startId))),
        ("cost", Lean.Json.num (asgn.intVal r.costId)),
        ("demandAtomic", Lean.Json.num (asgn.intVal r.demandId))
      ])))
  ]

end CpsatScheduler.Build
