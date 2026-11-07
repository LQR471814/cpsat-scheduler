import CpsatSolver.Model
import CpsatSolver.LinearExpr

namespace CpsatScheduler.Constraints.Cumulative

structure Alloc where
  bucket : CpsatSolver.Int64
  value : CpsatSolver.Int64

def itemOf
    (intervalID : CpsatSolver.EntityID)
    (input : Alloc)
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
  let demandExpr := CpsatSolver.LinearExpr.const input.value
  {
    interval := interval
    demand := demandExpr.wrapInterval
  }

def constraint
    (id : CpsatSolver.EntityID)
    (allocs : Array Alloc)
    (capacity : CpsatSolver.LinearExpr.WithInterval)
    (enforcement : CpsatSolver.Constraint.Enforcement)
    (label : Option String := none) :
      CpsatSolver.Constraint :=
  let items := allocs.zipIdx.map
    (fun (item, idx) =>
      let label := label.map (fun p => s!"{p}_intv_{id + idx}")
      itemOf id item label)
  {
    id := id
    label := label
    enforcement := enforcement
    variant := .cumulative items capacity
  }

end CpsatScheduler.Constraints.Cumulative
