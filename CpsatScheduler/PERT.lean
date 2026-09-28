import CpsatScheduler.Defs
import CpsatScheduler.CostTable
import CpsatScheduler.Stats.PERT

namespace PERT

open CpsatScheduler
open CpsatSolver

structure DemandEstimate where
  opt : Float
  exp : Float
  pes : Float

abbrev Cost := { x : CpsatSolver.Int64 // x ≥ (CpsatSolver.Int64.of 0) }

def Cost.of (v : ℤ)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow v := by decide)
  (nonzero : v ≥ (0 : ℤ) := by decide) : Cost :=
  Subtype.mk (Subtype.mk v nonoverflow) nonzero

def Cost.hull (c : Cost) : NonemptyDomain :=
  {
    domain := Domain.interval {
      left := CpsatSolver.Int64.of 0
      right := c
      left_le_right := c.prop
    },
    nonempty := by simp
  }

def costTable (py : Python.DaemonProcess)
  (cost : Cost) (demand : DemandEstimate)
  (steps : Array Float) :
    IO (Except String CostDemandTable) := do
  let pairs ← Stats.PERT.costDemandPairs
    py demand.opt demand.exp demand.pes (Float.ofInt cost.val)
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
    pure ⟨points⟩

structure TaskConfig (S : Timescales) where
  cost : Cost
  demand : DemandEstimate
  steps : Array Float
  task : CpsatScheduler.Task S

structure Task (cfg : TaskConfig S) where
  taskVars : TaskVarsResult S cfg.task cfg.cost.hull

def Task.of (py : Python.DaemonProcess) (cfg : TaskConfig S) :
    IO (Except String (Builder (Task cfg))) := do
  let table ← PERT.costTable py cfg.cost cfg.demand cfg.steps
  pure (match table with
    | .ok table =>
      .ok do
        let taskVarsResult ← TaskVars.of cfg.task cfg.cost.hull
        let _ ← table.constrain taskVarsResult.vars .always
        pure ⟨taskVarsResult⟩
    | .error err =>
      .error s!"PERT.costTable: {err}")

end PERT
