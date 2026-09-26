import CpsatScheduler.Scipy.Convert
import CpsatScheduler.Scipy.PERT
import CpsatScheduler.Scipy.Batch
import CpsatScheduler.CostTable
import CpsatScheduler.ConstrainPERT

set_option linter.style.setOption false
set_option linter.style.nativeDecide false
set_option maxHeartbeats 400000

open Scipy.Convert
open Scipy
open CpsatScheduler
open CpsatSolver
open Constraint.PERT

example : roundToInt 3.4 = 3 := by native_decide
example : roundToInt 3.6 = 4 := by native_decide
example : roundToInt (-3.6) = -4 := by native_decide
example : floatToRat 3.14159 2 = (157 : ℚ) / 50 := by native_decide
example : (roundToInt64? 3.6).map (·.val) = some 4 := by native_decide

example :
    (let q := floatToRat 3.14159 2
     let e := roundToInt 3.14159
     |q - (e : ℚ)| ≤ roundingErrorBound) := by native_decide

example : (0 : ℚ) ≤ roundingErrorBound := roundingErrorBound_nonneg

example : pertPosition 1.0 8.0 1.0 = 0.0 := by native_decide
example : pertPosition 1.0 8.0 8.0 = 1.0 := by native_decide
example : pertPosition 1.0 8.0 0.0 = 0.0 := by native_decide
example : pertPosition 1.0 8.0 20.0 = 1.0 := by native_decide

example : (decide (Float.abs (pertPosition 0.0 8.0 4.0 - 0.5) < 0.0000001)) = true := by
  native_decide

example :
    (let exprs := #[
        pertCostExpr 1.0 3.0 8.0 1000.0 0.0,
        pertCostExpr 1.0 3.0 8.0 1000.0 2.0,
        pertCostExpr 1.0 3.0 8.0 1000.0 4.0]
     ((mkBatchScript exprs).repr.splitOn "print").length - 1) = 1 := by
  native_decide

example :
    (let exprs := #[pertCostExpr 1.0 3.0 8.0 1000.0 2.0]
     let text := (mkBatchScript exprs).repr
     ((text.splitOn "import beta").length - 1, (text.splitOn "import dumps").length - 1)) =
      (1, 1) := by
  native_decide

example :
    (((mkBatchScript #[pertCostExpr 1.0 3.0 8.0 1000.0 2.0]).repr.splitOn "beta.cdf").length
      - 1) = 1 := by
  native_decide

example : parseFloatArray "[1.5, 3.0, 6.25]" = Except.ok #[1.5, 3.0, 6.25] := by
  native_decide

example : (parseFloatArray "not json").toOption = none := by native_decide

def liveBatchDemo (runtime : Python.Runtime := { path := "./.venv/bin/python" }) :
    IO Unit := do
  let (handles, results) ← PertM.run runtime do
    let h0 ← PertM.request (pertCostExpr 1.0 3.0 8.0 1000.0 0.0)
    let h2 ← PertM.request (pertCostExpr 1.0 3.0 8.0 1000.0 2.0)
    let h4 ← PertM.request (pertCostExpr 1.0 3.0 8.0 1000.0 4.0)
    pure #[h0, h2, h4]
  IO.println s!"results ({results.size}): {results.toList}"
  for h in handles do
    IO.println s!"  handle {h.idx} → {results[h.idx]?}"

def unit4 : UnitScale := ⟨4, by decide, by decide⟩

def idCost : ℤ → ℚ := fun d => (d : ℚ)

def validPoints : Array CostPoint :=
  #[ ⟨CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 0⟩,
     ⟨CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 2⟩,
     ⟨CpsatSolver.Int64.of 4, CpsatSolver.Int64.of 4⟩ ]

example : (CostTable.ofPoints? unit4 validPoints idCost roundingErrorBound).isSome = true := by
  native_decide

example :
    (CostTable.ofPoints? unit4
      #[ ⟨CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 2⟩,
         ⟨CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3⟩ ]
      idCost roundingErrorBound).isNone = true := by
  native_decide

example :
    (CostTable.ofPoints? unit4
      #[ ⟨CpsatSolver.Int64.of 5, CpsatSolver.Int64.of 5⟩ ]
      idCost roundingErrorBound).isNone = true := by
  native_decide

example :
    (CostTable.ofPoints? unit4
      #[ ⟨CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 3⟩ ]
      idCost roundingErrorBound).isNone = true := by
  native_decide

example :
    (CostTable.ofPoints? unit4 #[] idCost roundingErrorBound).isNone = true := by
  native_decide

example :
    ((CostTable.ofPoints? unit4 validPoints idCost roundingErrorBound).map
      (fun t => t.allowedRows.map (fun v => (v[0].val, v[1].val)))) =
      some #[(0, 0), (2, 2), (4, 4)] := by
  native_decide

example :
    ((CostTable.ofPoints? unit4 validPoints idCost roundingErrorBound).map
      (fun t => (t.costHull.min.val, t.costHull.max.val))) = some (0, 4) := by
  native_decide

def unit8 : UnitScale := ⟨8, by decide, by decide⟩

def genConfig : Config :=
  { opt := 0.0, exp := 3.0, pes := 8.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

example :
    (let handle : CostTableHandle := { config := genConfig, start := 0 }
     let results := #[1000.0, 880.0, 610.0, 340.0, 140.0]
     (handle.resolve results unit8).map
       (fun t => (t.allowedRows.map
         (fun v => ((v[0] : CpsatSolver.Int64).val, (v[1] : CpsatSolver.Int64).val))))) =
      some #[(0, 1000), (1, 880), (2, 610), (3, 340), (4, 140)] := by
  native_decide

example :
    (let handle : CostTableHandle := { config := genConfig, start := 0 }
     let results := #[1000.0, 880.0, 610.0, 340.0, 140.0]
     (handle.resolve results unit8).map (fun t =>
       let costs : Array ℤ := t.points.map (fun p => (p.encodedCost : CpsatSolver.Int64).val)
       (Array.range 4).all (fun i => decide (costs[i + 1]! ≤ costs[i]!)))) = some true := by
  native_decide

example :
    (let handle : CostTableHandle := { config := genConfig, start := 2 }
     let results := #[99.0, 99.0, 1000.0, 880.0, 610.0, 340.0, 140.0]
     (handle.resolve results unit8).map (fun t => t.points.size)) = some 5 := by
  native_decide

example :
    (let handle : CostTableHandle := { config := genConfig, start := 0 }
     let results := #[1000.0, 880.0, 610.0, 340.0, 140.0]
     (handle.resolve results unit8).isSome) = true := by
  native_decide

def liveGenDemo (runtime : Python.Runtime := { path := "./.venv/bin/python" }) :
    IO Unit := do
  let (handles, results) ← PertM.run runtime do
    let h1 ← requestCostTable genConfig
    let h2 ← requestCostTable { genConfig with opt := 2.0, exp := 5.0, pes := 12.0 }
    pure #[h1, h2]
  for h in handles do
    match h.resolve results unit8 with
    | none => IO.println "  table: none"
    | some t =>
      let rows := (t.allowedRows.map
        (fun v => ((v[0] : CpsatSolver.Int64).val, (v[1] : CpsatSolver.Int64).val))).toList
      IO.println s!"  table rows (demand, cost): {rows}"
