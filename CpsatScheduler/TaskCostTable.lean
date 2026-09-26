import CpsatScheduler.Defs

namespace CpsatScheduler

theorem TaskCostTable.pointsNeNil {scales : Timescales} {task : Task scales}
    (table : TaskCostTable task) : table.points.toList ≠ [] := by
  intro h
  have : table.points.size = 0 := by
    rw [← Array.length_toList, h, List.length_nil]
  exact (Nat.not_lt_of_ge (Nat.le_of_eq this)) table.nonempty

def TaskCostTable.demandDomain {scales : Timescales} {task : Task scales}
    (table : TaskCostTable task) : CpsatSolver.NonemptyDomain :=
  CpsatSolver.Domain.ofListNonempty
    (table.points.toList.map fun p => CpsatSolver.Interval.ofValue p.timeDemanded)
    (by
      intro h
      exact TaskCostTable.pointsNeNil table (List.map_eq_nil_iff.mp h))

def TaskCostTable.costDomain {scales : Timescales} {task : Task scales}
    (table : TaskCostTable task) : CpsatSolver.NonemptyDomain :=
  CpsatSolver.Domain.ofListNonempty
    (table.points.toList.map fun p => CpsatSolver.Interval.ofValue p.encodedCost)
    (by
      intro h
      exact TaskCostTable.pointsNeNil table (List.map_eq_nil_iff.mp h))

def TaskCostTable.allowedRows {scales : Timescales} {task : Task scales}
    (table : TaskCostTable task) : Array (Vector CpsatSolver.Int64 2) :=
  table.points.map fun p =>
    Vector.mk #[p.timeDemanded, p.encodedCost] rfl

end CpsatScheduler
