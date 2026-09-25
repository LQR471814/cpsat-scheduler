import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task

open CpsatScheduler
open CpsatSolver

namespace CpsatScheduler

/-- Nonnegative task start in bucket-index coordinates. -/
structure TaskVars (S : Timescales) where
  task : Task S
  startVar : CpsatSolver.IntVar
  unit_eq : startVar.domain = task.startDomain
  costVar : CpsatSolver.IntVar
  timeDemandedVar : CpsatSolver.IntVar
  time_demanded_le_unit :
    timeDemandedVar.domain.min ≥ (0 : ℤ) ∧
    timeDemandedVar.domain.max.val ≤ task.unit.val

@[simp] def TaskVars.startDomain (task : Task S) := task.startDomain

@[simp] def TaskVars.costDomain :=
  NonemptyDomain.interval
    (CpsatSolver.Interval.of 0 100)

@[simp] def TaskVars.demandDomain (task : Task S) :=
  (NonemptyDomain.interval
    (CpsatSolver.Interval.of 0 task.unit
      (hl := by decide)
      (hr := task.unit.val.nonoverflow)
      (hlr := by exact Int.natCast_nonneg task.unit.val)))

structure TaskVarsResult (S : Timescales) (t : Task S) where
  vars : TaskVars S
  start_domain : vars.startVar.domain = (TaskVars.startDomain t)
  cost_domain : vars.costVar.domain = TaskVars.costDomain
  demand_domain : vars.timeDemandedVar.domain = (TaskVars.demandDomain t)

def TaskVars.of (t : Task S) : Builder (TaskVarsResult S t) := do
  let prefix_ := t.label.getD s!"task_{t.id.val}"
  let start ← Builder.newIntVar
    (TaskVars.startDomain t)
    (some s!"{prefix_}_start")
  let cost ← Builder.newIntVar
    TaskVars.costDomain
    (some s!"{prefix_}_cost")
  let demand ← Builder.newIntVar
    (TaskVars.demandDomain t)
    (some s!"{prefix_}_demand")
  let vars : TaskVars S := {
    task := t
    startVar := start.val
    costVar := cost.val
    timeDemandedVar := demand.val
    unit_eq := start.property.1
    time_demanded_le_unit := by
      rw [demand.property.1]
      simp
  }
  pure {
    vars := vars
    start_domain := start.prop.1
    cost_domain := cost.prop.1
    demand_domain := demand.prop.1
  }

end CpsatScheduler
