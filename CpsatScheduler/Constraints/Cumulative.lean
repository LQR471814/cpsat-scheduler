import CpsatSolver.Model
import CpsatSolver.LinearExpr

namespace CpsatScheduler.Constraints.Cumulative

open CpsatSolver

structure Alloc where
  bucket : CpsatSolver.Int64
  value : CpsatSolver.Int64

/-- A cumulative item for a single allocation: a unit-size interval starting at
    `input.bucket` with constant demand `input.value`.

    Identity is structural — the interval and demand are fully determined by
    the allocation, so equal allocations produce equal items. -/
def itemOf
  (input : Alloc)
  (label : Option String := none) :
    Constraint.CumulativeItem :=
  let startExpr := CpsatSolver.LinearExpr.const input.bucket
  let interval : CpsatSolver.FixedSizeIntervalVar := {
    label := label
    start := startExpr
    size := CpsatSolver.Int64.of 1
    size_nonneg := by native_decide
  }
  let demandExpr := CpsatSolver.LinearExpr.const input.value
  {
    interval := interval
    demand := demandExpr.raw
    demandInterval := demandExpr.interval
    demand_proof := demandExpr.proof
  }

def constraint
  (allocs : Array Alloc)
  (capacity : CpsatSolver.LinearExpr)
  (enforcement : CpsatSolver.Constraint.Enforcement)
  (label : Option String := none) :
    CpsatSolver.Constraint :=
  let items := allocs.zipIdx.map
    (fun (item, idx) =>
      let label := label.map (fun p => s!"{p}_intv_{idx}")
      itemOf item label)
  {
    label := label
    enforcement := enforcement
    variant := .cumulative items capacity
  }

end CpsatScheduler.Constraints.Cumulative
