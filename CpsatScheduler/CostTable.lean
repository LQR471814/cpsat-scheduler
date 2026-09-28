import CpsatScheduler.TaskVars

open CpsatSolver
open CpsatScheduler

structure CostDemandPoint where
  timeDemanded : CpsatSolver.Int64
  encodedCost : CpsatSolver.Int64
deriving DecidableEq

def CostDemandPoint.toVector (p : CostDemandPoint) :
    Vector CpsatSolver.Int64 2 :=
  Vector.mk
    #[ p.timeDemanded, p.encodedCost ]
    (by exact Nat.two_eq_digitChar.mp rfl)

structure CostDemandTable where
  points : Array CostDemandPoint

def CostDemandTable.constrain (table : CostDemandTable)
  (task : TaskVars S)
  (enforcement : Constraint.Enforcement) := do
  let targetVars := Vector.mk
    #[ task.timeDemandedVar, task.costVar ]
    (by exact Nat.add_zero ([task.costVar].length + 1))
  Builder.addConstraint enforcement
    (.allowed_assignments (n := 2)
      targetVars
      (table.points.map (fun p => CostDemandPoint.toVector p)))
    (.some s!"cost_demand_{task.task.label}")

