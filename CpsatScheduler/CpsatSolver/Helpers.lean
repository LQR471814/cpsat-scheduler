import CpsatScheduler.CpsatSolver.Defs

namespace CpsatSolver

def BoolLit.toPythonExpr (b : BoolLit) : Python.Expr :=
  match b with
  | .var v => Python.Expr.id v.id.toPythonName
  | .neg v => Python.Expr.bitwiseNot (Python.Expr.id v.id.toPythonName)

def IntVar.toPythonExpr (var : IntVar) : Python.Expr :=
  Python.Expr.id var.id.toPythonName

def FixedSizeIntervalVar.toPythonExpr (var : FixedSizeIntervalVar) : Python.Expr :=
  Python.Expr.id var.id.toPythonName

def LinearExpr.toPythonExpr {bounds : Bounds} (expr : LinearExpr bounds) : Python.Expr :=
  match expr with
  | .fromVar value => value.toPythonExpr
  | .fromConst value => Python.Expr.lit (Python.Literal.int value.val)
  | .fromNeg a _ => Python.Expr.neg a.toPythonExpr
  | .fromMulConst a value _ =>
    Python.Expr.mul (Python.Expr.lit (Python.Literal.int value.val)) a.toPythonExpr
  | .fromAdd a b _ => Python.Expr.add a.toPythonExpr b.toPythonExpr
  | .fromSub a b _ => Python.Expr.sub a.toPythonExpr b.toPythonExpr

def LinearExpr.var (value : IntVar) : LinearExpr value.domain.hull := .fromVar value

def LinearExpr.const (value : Int64) : LinearExpr (Interval.fromValue value) :=
  .fromConst value

def LinearExpr.neg {bounds : Bounds} (a : LinearExpr bounds)
    (nonoverflow : Int64.Nonoverflow (-bounds.right : ℤ) ∧
      Int64.Nonoverflow (-bounds.left : ℤ)) :
    LinearExpr (bounds.neg nonoverflow) :=
  .fromNeg a nonoverflow

def LinearExpr.mul {bounds : Bounds} (a : LinearExpr bounds) (value : Int64)
    (nonoverflow :
      Int64.Nonoverflow (bounds.mulLower (Interval.fromValue value)) ∧
      Int64.Nonoverflow (bounds.mulUpper (Interval.fromValue value))) :
    LinearExpr (bounds.mul (Interval.fromValue value) nonoverflow) :=
  .fromMulConst a value nonoverflow

def LinearExpr.add {leftBounds rightBounds : Bounds}
    (left : LinearExpr leftBounds) (right : LinearExpr rightBounds)
    (nonoverflow :
      Int64.Nonoverflow ((leftBounds.left : ℤ) + rightBounds.left) ∧
      Int64.Nonoverflow ((leftBounds.right : ℤ) + rightBounds.right)) :
    LinearExpr (leftBounds.add rightBounds nonoverflow) :=
  .fromAdd left right nonoverflow

def LinearExpr.sub {leftBounds rightBounds : Bounds}
    (left : LinearExpr leftBounds) (right : LinearExpr rightBounds)
    (nonoverflow :
      Int64.Nonoverflow ((leftBounds.left : ℤ) - rightBounds.right) ∧
      Int64.Nonoverflow ((leftBounds.right : ℤ) - rightBounds.left)) :
    LinearExpr (leftBounds.sub rightBounds nonoverflow) :=
  .fromSub left right nonoverflow

def BoundedLinearExpr.toPythonExpr (expr : BoundedLinearExpr) : Python.Expr :=
  let left := @LinearExpr.toPythonExpr expr.leftBounds expr.left
  let right := @LinearExpr.toPythonExpr expr.rightBounds expr.right
  match expr.rel with
    | .eq => Python.Expr.eq left right
    | .neq => Python.Expr.neq left right
    | .gt => Python.Expr.gt left right
    | .gte => Python.Expr.gte left right
    | .lt => Python.Expr.lt left right
    | .lte => Python.Expr.lte left right

def idsUnique {α : Type} [HasId α] (arr : Array α) : Prop :=
  ∀ a b : Fin arr.size, a ≠ b → HasId.id arr[a] ≠ HasId.id arr[b]

end CpsatSolver
