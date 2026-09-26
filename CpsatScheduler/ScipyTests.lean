import CpsatScheduler.Scipy.Convert
import CpsatScheduler.Scipy.PERT
import CpsatScheduler.Scipy.Batch
import CpsatScheduler.TaskCostTable
import CpsatScheduler.Task
import CpsatScheduler.ConstrainPERT

set_option linter.style.setOption false
set_option linter.style.nativeDecide false
set_option maxHeartbeats 400000

open Scipy.Convert
open Scipy
open CpsatScheduler
open CpsatSolver
open Constraint.PERT

/-! ## Task 1: Float → Int64 / ℚ conversion helpers -/

/-- Nearest-integer rounding, below the half. -/
example : floatToInt 3.4 = 3 := by native_decide

/-- Nearest-integer rounding, above the half. -/
example : floatToInt 3.6 = 4 := by native_decide

/-- Negative values round toward the nearest integer. -/
example : floatToInt (-3.6) = -4 := by native_decide

/-- Exact rational approximation at two decimal digits. -/
example : floatToRat 3.14159 2 = (157 : ℚ) / 50 := by native_decide

/-- Rounding a float to `Int64` succeeds within range. -/
example : (roundToInt64? 3.6).map (·.val) = some 4 := by native_decide

/-- The rounding error bound `1/2` genuinely bounds `|trueCost - encodedCost|`
for a representative value. -/
example :
    (let q := floatToRat 3.14159 2
     let e := floatToInt 3.14159
     |q - (e : ℚ)| ≤ roundingErrorBound) := by native_decide

/-- `roundingErrorBound` is nonnegative (reused as `errorBound`). -/
example : (0 : ℚ) ≤ roundingErrorBound := roundingErrorBound_nonneg

/-! ## Task 2: quadratic quantile probability generator -/

/-- `pertProbs steps` has exactly `steps` entries. -/
example : (pertProbs 5).size = 5 := by native_decide

/-- Every generated probability lies strictly inside `(0, 1)`. -/
example : (pertProbs 5).all (fun p => p > 0.0 && p < 1.0) = true := by native_decide

/-- The probabilities are strictly increasing (monotone quantiles), default
(`backLoaded`) spacing. -/
example :
    (Array.range 4).all (fun i => (pertProbs 5)[i]! < (pertProbs 5)[i + 1]!) = true := by
  native_decide

/-- Default spacing is `backLoaded`: points cluster near `1`, so the gap between
the first two points **exceeds** the gap between the last two. -/
example :
    (decide (((pertProbs 5)[1]! - (pertProbs 5)[0]!) >
      ((pertProbs 5)[4]! - (pertProbs 5)[3]!))) = true := by
  native_decide

/-- `frontLoaded` mirrors the default: points cluster near `0`, so the last gap
exceeds the first gap. -/
example :
    (decide (((pertProbs 5 Spacing.frontLoaded)[1]! - (pertProbs 5 Spacing.frontLoaded)[0]!) <
      ((pertProbs 5 Spacing.frontLoaded)[4]! - (pertProbs 5 Spacing.frontLoaded)[3]!))) = true := by
  native_decide

/-- Every spacing keeps probabilities strictly inside `(0, 1)`. -/
example :
    ((pertProbs 5 Spacing.frontLoaded).all (fun p => p > 0.0 && p < 1.0) &&
     (pertProbs 5 Spacing.backLoaded).all (fun p => p > 0.0 && p < 1.0) &&
     (pertProbs 5 Spacing.linear).all (fun p => p > 0.0 && p < 1.0)) = true := by
  native_decide

/-- `linear` spacing has (approximately) equal gaps: the first and last gaps
agree up to floating-point tolerance. -/
example :
    (let g1 := (pertProbs 5 Spacing.linear)[1]! - (pertProbs 5 Spacing.linear)[0]!
     let g2 := (pertProbs 5 Spacing.linear)[4]! - (pertProbs 5 Spacing.linear)[3]!
     decide (Float.abs (g1 - g2) < 0.0000001)) = true := by
  native_decide

/-! ## Task 3: `PertM` batching monad (single-script flush) -/

