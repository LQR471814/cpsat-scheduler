import CpsatSolver.LinearExpr

namespace CpsatScheduler

def Constraint.bucketContainedIn
    (child parent : CpsatSolver.IntVar) (ratio : CpsatSolver.Int64)
    (mul₁ :
      CpsatSolver.Int64.Nonoverflow
        (parent.domainHull.mulLower (CpsatSolver.Interval.ofValue ratio)) ∧
      CpsatSolver.Int64.Nonoverflow
        (parent.domainHull.mulUpper (CpsatSolver.Interval.ofValue ratio)))
    (add₁ :
      CpsatSolver.Int64.Nonoverflow ((parent.domainHull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((parent.domainHull.right : ℤ) + 1))
    (mul₂ :
      CpsatSolver.Int64.Nonoverflow
        (((parent.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1))
            add₁).mulLower (CpsatSolver.Interval.ofValue ratio))) ∧
      CpsatSolver.Int64.Nonoverflow
        (((parent.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1))
            add₁).mulUpper (CpsatSolver.Interval.ofValue ratio))))
    (addChild :
      CpsatSolver.Int64.Nonoverflow ((child.domainHull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((child.domainHull.right : ℤ) + 1)) :
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
      leftInterval := child.domainHull
      rightInterval := parent.domainHull.mul (CpsatSolver.Interval.ofValue ratio) mul₁
      left := childE
      right := parentScaled
    },
    snd := {
      rel := .lte
      leftInterval := child.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1))
        addChild
      rightInterval :=
        (parent.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁).mul
          (CpsatSolver.Interval.ofValue ratio) mul₂
      left := childPlus
      right := parentPlusScaled
    }
  }

end CpsatScheduler
