import CpsatSolver.LinearExpr

namespace CpsatScheduler.Constraints

open CpsatSolver

def bucketContainedIn
    (child parent : IntVar) (ratio : CpsatSolver.Int64)
    (mul₁ : Interval.Nonoverflow.MulConst parent.domainHull ratio)
    (add₁ : Interval.Nonoverflow.Add parent.domainHull
      (Interval.ofValue (CpsatSolver.Int64.of 1)))
    (mul₂ :
      Interval.Nonoverflow.MulConst
        (parent.domainHull.add
          (Interval.ofValue (CpsatSolver.Int64.of 1)) add₁) ratio)
    (addChild :
      Interval.Nonoverflow.Add child.domainHull
        (Interval.ofValue (CpsatSolver.Int64.of 1))) :
    BoundedLinearExpr × BoundedLinearExpr :=
  let childE := LinearExpr.var child
  let parentE := LinearExpr.var parent
  let one : LinearExpr _ := LinearExpr.const (CpsatSolver.Int64.of 1)
  {
    fst := {
      rel := .gte
      leftInterval := _
      rightInterval := _
      left := childE
      right := LinearExpr.mul parentE ratio mul₁
    },
    snd := {
      rel := .lte
      leftInterval := _
      rightInterval := _
      left := LinearExpr.add childE one addChild
      right := LinearExpr.mul (LinearExpr.add parentE one add₁) ratio mul₂
    }
  }

end CpsatScheduler.Constraints
