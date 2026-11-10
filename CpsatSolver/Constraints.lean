import CpsatSolver.LinearExpr

namespace CpsatSolver.Constraint

/-- A division constraint together with the freshly-introduced quotient
    variable it constrains. -/
structure Division where
  quotient : IntVar
  constraint : Constraint

/-- `numerator / denominator = quotient`, with `denominator` a positive
    constant. The quotient variable's domain is the elementwise division of
    the numerator's bounding interval, so it is tight by construction.

    Identity is structural: the quotient variable is determined entirely by
    its domain (and optional label), so two `divPosConst` calls with identical
    inputs produce the same variable. -/
def divPosConst
  (numerator : LinearExpr) (denominator : Int64)
  (hdiv : (0 : ℤ) < denominator)
  (enforcement : Constraint.Enforcement) (label : Option String := none) :
    Division :=
  let resultDomain := NonemptyDomain.interval
    (numerator.interval.divPosConst denominator hdiv)
  let quotVar : IntVar := {
    domain := resultDomain
    label := label
  }
  let constraint : Constraint := {
    label := label
    enforcement := enforcement
    variant := .div_eq
      (LinearExpr.var quotVar)
      numerator
      denominator
      hdiv
  }
  ⟨quotVar, constraint⟩

end CpsatSolver.Constraint
