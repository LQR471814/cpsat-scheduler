import CpsatScheduler.Defs
import CpsatScheduler.CostTable
import CpsatScheduler.TaskVars
import CpsatScheduler.Scipy.PERT
import CpsatScheduler.Scipy.Batch
import CpsatScheduler.Scipy.Convert

namespace Constraint.PERT

open CpsatScheduler
open CpsatSolver
open Scipy

structure Config where
  opt : Float
  exp : Float
  pes : Float
  cost : Float
  steps : ℕ
  steps_nonzero : steps > 0

def costPrecision : ℕ := 6

structure CostTableHandle where
  config : Config
  start : Nat

def requestCostTable (config : Config) : PertM CostTableHandle := do
  let start := (← get).requests.size
  for δ in Array.range config.steps do
    let _ ← PertM.request
      (pertCostExpr config.opt config.exp config.pes config.cost δ.toFloat)
  pure { config := config, start := start }

private def pointAt (handle : CostTableHandle) (results : Array Float) (i : ℕ) :
    Option (CostPoint × ℚ) := do
  let cost ← results[handle.start + i]?
  let demand ← Scipy.Convert.int64? (i : ℤ)
  let encoded ← Scipy.Convert.roundToInt64? cost
  pure (⟨demand, encoded⟩, Scipy.Convert.floatToRat cost costPrecision)

def CostTableHandle.resolve (handle : CostTableHandle) (results : Array Float)
    (unit : UnitScale) : Option (CostTable unit) := do
  let entries ← (Array.range handle.config.steps).mapM (pointAt handle results)
  let costOf (demand : ℤ) : ℚ :=
    (entries.find? (fun e => e.fst.timeDemanded.val == demand)).map (·.snd) |>.getD 0
  CostTable.ofPoints? unit (entries.map (·.fst)) costOf Scipy.Convert.roundingErrorBound

def constrainCostByTable {scales : Timescales} {unit : UnitScale}
    (vars : TaskVars scales) (table : CostTable unit) : Builder Unit := do
  let cols : Vector IntVar 2 := ⟨#[vars.timeDemandedVar, vars.costVar], rfl⟩
  let _ ← Builder.addConstraint .always
    (.allowed_assignments cols table.allowedRows)
    (some s!"task_{vars.task.id.val}_pert_cost")
  pure ()

def sumVars (vars : Array IntVar) : Option ((b : Bounds) × LinearExpr b) :=
  vars.foldl (init := none) fun acc v =>
    let cur : (b : Bounds) × LinearExpr b := ⟨_, LinearExpr.var v⟩
    match acc with
    | none => some cur
    | some ⟨b, e⟩ =>
      if h : Int64.Nonoverflow ((b.left : ℤ) + cur.fst.left) ∧
             Int64.Nonoverflow ((b.right : ℤ) + cur.fst.right) then
        some ⟨_, LinearExpr.add e cur.snd h⟩
      else
        none

def minimizeCostSum {scales : Timescales} (varsList : Array (TaskVars scales)) :
    Builder Bool :=
  match sumVars (varsList.map (·.costVar)) with
  | none => pure false
  | some ⟨_, total⟩ => do
    Builder.setObjective (.minimize total.wrapBounds)
    pure true

end Constraint.PERT
