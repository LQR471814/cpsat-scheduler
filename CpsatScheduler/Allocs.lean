import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.TaskVars
import CpsatScheduler.Schedule.Event

open CpsatScheduler.Schedule (Alloc)

namespace CpsatScheduler.Alloc

structure Input where
  bucket : CpsatSolver.Int64
  alloc : CpsatSolver.Int64

def Input.ofAlloc? (a : Alloc) : Option Input :=
  if hb : CpsatSolver.Int64.Nonoverflow a.bucket then
    if ha : CpsatSolver.Int64.Nonoverflow a.alloc then
      some { bucket := ⟨a.bucket, hb⟩, alloc := ⟨a.alloc, ha⟩ }
    else none
  else none

def checkAllocs (allocs : List Alloc) : Option (List Input) :=
  allocs.mapM Input.ofAlloc?

def allocItem
    (input : Input)
    (label : Option String := none) :
    CpsatSolver.Builder CpsatSolver.CumulativeItem := do
  let startExpr := CpsatSolver.LinearExpr.const input.bucket
  let interval ← CpsatSolver.Builder.newFixedSizeInterval
    startExpr (CpsatSolver.Int64.of 1) (by decide) label
  let demandExpr := CpsatSolver.LinearExpr.const input.alloc
  pure {
    interval := interval.val
    demand := demandExpr.wrapBounds
  }

def allocItems
    (allocs : List Input)
    (labelPrefix : Option String := none) :
    CpsatSolver.Builder (Array CpsatSolver.CumulativeItem) := do
  let values ← allocs.zipIdx.mapM
    (fun (input, idx) =>
      let label := labelPrefix.map (fun p => s!"{p}_bg_{idx}")
      let item := allocItem input label
      item)
  pure values.toArray

end CpsatScheduler.Alloc

