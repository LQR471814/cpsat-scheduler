import CpsatScheduler.Constraints.Cumulative
import CpsatScheduler.Task

namespace CpsatScheduler.Constraints

open CpsatSolver

-- add_cumulative constraint for a single timescale
private def packSingleLayer {TP : TaskParams}
  (u : TP.units.elem)
  (tasks : Array (Task TP))
  (allocs : Array Cumulative.Alloc)
  (allocUnit : TP.units.elem)
    : CpsatSolver.Constraint.Variant :=
  let tasksUnitEq := tasks.filter
    (fun x => decide (x.task.unit = u))
  let itemsUnitEq <- tasksUnitEq.mapM
    (fun (t : TaskVars scales) => do
      let interval <- CpsatSolver.Builder.newFixedSizeInterval
        (.var t.startVar) (CpsatSolver.Int64.of 1) (by native_decide)
      let result : CpsatSolver.CumulativeItem := {
        interval := interval.val
        demand := (
          CpsatSolver.LinearExpr.var t.timeDemandedVar
        ).wrapInterval
      }
      pure result)
  let tasksUnitLt :=
    (tasks.filter
      (fun x => decide (x.task.unit < u))).attachWith
        (fun x => decide (x.task.unit < u) = true)
        (fun x hx => (Array.mem_filter.mp hx).2)
  let itemsUnitLt <- tasksUnitLt.mapM
    (α := { x : TaskVars scales // decide (↑x.task.unit < u) = true })
    (β := CpsatSolver.CumulativeItem)
    (fun el => do
      let task := el.val.task
      let startVar := el.val.startVar
      let startLinExpr := CpsatSolver.LinearExpr.var startVar
      have taskunit_lt_u : task.unit < u := of_decide_eq_true el.prop
      have taskunit_le_u : task.unit.val ≤ u.val :=
        LT.lt.le (a := task.unit.val.val) (b := u.val) taskunit_lt_u
      let normalized : UnitAware.IntVar u <-
        UnitAware.truncCoarsen
          (u := task.unit) (v := u)
          ⟨startVar.domainHull, startLinExpr⟩
          (scales.units.divisibility
            u
            u_in_scales
            task.unit.val
            task.unit.mem
            taskunit_le_u)
          none
      let interval <- CpsatSolver.Builder.newFixedSizeInterval
        (.var normalized.var) (CpsatSolver.Int64.of 1) (by native_decide)
      let result : CpsatSolver.CumulativeItem := {
        interval := interval.val
        demand := (
          CpsatSolver.LinearExpr.var el.val.timeDemandedVar
        ).wrapInterval
      }
      pure result
    )
  let capacity : CpsatSolver.LinearExpr.WithInterval :=
    {
      fst := {
        left := u
        right := u
        left_le_right := by exact Int.le_refl u
      }
      snd := .const u
    }
  let itemsAlloc <-
    if u = allocUnit then Alloc.cumulativeItems allocs
    else pure #[]
  let result : CpsatSolver.Constraint.Variant :=
    .cumulative
      (itemsUnitEq
        ++ itemsUnitLt
        ++ itemsAlloc)
      capacity
  pure result

def pack {TP : TaskParams}
  (tasks : Array (Task TP))
  (allocs : Array Cumulative.Alloc)
  (allocUnit : TP.units.elem) : Array Constraint :=
  (TP.units.fs.sort.attach.map
    (fun unit =>
      {
        variant := packSingleLayer
          ⟨unit.val, (unit.val.mem_sort unit.prop)⟩
          tasks
          allocs
          allocUnit
        enforcement := .always
      }))

end CpsatScheduler.Constraints
