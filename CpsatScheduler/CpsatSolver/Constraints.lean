import CpsatScheduler.CpsatSolver.LinearExpr

namespace CpsatSolver.Constraint

def truncDivEq {nb : Bounds}
    (constraintID : EntityID)
    (numerator : LinearExpr nb)
    (divisor : Int64)
    (hdiv : (0 : ℤ) < divisor) :=
  let nt := nb.divPosConst divisor hdiv
  let curried
    (target : LinearExpr nt)
    (label : Option String := none)
    (enforcement : Constraint.Enforcement) :
      Constraint :=
    {
      id := constraintID
      label := label
      enforcement := enforcement
      variant := .div_eq ⟨nt, target⟩ ⟨nb, numerator⟩ divisor hdiv
    }
  curried

structure TruncCoarsen where
  quotient : IntVar
  constraint : Constraint

def truncCoarsen {nb : Bounds} (quotVarID constraintID : EntityID)
    (numerator : LinearExpr nb) (divisor : Int64) (hdiv : (0 : ℤ) < divisor)
    (enforcement : Enforcement)
    (label : Option String := none) : TruncCoarsen :=
  let quotDomain := NonemptyDomain.interval
    (nb.divPosConst divisor hdiv)
  let quotVar : IntVar := {
    id := quotVarID
    domain := quotDomain
    label := label
  }
  let divTarget : LinearExpr (Interval.divPosConst nb (↑divisor) hdiv) :=
    let quotVarExpr := LinearExpr.var quotVar
    by
      have quot_div_eq := NonemptyDomain.hull_interval_eq
        quotDomain rfl
      rw [quot_div_eq.symm]
      exact quotVarExpr
  let cnstr : Constraint :=
    .truncDivEq constraintID
      numerator divisor hdiv divTarget
      enforcement
  ⟨quotVar, cnstr⟩

end CpsatSolver.Constraint

