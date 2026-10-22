import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.CpsatSolver.LinearExpr
import CpsatScheduler.TaskVars
import CpsatScheduler.Schedule.Event

open CpsatScheduler.Schedule (Alloc)

namespace CpsatScheduler.Alloc

structure Nonoverflow where
  bucket : CpsatSolver.Int64
  alloc : CpsatSolver.Int64

def cumulativeItem
    (intervalID : CpsatSolver.EntityID)
    (input : Nonoverflow)
    (label : Option String := none) :
      CpsatSolver.CumulativeItem :=
  let startExpr := CpsatSolver.LinearExpr.const input.bucket
  let interval : CpsatSolver.FixedSizeIntervalVar := {
    id := intervalID
    label := label
    startBounds := CpsatSolver.Interval.ofValue input.bucket
    start := startExpr
    size := CpsatSolver.Int64.of 1
    size_nonneg := by decide
  }
  let demandExpr := CpsatSolver.LinearExpr.const input.alloc
  {
    interval := interval
    demand := demandExpr.wrapBounds
  }

def cumulativeItems
    (allocs : List Nonoverflow)
    (labelPrefix : Option String := none) :
      Array CpsatSolver.CumulativeItem := do
  let values ← allocs.zipIdx.mapM
    (fun (input, idx) =>
      let label := labelPrefix.map (fun p => s!"{p}_bg_{idx}")
      let item := cumulativeItem input label
      item)
  pure values.toArray

-- TODO: finish migrating CpsatSolver refactors to the rest of the package
-- TODO: figure out a better way of allocating ids without requiring monadic builders

end CpsatScheduler.Alloc

