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

/-! ## Smart constructor `ofPoints?`

Validates a candidate point array (plus a caller-supplied `trueCost`/`errorBound`)
against every `TaskCostTable` proof obligation using decidable boolean checks, in
the `idsUniqueB` / `idsUniqueB_iff` style, and returns a fully proof-carrying
`TaskCostTable` or `none`. -/

/-- Decidable uniqueness of demands (mirrors `CpsatSolver.idsUniqueB`). -/
def CostPoint.uniqueDemandB (points : Array CostPoint) : Bool :=
  (List.finRange points.size).all fun i =>
    (List.finRange points.size).all fun j =>
      decide (i = j ∨ points[i].timeDemanded ≠ points[j].timeDemanded)

theorem CostPoint.uniqueDemandB_iff (points : Array CostPoint) :
    CostPoint.uniqueDemandB points = true ↔
      ∀ i j : Fin points.size, i ≠ j →
        points[i].timeDemanded ≠ points[j].timeDemanded := by
  unfold CostPoint.uniqueDemandB
  rw [List.all_eq_true]
  constructor
  · intro h i j hij
    have hi := h i (List.mem_finRange i)
    rw [List.all_eq_true] at hi
    have hj := of_decide_eq_true (hi j (List.mem_finRange j))
    cases hj with
    | inl heq => exact (hij heq).elim
    | inr hne => exact hne
  · intro h i _hi
    rw [List.all_eq_true]
    intro j _hj
    refine decide_eq_true ?_
    by_cases heq : i = j
    · exact Or.inl heq
    · exact Or.inr (h i j heq)

/-- Decidable demand-bounds check. -/
def CostPoint.demandBoundsB {scales : Timescales} (task : Task scales)
    (points : Array CostPoint) : Bool :=
  points.all fun p =>
    decide ((0 : ℤ) ≤ p.timeDemanded.val ∧ p.timeDemanded.val ≤ task.unit.val.val)

theorem CostPoint.demandBoundsB_iff {scales : Timescales} (task : Task scales)
    (points : Array CostPoint) :
    CostPoint.demandBoundsB task points = true ↔
      ∀ p ∈ points, (0 : ℤ) ≤ p.timeDemanded.val ∧
        p.timeDemanded.val ≤ task.unit.val.val := by
  unfold CostPoint.demandBoundsB
  rw [Array.all_eq_true']
  constructor
  · intro h p hp
    exact of_decide_eq_true (h p hp)
  · intro h p hp
    exact decide_eq_true (h p hp)

/-- Decidable closeness check against a concrete `trueCost`/`errorBound`. -/
def CostPoint.encodedCloseB (points : Array CostPoint)
    (trueCost : ℤ → ℚ) (errorBound : ℚ) : Bool :=
  points.all fun p =>
    decide (|trueCost p.timeDemanded.val - (p.encodedCost.val : ℚ)| ≤ errorBound)

theorem CostPoint.encodedCloseB_iff (points : Array CostPoint)
    (trueCost : ℤ → ℚ) (errorBound : ℚ) :
    CostPoint.encodedCloseB points trueCost errorBound = true ↔
      ∀ p ∈ points,
        |trueCost p.timeDemanded.val - (p.encodedCost.val : ℚ)| ≤ errorBound := by
  unfold CostPoint.encodedCloseB
  rw [Array.all_eq_true']
  constructor
  · intro h p hp
    exact of_decide_eq_true (h p hp)
  · intro h p hp
    exact decide_eq_true (h p hp)

/-- Smart constructor: build a `TaskCostTable` from a candidate point array and a
caller-supplied `trueCost`/`errorBound`, validating every proof obligation.
Returns `none` if any check fails. -/
def TaskCostTable.ofPoints? {scales : Timescales} (task : Task scales)
    (points : Array CostPoint) (trueCost : ℤ → ℚ) (errorBound : ℚ) :
    Option (TaskCostTable task) :=
  if hne : 0 < points.size then
    if huniq : CostPoint.uniqueDemandB points = true then
      if hbounds : CostPoint.demandBoundsB task points = true then
        if herr : (0 : ℚ) ≤ errorBound then
          if hclose : CostPoint.encodedCloseB points trueCost errorBound = true then
            some {
              points := points
              nonempty := hne
              uniqueDemand := (CostPoint.uniqueDemandB_iff points).mp huniq
              demandBounds := (CostPoint.demandBoundsB_iff task points).mp hbounds
              trueCost := trueCost
              errorBound := errorBound
              error_nonneg := herr
              encodedClose := (CostPoint.encodedCloseB_iff points trueCost errorBound).mp hclose
            }
          else none
        else none
      else none
    else none
  else none

end CpsatScheduler
