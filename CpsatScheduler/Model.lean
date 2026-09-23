import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.Constraints

open CpsatScheduler
open CpsatSolver

namespace CpsatScheduler

def TaskVars.of (task : Task S) :
    Builder (TaskVars S) := do
  let start ← Builder.newIntVar task.startDomain (some "task_a_start")
  let cost ← Builder.newIntVar
    (NonemptyDomain.interval
      (CpsatSolver.Interval.of 0 100))
    (some "task_a_cost")
  let demand ← Builder.newIntVar
    (NonemptyDomain.interval
      (CpsatSolver.Interval.of 0 task.unit
        (hl := by decide)
        (hr := task.unit.val.nonoverflow)
        (hlr := by exact Int.natCast_nonneg task.unit.val)))
    (some "task_a_demand")
  pure {
    task := task
    startVar := start.var
    costVar := cost.var
    timeDemandedVar := demand.var
    unit_eq := by rw [start.eq]
    time_demanded_le_unit := by
      rw [demand.eq]
      simp
  }

end CpsatScheduler
