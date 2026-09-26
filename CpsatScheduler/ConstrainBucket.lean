import CpsatScheduler.CpsatSolver.LinearExpr

namespace CpsatScheduler

def Constraint.bucketContainedIn
    (child parent : CpsatSolver.IntVar) (ratio : CpsatSolver.Int64)
    (mul₁ :
      CpsatSolver.Int64.Nonoverflow
        (parent.domain.hull.mulLower (CpsatSolver.Interval.ofValue ratio)) ∧
      CpsatSolver.Int64.Nonoverflow
        (parent.domain.hull.mulUpper (CpsatSolver.Interval.ofValue ratio)))
    (add₁ :
      CpsatSolver.Int64.Nonoverflow ((parent.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((parent.domain.hull.right : ℤ) + 1))
    (mul₂ :
      CpsatSolver.Int64.Nonoverflow
        (((parent.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1))
            add₁).mulLower (CpsatSolver.Interval.ofValue ratio))) ∧
      CpsatSolver.Int64.Nonoverflow
        (((parent.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1))
            add₁).mulUpper (CpsatSolver.Interval.ofValue ratio))))
    (addChild :
      CpsatSolver.Int64.Nonoverflow ((child.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((child.domain.hull.right : ℤ) + 1)) :
    CpsatSolver.BoundedLinearExpr × CpsatSolver.BoundedLinearExpr :=
  let childE := CpsatSolver.LinearExpr.var child
  let parentE := CpsatSolver.LinearExpr.var parent
  let parentScaled := CpsatSolver.LinearExpr.mul parentE ratio mul₁
  let one : CpsatSolver.LinearExpr _ :=
    CpsatSolver.LinearExpr.const (CpsatSolver.Int64.of 1)
  let parentPlus := CpsatSolver.LinearExpr.add parentE one add₁
  let parentPlusScaled := CpsatSolver.LinearExpr.mul parentPlus ratio mul₂
  let childPlus := CpsatSolver.LinearExpr.add childE one addChild
  {
    fst := {
      rel := .gte
      leftBounds := child.domain.hull
      rightBounds := parent.domain.hull.mul (CpsatSolver.Interval.ofValue ratio) mul₁
      left := childE
      right := parentScaled
    },
    snd := {
      rel := .lte
      leftBounds := child.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1))
        addChild
      rightBounds :=
        (parent.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁).mul
          (CpsatSolver.Interval.ofValue ratio) mul₂
      left := childPlus
      right := parentPlusScaled
    }
  }

end CpsatScheduler
