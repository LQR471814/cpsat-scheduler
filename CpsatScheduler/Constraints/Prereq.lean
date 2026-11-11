import CpsatSolver.LinearExpr

namespace CpsatScheduler.Constraints

open CpsatSolver

def prerequisite (succ pred : IntVar)
    (nonoverflow :
      Int64.Nonoverflow ((pred.domainHull.left : ℤ) + 1) ∧
      Int64.Nonoverflow ((pred.domainHull.right : ℤ) + 1)) :
    BoundedLinearExpr :=
  let succE := LinearExpr.var succ
  let predE := LinearExpr.var pred
  let one : LinearExpr :=
    LinearExpr.const (Int64.of 1)
  let predEnd := LinearExpr.add predE one nonoverflow
  {
    rel := .gte
    leftInterval := succE.interval
    rightInterval := predEnd.interval
    left := succE
    right := predEnd
  }

end CpsatScheduler.Constraints

