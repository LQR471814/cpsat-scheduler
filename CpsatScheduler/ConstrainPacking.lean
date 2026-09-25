import CpsatScheduler.UnitAware
import CpsatScheduler.TaskVars

namespace CpsatScheduler

-- add_cumulative constraint for a single timescale
def Constraint.packSingleLayer
  {scales : Timescales}
  (u : UnitScale)
  (u_in_scales : u ∈ scales.units.set := by decide)
  (tasks : Array (TaskVars scales))
    : CpsatSolver.Builder CpsatSolver.Constraint.Variant := do
  let tasksUnitEq := tasks.filter
    (fun x => decide (x.task.unit = u))
  let itemsUnitEq <- tasksUnitEq.mapM
    (fun (t : TaskVars scales) => do
      let interval <- CpsatSolver.Builder.newFixedSizeInterval
        (.var t.startVar) u
        (by exact Int.natCast_nonneg u.val)
      let result : CpsatSolver.CumulativeItem := {
        interval := interval.val
        demand := (
          CpsatSolver.LinearExpr.var t.timeDemandedVar
        ).wrapBounds
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
          ⟨startVar.domain.hull, startLinExpr⟩
          (scales.units.divisibility
            u
            u_in_scales
            task.unit.val
            task.unit.mem
            taskunit_le_u)
          none
      let interval <- CpsatSolver.Builder.newFixedSizeInterval
        (.var normalized.var) u
        (by exact Int.natCast_nonneg u.val)
      let result : CpsatSolver.CumulativeItem := {
        interval := interval.val
        demand := (
          CpsatSolver.LinearExpr.var el.val.timeDemandedVar
        ).wrapBounds
      }
      pure result
    )
  let capacity : CpsatSolver.LinearExpr.WithBounds :=
    {
      fst := {
        left := u
        right := u
        left_le_right := by exact Int.le_refl u
      }
      snd := .const u
    }
  let result : CpsatSolver.Constraint.Variant :=
    .cumulative (itemsUnitEq ++ itemsUnitLt) capacity
  pure result

def Constraint.packing
  {scales : Timescales}
  (tasks : Array (TaskVars scales))
    : CpsatSolver.Builder Unit := do
  let _ <- (UnitScale.sort scales.units.set).attach.mapM
    (fun unit => do
      let cnstr <- (Constraint.packSingleLayer
        unit.val
        (unit.val.mem_sort unit.prop)
        tasks)
      let _ <- CpsatSolver.Builder.addConstraint .always cnstr none)
  pure ()

end CpsatScheduler
