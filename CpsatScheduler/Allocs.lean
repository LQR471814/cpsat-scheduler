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
    startInterval := CpsatSolver.Interval.ofValue input.bucket
    start := startExpr
    size := CpsatSolver.Int64.of 1
    size_nonneg := by native_decide
  }
  let demandExpr := CpsatSolver.LinearExpr.const input.alloc
  {
    interval := interval
    demand := demandExpr.wrapInterval
  }

def cumulative
    (id : CpsatSolver.EntityID)
    (allocs : Array Nonoverflow)
    (capacity : CpsatSolver.LinearExpr.WithInterval)
    (enforcement : CpsatSolver.Constraint.Enforcement)
    (label : Option String := none) :
      CpsatSolver.Constraint :=
  let items := allocs.zipIdx.map
    (fun (item, idx) =>
      let label := label.map (fun p => s!"{p}_intv_{id + idx}")
      cumulativeItem id item label)
  {
    id := id
    label := label
    enforcement := enforcement
    variant := .cumulative items capacity
  }

end CpsatScheduler.Alloc