/-- The batched script emits **exactly one** `print`, no matter how many
expressions are requested (the core anti-overhead guarantee). -/
example :
    (let exprs := #[
        pertPointExpr 1.0 3.0 10.0 0.1,
        pertPointExpr 1.0 3.0 10.0 0.5,
        pertPointExpr 1.0 3.0 10.0 0.9]
     ((mkBatchScript exprs).repr.splitOn "print").length - 1) = 1 := by
  native_decide

/-- The batched script imports `beta` and `dumps` once each (single setup). -/
example :
    (let exprs := #[pertPointExpr 1.0 3.0 10.0 0.5]
     let text := (mkBatchScript exprs).repr
     ((text.splitOn "import beta").length - 1, (text.splitOn "import dumps").length - 1)) =
      (1, 1) := by
  native_decide

/-- `parseFloatArray` reads a JSON float array. -/
example : parseFloatArray "[1.5, 3.0, 6.25]" = Except.ok #[1.5, 3.0, 6.25] := by
  native_decide

/-- `parseFloatArray` rejects non-array / malformed JSON. -/
example : (parseFloatArray "not json").toOption = none := by native_decide

/-- Handles resolve positionally against a resolved results array. -/
example : (PertHandle.mk 1).resolve #[10.0, 20.0, 30.0] = some 20.0 := by native_decide

/-- Opt-in live batch run (requires a Python runtime with scipy on `path`).
Not forced during a normal build; invoke manually via `#eval liveBatchDemo` with
a valid runtime. Verifies a single subprocess yields all requested values. -/
def liveBatchDemo (runtime : Python.Runtime := { path := "./.venv/bin/python" }) :
    IO Unit := do
  let (handles, results) ← PertM.run runtime do
    let h1 ← PertM.request (pertPointExpr 1.0 3.0 10.0 0.1)
    let h2 ← PertM.request (pertPointExpr 1.0 3.0 10.0 0.5)
    let h3 ← PertM.request (pertPointExpr 1.0 3.0 10.0 0.9)
    pure #[h1, h2, h3]
  IO.println s!"results ({results.size}): {results.toList}"
  for h in handles do
    IO.println s!"  handle {h.idx} → {h.resolve results}"


/-! ## Task 4: `TaskCostTable.ofPoints?` smart constructor -/

/-- Test scales: units `{1, 4}` over horizon `[0, 24)`. -/
def testScales : Timescales :=
  let unit4 : UnitScale := ⟨4, by decide, by decide⟩
  let units : Units :=
    { set := {UnitScale.atomic, unit4}
      has_atomic := by decide
      divisibility := by decide }
  let horizon : Horizon :=
    { begin := 0, end_ := 24, begin_lt_end := by decide,
      begin_safe := by decide, end_safe := by decide }
  Timescales.mk units horizon

/-- Test task on unit `4`: demands range over `[0, 4]`. -/
def testTask : Task testScales :=
  Task.ofBucketRange testScales { val := 7 }
    (Subtype.mk ⟨4, by decide, by decide⟩ (by decide))
    (kLo := 0) (kHi := 5)
    (hle := by decide) (hbegin := by decide) (hend := by decide)
    (label := some "cost_task")

/-- Identity-ish trueCost: cost equals the demand as a rational (so encoded cost
= demand rounds to itself, closeness holds with any nonneg bound). -/
def idCost : ℤ → ℚ := fun d => (d : ℚ)

/-- Valid point set (unique demands in `[0,4]`, encoded = trueCost exactly). -/
def validPoints : Array CostPoint :=
  #[ ⟨CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 0⟩,
     ⟨CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 2⟩,
     ⟨CpsatSolver.Int64.of 4, CpsatSolver.Int64.of 4⟩ ]

/-- A valid point set builds `some`. -/
example :
    (TaskCostTable.ofPoints? testTask validPoints idCost roundingErrorBound).isSome = true := by
  native_decide

/-- Duplicate demand ⇒ `none`. -/
example :
    (TaskCostTable.ofPoints? testTask
      #[ ⟨CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 2⟩,
         ⟨CpsatSolver.Int64.of 2, CpsatSolver.Int64.of 3⟩ ]
      idCost roundingErrorBound).isNone = true := by
  native_decide

/-- Out-of-bounds demand (`5 > unit 4`) ⇒ `none`. -/
example :
    (TaskCostTable.ofPoints? testTask
      #[ ⟨CpsatSolver.Int64.of 5, CpsatSolver.Int64.of 5⟩ ]
      idCost roundingErrorBound).isNone = true := by
  native_decide

