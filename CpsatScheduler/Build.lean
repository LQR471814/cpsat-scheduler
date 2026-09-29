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

/-!
# Model assembly helpers

Reusable scaffolding for turning a list of PERT task configs plus declarative
constraint edges into a finalized CP-SAT `Model`, together with a homogeneous
record of solved-variable ids for reporting.

The design keeps every proof obligation off the demo/author:

* task ids come from a single monotonic counter (`freshTaskId`);
* `registerTask` rewrites the id onto a concrete config, preserving all proofs
  (`PERT.TaskConfig.setId`);
* prerequisite and containment ("within") edges are resolved by id, with their
  `Int64` nonoverflow obligations discharged by the generic `Task.*` lemmas —
  no `decide` on solver variables or runtime units.
-/

namespace CpsatScheduler.Build

open CpsatScheduler
open CpsatScheduler.Schedule
open CpsatSolver

/-- Homogeneous, dependent-index-free record captured once a task is built.
Everything needed to report a task's solved values lives here. -/
structure SolvedTaskRef where
  taskId : Nat
  label : String
  unit : UnitScale
  startId : EntityId
  costId : EntityId
  demandId : EntityId

/-- A registered task: its assigned id, concrete `Task`, and the builder action
that allocates its variables. -/
structure Registered (scales : Timescales) where
  taskId : TaskId
  task : Task scales
  build : Builder (TaskVars scales)

/-- Allocate a fresh task id from a monotonic counter. -/
def freshTaskId : StateT Nat IO TaskId := do
  let n ← get
  set (n + 1)
  pure ⟨n⟩

/-- Register a task: allocate a fresh id, rewrite it onto the concrete config
(the id appears in no proof, so `PERT.TaskConfig.setId` preserves every proof
field), and run the Python-backed cost-table construction. -/
def registerTask {scales : Timescales}
    (py : Python.DaemonProcess) (base : PERT.TaskConfig scales) :
    StateT Nat IO (Except String (Registered scales)) := do
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

/-- A containment ("within") edge: the `child` task's bucket must fall inside the
`parent` task's bucket. The scale ratio is derived as `parentUnit / childUnit`,
so no ratio needs to be supplied. -/
structure WithinEdge where
  child : TaskId
  parent : TaskId

/-- One built task paired with its captured reference record. -/
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

/-- Add a `succ ≥ pred + 1` prerequisite constraint for a resolved edge. The
nonoverflow obligation is discharged generically. -/
private def addPrerequisite {scales : Timescales}
    (s p : TaskVars scales) (succId predId : Nat) : Builder Unit := do
  let _ ← Builder.addConstraint .always
    (.bounded_linear
      (Constraint.prerequisite s.startVar p.startVar
        (Task.prereq_nonoverflow p.task p.startVar p.unit_eq)))
    (some s!"prereq_{predId}_before_{succId}")
  pure ()

/-- Add a containment ("within") constraint for a resolved edge. `ratio =
parentUnit / childUnit`; the bound `ratio ≤ parentUnit` holds by
`Int.ediv_le_self`, and scaled-endpoint safety comes from the `Task.within_*`
lemmas. -/
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

/-- Assemble a finalized model from task configs and declarative edges.

Steps: validate blocked allocations, register each config (fresh ids + Python
cost tables), build all task variables, add prerequisite / within / packing
constraints and the cost-minimization objective, then finalize. Returns the
model together with the reporting records. Unresolved edge ids are a hard
error. -/
def buildModel {scales : Timescales}
    (py : Python.DaemonProcess)
    (sched : ScheduleMap)
    (configs : List (PERT.TaskConfig scales))
    (prereqEdges : List PrereqEdge := [])
    (withinEdges : List WithinEdge := [])
    (blockedAllocs : List Alloc := []) :
    IO (Except String (Model × List SolvedTaskRef)) := do
  let _ := sched
  let blockedNonoverflow : Except String (List Alloc.Nonoverflow) :=
    match Alloc.checkMany blockedAllocs with
    | .some b => .ok b
    | .none => .error "blocked allocations were not valid"
  let (registeredResults, _) ← (configs.mapM (registerTask py ·)).run 0
  let registered : Except String (List (Registered scales)) :=
    registeredResults.mapM id
  pure do
    let blocked ← blockedNonoverflow
    let regBuilders ← registered
    let result : Except String (RawModel × List SolvedTaskRef) := Id.run do
      let ⟨rawModel, out⟩ := Builder.run (do
        let built ← regBuilders.mapM capture
        let varsArr : Array (TaskVars scales) := (built.map (·.2.1)).toArray
        let mut err : Option String := none
        for edge in prereqEdges do
          match find? built edge.succ, find? built edge.pred with
          | some s, some p => addPrerequisite s.2.1 p.2.1 edge.succ.val edge.pred.val
          | _, _ => err := some s!"prerequisite edge references unknown task id"
        for edge in withinEdges do
          match find? built edge.child, find? built edge.parent with
          | some c, some p => addWithin c.2.1 p.2.1 edge.child.val edge.parent.val
          | _, _ => err := some s!"within edge references unknown task id"
        Constraint.packing varsArr blocked
        let _ ← Objective.minimizeCostSum varsArr
        pure (err, built.map (·.2.2)))
      match out.1 with
      | some e => pure (.error e)
      | none => pure (.ok (rawModel, out.2))
    let ⟨rawModel, refs⟩ ← result
    let model ← rawModel.finalize?
      |> Except.mapError (s!"finalize model: {·}")
    pure (model, refs)

/-- Solution status label. -/
def statusLabel {model : Model} : SolveResult model → String
  | .optimal _ _ => "optimal"
  | .feasible _ _ => "feasible"
  | .infeasible => "infeasible"
  | .modelInvalid => "model_invalid"
  | .unknown => "unknown"

/-- Task-specification JSON (independent of any solution): the scheduling
horizon plus per-task label and unit. -/
def specJson (sched : ScheduleMap) (refs : List SolvedTaskRef) : Lean.Json :=
  let hBegin : Int := (sched.scales.horizon.begin : Int)
  let hEnd : Int := (sched.scales.horizon.end_ : Int)
  Lean.Json.mkObj [
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

/-- Solution JSON: solve status plus per-task solved datetime, cost, and demand.
The reported datetime uses each task's own unit. -/
def solutionJson (sched : ScheduleMap) (status : String)
    (asgn : Assignment) (refs : List SolvedTaskRef) : Lean.Json :=
  Lean.Json.mkObj [
    ("status", Lean.Json.str status),
    ("tasks", Lean.Json.mkObj (refs.map fun r =>
      (toString r.taskId, Lean.Json.mkObj [
        ("datetime", Lean.Json.str (sched.bucketDateString r.unit (asgn.intVal r.startId))),
        ("cost", Lean.Json.num (asgn.intVal r.costId)),
        ("demand", Lean.Json.num (asgn.intVal r.demandId))
      ])))
  ]

end CpsatScheduler.Build
