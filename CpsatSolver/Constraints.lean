import CpsatSolver.LinearExpr

namespace CpsatSolver.Constraint

structure Division where
  quotient : IntVar
  constraint : Constraint

def divPosConst {N : Interval}
  (quotientID constraintID : EntityID)
  (numerator : LinearExpr N) (denominator : Int64)
  (hdiv : (0 : ℤ) < denominator)
  (enforcement : Enforcement) (label : Option String := none) :
    Division :=
  let resultDomain := NonemptyDomain.interval
    (N.divPosConst denominator hdiv)
  let quotVar : IntVar := {
    id := quotientID
    domain := resultDomain
    label := label
  }
  let quotVarExpr : LinearExpr (Interval.divPosConst N (↑denominator) hdiv) :=
    by
      have quot_div_eq := NonemptyDomain.hull_interval_eq
        resultDomain rfl
      rw [quot_div_eq.symm]
      exact LinearExpr.var quotVar
  let constraint : Constraint :=
    let Q := N.divPosConst denominator hdiv
    {
      id := constraintID
      label := label
      enforcement := enforcement
      variant := .div_eq
        ⟨Q, quotVarExpr⟩
        ⟨N, numerator⟩
        denominator
        hdiv
    }
  ⟨quotVar, constraint⟩

end CpsatSolver.Constraint