/-- `encodedClose` violation (trueCost 0 = 0 but encoded = 3, error > 1/2) ⇒ `none`. -/
example :
    (TaskCostTable.ofPoints? testTask
      #[ ⟨CpsatSolver.Int64.of 0, CpsatSolver.Int64.of 3⟩ ]
      idCost roundingErrorBound).isNone = true := by
  native_decide

/-- Empty point set ⇒ `none`. -/
example :
    (TaskCostTable.ofPoints? testTask #[] idCost roundingErrorBound).isNone = true := by
  native_decide

/-- The built table exposes the expected allowed rows `[demand, cost]`. -/
example :
    ((TaskCostTable.ofPoints? testTask validPoints idCost roundingErrorBound).map
      (fun t => t.allowedRows.map (fun v => (v[0].val, v[1].val)))) =
      some #[(0, 0), (2, 2), (4, 4)] := by
  native_decide


/-! ## Task 5: end-to-end `genCostTable` wiring -/

/-- A larger unit-8 task so demands `0..4` fit within `[0, 8]`. -/
def genScales : Timescales :=
  let unit8 : UnitScale := ⟨8, by decide, by decide⟩
  let units : Units :=
    { set := {UnitScale.atomic, unit8}, has_atomic := by decide, divisibility := by decide }
  let horizon : Horizon :=
    { begin := 0, end_ := 24, begin_lt_end := by decide,
      begin_safe := by decide, end_safe := by decide }
  Timescales.mk units horizon

def genTask : Task genScales :=
  Task.ofBucketRange genScales { val := 1 }
    (Subtype.mk ⟨8, by decide, by decide⟩ (by decide))
    (kLo := 0) (kHi := 2) (hle := by decide) (hbegin := by decide) (hend := by decide)

def genConfig : Config :=
  { opt := 0.0, exp := 3.0, pes := 8.0, steps := 5, steps_nonzero := by decide }

/-- Pure phase-2 assembly over synthetic (deterministic) PERT results yields a
valid table with the demand grid `0..4` and rounded costs. -/
example :
    (let handles := #[PertHandle.mk 0, PertHandle.mk 1, PertHandle.mk 2,
        PertHandle.mk 3, PertHandle.mk 4]
     let results := #[0.4, 1.6, 3.2, 5.1, 7.8]
     (assembleTable genTask handles results).map
       (fun t => (t.allowedRows.map
         (fun v => ((v[0] : CpsatSolver.Int64).val, (v[1] : CpsatSolver.Int64).val))))) =
      some #[(0, 0), (1, 2), (2, 3), (3, 5), (4, 8)] := by
  native_decide

/-- Assembly produces exactly `steps` points. -/
example :
    (let handles := #[PertHandle.mk 0, PertHandle.mk 1, PertHandle.mk 2,
        PertHandle.mk 3, PertHandle.mk 4]
     let results := #[0.4, 1.6, 3.2, 5.1, 7.8]
     (assembleTable genTask handles results).map (fun t => t.points.size)) = some 5 := by
  native_decide

/-- The assembled table's `encodedClose` obligation is discharged (it is a
`some`), confirming rounding error stays within `errorBound = 1/2`. -/
example :
    (let handles := #[PertHandle.mk 0, PertHandle.mk 1, PertHandle.mk 2,
        PertHandle.mk 3, PertHandle.mk 4]
     let results := #[0.4, 1.6, 3.2, 5.1, 7.8]
     (assembleTable genTask handles results).isSome) = true := by
  native_decide

/-- Opt-in live end-to-end run (requires Python + scipy at `runtime.path`).
Not forced during a normal build; invoke via `#eval liveGenDemo`. Verifies a
single Python execution yields a populated, certified `TaskCostTable`. -/
def liveGenDemo (runtime : Python.Runtime := { path := "./.venv/bin/python" }) :
    IO Unit := do
  let t ← runGenCostTable runtime genConfig genTask
  match t with
  | none => IO.println "genCostTable: none (validation failed)"
  | some tbl =>
    let rows := (tbl.allowedRows.map
      (fun v => ((v[0] : CpsatSolver.Int64).val, (v[1] : CpsatSolver.Int64).val))).toList
    IO.println s!"genCostTable rows (demand, cost): {rows}"
