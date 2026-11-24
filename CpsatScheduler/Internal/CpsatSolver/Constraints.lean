module

public import CpsatScheduler.Internal.CpsatSolver.LinearExpr

public section

namespace CpsatSolver.Constraint

structure Division where
  quotient : IntVar
  constraint : Constraint

def divPosConst (numerator : LinearExpr) (denominator : Int64)
  (hdiv : (0 : ℤ) < denominator) (enforcement : Enforcement)
  (label : Option String := none) :
    Division :=
  let N := numerator.interval
  let resultDomain := NonemptyDomain.interval
    (N.divPosConst denominator hdiv)
  let quotVar : IntVar := {
    domain := resultDomain
    label := label
  }
  let quotVarExpr : LinearExpr := {
    raw :=
    interval := Interval.divPosConst N denominator hdiv
    proof :=
      by
        have quot_div_eq := NonemptyDomain.hull_interval_eq
          resultDomain rfl
        rw [quot_div_eq.symm]
        exact LinearExpr.var quotVar
  }
  let constraint : Constraint :=
    let Q := N.divPosConst denominator hdiv
    {
      label := label
      enforcement := enforcement
      variant := .div_eq
        quotVarExpr numerator denominator hdiv
    }
  ⟨quotVar, constraint⟩

end CpsatSolver.Constraint

