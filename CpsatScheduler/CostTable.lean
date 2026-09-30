import CpsatScheduler.TaskVars
import Mathlib.Tactic.IntervalCases

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

abbrev PointsInDomain (points : Array CostDemandPoint)
  (demandDom costDom : Domain) :=
    ∀ p ∈ points,
      ((p.timeDemanded.val : ℤ) ∈ demandDom) ∧
      ((p.encodedCost.val : ℤ) ∈ costDom)

structure CostDemandTable (demandDom costDom : Domain) where
  points : Array CostDemandPoint
  nonempty : points.size > 0
  within : PointsInDomain points demandDom costDom

def CostDemandTable.ofPoints? (demandDom costDom : Domain)
  (points : Array CostDemandPoint)
  (nonempty : points.size > 0) :
    Option (CostDemandTable demandDom costDom) :=
  if h : PointsInDomain points demandDom costDom then
    some ⟨points, nonempty, h⟩
  else
    none

def CostDemandTable.constrain
  (task : TaskVars S)
  (table : CostDemandTable
    task.timeDemandedVar.domain.domain
    task.costVar.domain.domain)
  (enforcement : Constraint.Enforcement) := do
  let targetVars := Vector.mk
    #[task.timeDemandedVar, task.costVar]
    (by exact Nat.add_zero ([task.costVar].length + 1))
  Builder.addConstraint enforcement
    (.allowed_assignments (n := 2)
      targetVars
      (table.points.map (fun p => CostDemandPoint.toVector p))
      (by
        -- size of a mapped array equals the size of the original
        rw [Array.size_map]
        exact table.nonempty)
      (by
          -- every mapped row lies within the corresponding variable's domain
        intro row hrow i
        -- `row` comes from mapping `toVector` over the table points
        rw [Array.mem_map] at hrow
        obtain ⟨p, hp, hpr⟩ := hrow
        subst hpr
        -- `targetVars` has exactly two entries, so `i` is 0 or 1
        obtain ⟨iv, hiv⟩ := i
        have hsize : targetVars.size = 2 := rfl
        rw [hsize] at hiv
        interval_cases iv
        · exact (table.within p hp).1
        · exact (table.within p hp).2))
    (.some s!"cost_demand_{task.task.label}")
