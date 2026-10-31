import CpsatScheduler.Defs
import CpsatScheduler.CostTable
import CpsatScheduler.Stats.PERT

namespace PERT

open CpsatScheduler
open CpsatSolver

def DemandEstimate.Valid
  (task : CpsatScheduler.Task S)
  (opt exp pes : CpsatSolver.Int64) : Prop :=
    Task.MemDemand task opt.val ∧
    Task.MemDemand task exp.val ∧
    Task.MemDemand task pes.val ∧
    opt.val ≤ exp.val ∧
    exp.val ≤ pes.val

instance (task : CpsatScheduler.Task S) (opt exp pes : CpsatSolver.Int64) :
    Decidable (DemandEstimate.Valid task opt exp pes) := by
  unfold DemandEstimate.Valid
  infer_instance

structure DemandEstimate (S : Timescales) (task : Task S) where
  opt : CpsatSolver.Int64
  exp : CpsatSolver.Int64
  pes : CpsatSolver.Int64
  valid : DemandEstimate.Valid task opt exp pes

abbrev Cost := { x : CpsatSolver.Int64 // x ≥ (CpsatSolver.Int64.of 0) }

def Cost.of (v : ℤ)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow v := by native_decide)
  (nonzero : v ≥ (0 : ℤ) := by native_decide) : Cost :=
  Subtype.mk (Subtype.mk v nonoverflow) nonzero

def Cost.hull (c : Cost) : NonemptyDomain :=
  {
    domain := Domain.interval {
      left := CpsatSolver.Int64.of 0
      right := c
      left_le_right := c.prop
    },
    nonempty := by simp [Domain.interval]
  }

def costTable (py : Python.DaemonProcess)
  (task : CpsatScheduler.Task S) (cost : Cost)
  (demand : DemandEstimate S task) (steps : Array Float) :
    IO (Except String
      (CostDemandTable
        (Task.demandDomain task).domain cost.hull.domain)) := do
  let pairs ← Stats.PERT.costDemandPairs
    py
    demand.opt.val.toFloat
    demand.exp.val.toFloat
    demand.pes.val.toFloat
    (Float.ofInt cost.val)
    steps
  pure do
    let pairs ← pairs |> .mapError (fun err => s!"Stats.PERT.costDemandPairs: {err}")
    let points ← pairs.mapM (fun p => do
      let demand : CpsatSolver.Int64 ←
        match Int64.ofFloat? p.demand with
          | .some val => .ok val
          | .none => .error "demand float overflowed int64"
      let cost : CpsatSolver.Int64 ←
        match Int64.ofFloat? p.cost with
          | .some val => .ok val
          | .none => .error "cost float overflowed int64"
      .ok {
        timeDemanded := demand
        encodedCost := cost
      })
      |> .mapError (fun err => s!"truncate cost floats: {err}")
    if nonoverflow : points.size > 0 then
      match CostDemandTable.ofPoints?
        (Task.demandDomain task).domain
        cost.hull.domain
        points
        nonoverflow
      with
        | .some table => .ok table
        | .none =>
          .error "a cost/demand point fell outside the task's demand or cost domain"
    else
      .error "got empty points array"

structure TaskConfig (S : Timescales) where
  cost : Cost
  steps : Array Float
  task : CpsatScheduler.Task S
  demand : DemandEstimate S task

structure Task (cfg : TaskConfig S) where
  taskVars : TaskVars S
  constraint : Constraint

def Task.of (py : Python.DaemonProcess) (cfg : TaskConfig S)
  (startVarID costVarID timeDemandedVarID constraintID : EntityID) :
    IO (Except String (Task cfg)) := do
  let table ← PERT.costTable py cfg.task cfg.cost cfg.demand cfg.steps
  pure (match table with
    | .ok table =>
      let taskVarsResult := TaskVars.of
        cfg.task cfg.cost.hull
        startVarID costVarID timeDemandedVarID
      let constraint := CostDemandTable.constrain
        constraintID taskVarsResult table .always
      .ok {
        taskVars := taskVarsResult
        constraint := constraint
      }
    | .error err =>
      .error s!"PERT.costTable: {err}")

end PERT
