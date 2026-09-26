import CpsatScheduler.Defs

namespace CpsatScheduler

theorem CostTable.pointsNeNil {unit : UnitScale} (table : CostTable unit) :
    table.points.toList ≠ [] := by
  intro h
  have : table.points.size = 0 := by
    rw [← Array.length_toList, h, List.length_nil]
  exact (Nat.not_lt_of_ge (Nat.le_of_eq this)) table.nonempty

def CostTable.demandDomain {unit : UnitScale} (table : CostTable unit) :
    CpsatSolver.NonemptyDomain :=
  CpsatSolver.Domain.ofListNonempty
    (table.points.toList.map fun p => CpsatSolver.Interval.ofValue p.timeDemanded)
    (fun h => CostTable.pointsNeNil table (List.map_eq_nil_iff.mp h))

def CostTable.costDomain {unit : UnitScale} (table : CostTable unit) :
    CpsatSolver.NonemptyDomain :=
  CpsatSolver.Domain.ofListNonempty
    (table.points.toList.map fun p => CpsatSolver.Interval.ofValue p.encodedCost)
    (fun h => CostTable.pointsNeNil table (List.map_eq_nil_iff.mp h))

def CostTable.costHull {unit : UnitScale} (table : CostTable unit) :
    CpsatSolver.NonemptyDomain :=
  CpsatSolver.NonemptyDomain.interval table.costDomain.hull

def CostTable.allowedRows {unit : UnitScale} (table : CostTable unit) :
    Array (Vector CpsatSolver.Int64 2) :=
  table.points.map fun p => Vector.mk #[p.timeDemanded, p.encodedCost] rfl

private theorem all_decide_iff {α} (xs : Array α) (P : α → Prop) [DecidablePred P] :
    (xs.all fun x => decide (P x)) = true ↔ ∀ x ∈ xs, P x := by
  rw [Array.all_eq_true']
  exact ⟨fun h x hx => of_decide_eq_true (h x hx), fun h x hx => decide_eq_true (h x hx)⟩

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
    cases of_decide_eq_true (hi j (List.mem_finRange j)) with
    | inl heq => exact (hij heq).elim
    | inr hne => exact hne
  · intro h i _hi
    rw [List.all_eq_true]
    intro j _hj
    refine decide_eq_true ?_
    by_cases heq : i = j
    · exact Or.inl heq
    · exact Or.inr (h i j heq)

def CostPoint.demandBoundsB (unit : UnitScale) (points : Array CostPoint) : Bool :=
  points.all fun p =>
    decide ((0 : ℤ) ≤ p.timeDemanded.val ∧ p.timeDemanded.val ≤ unit.val)

theorem CostPoint.demandBoundsB_iff (unit : UnitScale) (points : Array CostPoint) :
    CostPoint.demandBoundsB unit points = true ↔
      ∀ p ∈ points, (0 : ℤ) ≤ p.timeDemanded.val ∧ p.timeDemanded.val ≤ unit.val :=
  all_decide_iff points _

def CostPoint.encodedCloseB (points : Array CostPoint)
    (trueCost : ℤ → ℚ) (errorBound : ℚ) : Bool :=
  points.all fun p =>
    decide (|trueCost p.timeDemanded.val - (p.encodedCost.val : ℚ)| ≤ errorBound)

theorem CostPoint.encodedCloseB_iff (points : Array CostPoint)
    (trueCost : ℤ → ℚ) (errorBound : ℚ) :
    CostPoint.encodedCloseB points trueCost errorBound = true ↔
      ∀ p ∈ points,
        |trueCost p.timeDemanded.val - (p.encodedCost.val : ℚ)| ≤ errorBound :=
  all_decide_iff points _

def CostTable.ofPoints? (unit : UnitScale)
    (points : Array CostPoint) (trueCost : ℤ → ℚ) (errorBound : ℚ) :
    Option (CostTable unit) :=
  if hne : 0 < points.size then
    if huniq : CostPoint.uniqueDemandB points = true then
      if hbounds : CostPoint.demandBoundsB unit points = true then
        if herr : (0 : ℚ) ≤ errorBound then
          if hclose : CostPoint.encodedCloseB points trueCost errorBound = true then
            some {
              points := points
              nonempty := hne
              uniqueDemand := (CostPoint.uniqueDemandB_iff points).mp huniq
              demandBounds := (CostPoint.demandBoundsB_iff unit points).mp hbounds
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
