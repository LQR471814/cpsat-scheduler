import CpsatScheduler.CpsatSolver.Expr

namespace CpsatSolver

inductive ConstraintEnforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))

structure Constraint where
  name : String
  expr : CpsatSolver.BoundedLinearExpr
  enforce : ConstraintEnforcement

end CpsatSolver

