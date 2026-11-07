import CpsatSolver
import CpsatScheduler.Defs
import CpsatScheduler.Task

import Mathlib.Tactic.IntervalCases

namespace CpsatScheduler.Constraint.CostDemand

open CpsatSolver

structure Point where
  timeDemanded : CpsatSolver.Int64
  encodedCost : CpsatSolver.Int64
deriving DecidableEq

def PointsInDomain (points : Array Point)
  (demand cost : Domain) : Prop :=
    ∀ p ∈ points,
      ((p.timeDemanded.val : ℤ) ∈ demand) ∧
      ((p.encodedCost.val : ℤ) ∈ cost)

structure Table (demand cost : Domain) where
  points : Array Point
  nonempty : points.size > 0
  within : PointsInDomain points demand cost

def Point.toVector (p : Point) :
    Vector CpsatSolver.Int64 2 :=
  Vector.mk
    #[ p.timeDemanded, p.encodedCost ]
    (by exact Nat.two_eq_digitChar.mp rfl)

instance (points : Array Point) (demand costDom : Domain) :
    Decidable (PointsInDomain points demand costDom) := by
  unfold PointsInDomain
  infer_instance

def Table.ofPoints? (demand cost : Domain)
  (points : Array Point)
  (nonempty : points.size > 0) :
    Option (Table demand cost) :=
  if h : PointsInDomain points demand cost then
    some ⟨points, nonempty, h⟩
  else
    none

def Table.constrain
  (id : EntityID)
  (task : Task S)
  (table : Table
    task.demand.domain
    task.cost.domain)
  (enforcement : Constraint.Enforcement) :
    Constraint :=
  let targetVars := Vector.mk
    #[task.demand, task.cost]
    (by exact Nat.add_zero ([task.cost].length + 1))
  {
    id := id
    variant := (.allowed_assignments (n := 2)
      targetVars
      (table.points.map (fun p => Point.toVector p))
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
    enforcement := enforcement
    label := .some s!"cost_demand_{task.label}"
  }

end CpsatScheduler.Constraint.CostDemand

