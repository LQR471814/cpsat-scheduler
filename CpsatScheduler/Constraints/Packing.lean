import CpsatScheduler.Constraints.Cumulative
import CpsatScheduler.Task

namespace CpsatScheduler.Constraints

open CpsatSolver

-- for each unit layer, we have one unique fixed size interval allocated for
-- each task with unit ≤ to the the unit layer

-- add_cumulative constraint for a single timescale
private def packSingleLayer {TP : TaskParams}
  (u : TP.units.elem)
  (tasks : Array (Task TP))
  (allocs : Array Cumulative.Alloc)
  (allocUnit : TP.units.elem)
    : Constraint.Variant :=
  let itemsUnitEq := tasks
    |> Array.filter fun t => decide (t.unit = u)
    |> Array.map fun t =>
      let interval : FixedSizeIntervalVar := {
        id := sorry
        startInterval := t.start
        start := .var t.start
        size := Int64.of 1
        size_nonneg := by native_decide
        label := .none
      }
      let result : CumulativeItem := {
        interval := interval.val
        demand :=
          (LinearExpr.var t.timeDemandedVar).wrapInterval
      }
      result
  let tasksUnitLt := tasks
    |> Array.filter fun x => decide (x.task.unit < u)
    |> Array.attachWith
        fun x => decide (x.task.unit < u) = true
        fun x hx => (Array.mem_filter.mp hx).2
  let itemsUnitLt <- tasksUnitLt.mapM
    (α := { x : TaskVars scales // decide (↑x.task.unit < u) = true })
    (β := CumulativeItem)
    (fun el => do
      let task := el.val.task
      let startVar := el.val.startVar
      let startLinExpr := LinearExpr.var startVar
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
      let interval <- Builder.newFixedSizeInterval
        (.var normalized.var) (Int64.of 1) (by native_decide)
      let result : CumulativeItem := {
        interval := interval.val
        demand := (
          LinearExpr.var el.val.timeDemandedVar
        ).wrapInterval
      }
      pure result
    )
  let capacity : LinearExpr.WithInterval :=
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
  let result : Constraint.Variant :=
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
