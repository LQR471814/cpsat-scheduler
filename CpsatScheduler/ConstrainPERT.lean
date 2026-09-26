import CpsatScheduler.Defs
import CpsatScheduler.TaskCostTable
import CpsatScheduler.Scipy.PERT
import CpsatScheduler.Scipy.Batch
import CpsatScheduler.Scipy.Convert

/-!
# PERT-driven cost/demand table generation

`Constraint.PERT` samples a PERT distribution (via the batched `PertM` Python
bridge) to produce a `TaskCostTable` for a task: each sampled quantile yields a
`(timeDemanded, encodedCost)` pair, which together act as an allowed-assignment
(table) constraint tying a chosen cost to its time demanded.

Pipeline:
1. `Scipy.pertProbs` — `steps` quantile probabilities under a chosen `Spacing`.
2. One `Scipy.pertPointExpr` per probability, requested through `PertM`
   (a single Python subprocess flushes all of them).
3. Each resolved `Float` cost is rounded to an `Int64` (`encodedCost`) and kept
   as an exact `ℚ` (`trueCost`); the demand grid is `0, 1, …, steps-1`.
4. `TaskCostTable.ofPoints?` certifies uniqueness / bounds / closeness.

Because `PertM` defers evaluation until `PertM.run`, generation is two-phase:
`genCostTableRequest` runs inside `PertM` (registering all quantile requests and
returning their handles), and the pure `assembleTable` turns the resolved floats
into the certified `TaskCostTable`. `runGenCostTable` wires both together with a
single Python execution.

Demand mapping: demands are the integers `0 … steps-1`, guaranteeing uniqueness;
pick `steps ≤ task.unit + 1` so every demand fits `[0, unit]` (otherwise
`ofPoints?` — and hence generation — returns `none`). `errorBound = 1/2`
(nearest-integer rounding), so `encodedClose` always holds for in-range demands.
-/

namespace Constraint.PERT

open CpsatScheduler
open CpsatSolver
open Scipy

/-- PERT parameters and sampling resolution for one task. -/
structure Config where
  /-- Optimistic estimate (distribution lower support). -/
  opt : Float
  /-- Most-likely / expected estimate (distribution mode). -/
  exp : Float
  /-- Pessimistic estimate (distribution upper support). -/
  pes : Float
  /-- Number of quantile samples (cost/demand pairs) to generate. -/
  steps : ℕ
  steps_nonzero : steps > 0
  /-- How quantile sample points are distributed across `(0,1)`
  (default: denser near the pessimistic tail). -/
  spacing : Spacing := Spacing.backLoaded

/-- Decimal precision used when turning a sampled `Float` cost into an exact
`trueCost : ℚ`. -/
def costPrecision : ℕ := 6

/-- Phase 1: register one PERT quantile request per quantile probability
(using `config.spacing`), returning the handles in demand order (`0 … steps-1`). -/
def genCostTableRequest (config : Config) : PertM (Array PertHandle) := do
  let probs := pertProbs config.steps config.spacing config.steps_nonzero
  probs.mapM fun p =>
    PertM.request (pertPointExpr config.opt config.exp config.pes p)

/-- Phase 2 (pure): assemble a certified `TaskCostTable` from the resolved
results. Demand `i` (the grid index) is paired with the rounded cost at
`handles[i]`; `trueCost` maps each demand to the exact `ℚ` cost. Returns `none`
if any handle is unresolved, a cost overflows `Int64`, or validation fails. -/
def assembleTable {scales : Timescales} (task : Task scales)
    (handles : Array PertHandle) (results : Array Float) :
    Option (TaskCostTable task) :=
  -- exact ℚ cost keyed by demand index, plus the encoded points
  let entries : Array (Option (CostPoint × (ℤ × ℚ))) :=
    (Array.range handles.size).map fun i =>
      match (handles[i]!).resolve results with
      | none => none
      | some cost =>
        match Scipy.Convert.int64? (i : ℤ), Scipy.Convert.roundToInt64? cost with
        | some d, some c =>
          some (⟨d, c⟩, ((i : ℤ), Scipy.Convert.floatToRat cost costPrecision))
        | _, _ => none
  if entries.all Option.isSome then
    let resolved := entries.filterMap id
    let points := resolved.map (·.fst)
    let ratByDemand := resolved.map (·.snd)
    let trueCost : ℤ → ℚ := fun d =>
      match ratByDemand.find? (fun kv => kv.fst == d) with
      | some kv => kv.snd
      | none => 0
    TaskCostTable.ofPoints? task points trueCost Scipy.Convert.roundingErrorBound
  else
    none

/-- End-to-end generation: one Python execution produces every quantile, then a
certified `TaskCostTable` is assembled (or `none` on validation failure). -/
def runGenCostTable {scales : Timescales} (runtime : Python.Runtime)
    (config : Config) (task : Task scales) : IO (Option (TaskCostTable task)) := do
  let (handles, results) ← PertM.run runtime (genCostTableRequest config)
  pure (assembleTable task handles results)

end Constraint.PERT
