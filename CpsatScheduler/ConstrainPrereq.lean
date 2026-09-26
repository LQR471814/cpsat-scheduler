import CpsatScheduler.CpsatSolver.LinearExpr

namespace CpsatScheduler

/-- Successor start after predecessor bucket end, already in a common unit. -/
def Constraint.prerequisite (succ pred : CpsatSolver.IntVar)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((pred.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((pred.domain.hull.right : ℤ) + 1)) :
    CpsatSolver.BoundedLinearExpr :=
  let succE := CpsatSolver.LinearExpr.var succ
  let predE := CpsatSolver.LinearExpr.var pred
  let one : CpsatSolver.LinearExpr _ :=
    CpsatSolver.LinearExpr.const (CpsatSolver.Int64.of 1)
  let predEnd := CpsatSolver.LinearExpr.add predE one nonoverflow
  {
    rel := .gte
    leftBounds := succ.domain.hull
    rightBounds := pred.domain.hull.add
      (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) nonoverflow
    left := succE
    right := predEnd
  }

end CpsatScheduler

