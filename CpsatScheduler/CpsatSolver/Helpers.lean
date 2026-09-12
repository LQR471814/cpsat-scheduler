import CpsatScheduler.CpsatSolver.Defs

namespace CpsatSolver

def BoolLit.toPythonExpr (b : BoolLit) : Python.Expr :=
  match b with
  | .var v => Python.Expr.id v.name
  | .neg v => Python.Expr.bitwiseNot (Python.Expr.id v.name)

def IntVar.toPythonExpr (var : IntVar) : Python.Expr := Python.Expr.id var.name

def FixedSizeIntervalVar.toPythonExpr (var : FixedSizeIntervalVar) : Python.Expr :=
  Python.Expr.id var.name

def LinearExpr.toPythonExpr {domain : Interval} (expr : LinearExpr domain) : Python.Expr :=
  match expr with
  | .fromVar value => value.toPythonExpr
  | .fromConst value => Python.Expr.lit (Python.Literal.int value.val)
  | .fromNeg a _ _ _ => Python.Expr.neg a.toPythonExpr
  | .fromAdd a b _ _ _ => Python.Expr.add a.toPythonExpr b.toPythonExpr
  | .fromMul a b _ _ _ => Python.Expr.mul a.toPythonExpr b.toPythonExpr
  | .fromSub a b _ _ _ => Python.Expr.sub a.toPythonExpr b.toPythonExpr

def LinearExpr.var (value : IntVar) : LinearExpr value.domain := .fromVar value

def LinearExpr.const (value : Int64) : LinearExpr (Interval.fromValue value) := .fromConst value

def LinearExpr.neg {domain : Interval}
    (a : LinearExpr domain) (result : Interval)
    (nonoverflow : Int64.Nonoverflow (-domain.right : ℤ) ∧
      Int64.Nonoverflow (-domain.left : ℤ))
    (result_eq : domain.neg nonoverflow = result) : LinearExpr result :=
  .fromNeg a result nonoverflow result_eq

def LinearExpr.add {leftDomain rightDomain : Interval}
    (left : LinearExpr leftDomain) (right : LinearExpr rightDomain)
    (result : Interval)
    (nonoverflow : Int64.Nonoverflow ((leftDomain.left : ℤ) + rightDomain.left) ∧
      Int64.Nonoverflow ((leftDomain.right : ℤ) + rightDomain.right))
    (result_eq : leftDomain.add rightDomain nonoverflow = result) : LinearExpr result :=
  .fromAdd left right result nonoverflow result_eq

def LinearExpr.sub {leftDomain rightDomain : Interval}
    (left : LinearExpr leftDomain) (right : LinearExpr rightDomain)
    (result : Interval)
    (nonoverflow : Int64.Nonoverflow (min (min ((leftDomain.left : ℤ) * rightDomain.left)
        ((leftDomain.left : ℤ) * rightDomain.right))
        (min ((leftDomain.right : ℤ) * rightDomain.left)
          ((leftDomain.right : ℤ) * rightDomain.right))) ∧
      Int64.Nonoverflow (max (max ((leftDomain.left : ℤ) * rightDomain.left)
        ((leftDomain.left : ℤ) * rightDomain.right))
        (max ((leftDomain.right : ℤ) * rightDomain.left)
          ((leftDomain.right : ℤ) * rightDomain.right))))
    (result_eq : leftDomain.mul rightDomain nonoverflow = result) : LinearExpr result :=
  .fromSub left right result nonoverflow result_eq

def LinearExpr.mul {leftDomain rightDomain : Interval}
    (left : LinearExpr leftDomain) (right : LinearExpr rightDomain)
    (result : Interval)
    (nonoverflow : Int64.Nonoverflow ((leftDomain.left : ℤ) - rightDomain.right) ∧
      Int64.Nonoverflow ((leftDomain.right : ℤ) - rightDomain.left))
    (result_eq : leftDomain.sub rightDomain nonoverflow = result) : LinearExpr result :=
  .fromMul left right result nonoverflow result_eq

def BoundedLinearExpr.toPythonExpr (expr : BoundedLinearExpr) : Python.Expr :=
  let left := @LinearExpr.toPythonExpr expr.leftDomain expr.left
  let right := @LinearExpr.toPythonExpr expr.rightDomain expr.right
  match expr.rel with
    | .eq => Python.Expr.eq left right
    | .neq => Python.Expr.neq left right
    | .gt => Python.Expr.gt left right
    | .gte => Python.Expr.gte left right
    | .lt => Python.Expr.lt left right
    | .lte => Python.Expr.lte left right

abbrev Var.uniqueNames {α : Type} [Var α] (arr : Array α) :=
  ∀ a b : Fin arr.size, a ≠ b → (Var.name (arr[a])) ≠ (Var.name (arr[b]))

end CpsatSolver
