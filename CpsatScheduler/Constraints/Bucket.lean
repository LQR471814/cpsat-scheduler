import CpsatSolver.LinearExpr

namespace CpsatScheduler.Constraints

open CpsatSolver

def bucketContainedIn
    (child parent : IntVar) (ratio : CpsatSolver.Int64)
    (mul₁ : LinearExpr.Nonoverflow.Mul parent.domainHull ratio)
    (add₁ : LinearExpr.Nonoverflow.Add parent.domainHull
      (Interval.ofValue (CpsatSolver.Int64.of 1)))
    (mul₂ :
      LinearExpr.Nonoverflow.Mul
        (parent.domainHull.add
          (Interval.ofValue (CpsatSolver.Int64.of 1)) add₁) ratio)
    (addChild :
      LinearExpr.Nonoverflow.Add child.domainHull
        (Interval.ofValue (CpsatSolver.Int64.of 1))) :
    BoundedLinearExpr × BoundedLinearExpr :=
  let childE := LinearExpr.var child
  let parentE := LinearExpr.var parent
  let one : LinearExpr := LinearExpr.const (CpsatSolver.Int64.of 1)
  let lower := LinearExpr.mul parentE ratio mul₁
  let childPlusOne := LinearExpr.add childE one addChild
  let upper := LinearExpr.mul (LinearExpr.add parentE one add₁) ratio mul₂
  {
    fst := {
      rel := .gte
      leftInterval := childE.interval
      rightInterval := lower.interval
      left := childE
      right := lower
    },
    snd := {
      rel := .lte
      leftInterval := childPlusOne.interval
      rightInterval := upper.interval
      left := childPlusOne
      right := upper
    }
  }

end CpsatScheduler.Constraints
