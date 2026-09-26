import CpsatScheduler.CpsatSolver.WellFormed
import CpsatScheduler.CpsatSolver.EntityId

namespace CpsatSolver

/-- Collision-free Python identifier derived from an ID, never from a label. -/
def EntityId.toPythonName (id : EntityId) : Python.ValidName :=
  ⟨"e_" ++ toString id.val, EntityId.toPythonName_proof id.val⟩

def HasId.pythonName {α : Type} [HasId α] (x : α) : Python.ValidName :=
  EntityId.toPythonName (HasId.id x)

def BoolLit.toPythonExpr (b : BoolLit) : Python.Expr :=
  match b with
  | .var v => .id v.id.toPythonName
  | .neg v => .bitwiseNot (.id v.id.toPythonName)

def IntVar.toPythonExpr (var : IntVar) : Python.Expr :=
  .id var.id.toPythonName

def FixedSizeIntervalVar.toPythonExpr (var : FixedSizeIntervalVar) : Python.Expr :=
  .id var.id.toPythonName

def LinearExpr.toPythonExpr {bounds : Bounds} (expr : LinearExpr bounds) : Python.Expr :=
  match expr with
  | .fromVar value => value.toPythonExpr
  | .fromConst value => .lit (.int value.val)
  | .fromNeg a _ => .neg a.toPythonExpr
  | .fromMulConst a value _ =>
    .mul (.lit (.int value.val)) a.toPythonExpr
  | .fromAdd a b _ => .add a.toPythonExpr b.toPythonExpr
  | .fromSub a b _ => .sub a.toPythonExpr b.toPythonExpr

def BoundedLinearExpr.toPythonExpr (expr : BoundedLinearExpr) : Python.Expr :=
  let left := @LinearExpr.toPythonExpr expr.leftBounds expr.left
  let right := @LinearExpr.toPythonExpr expr.rightBounds expr.right
  match expr.rel with
    | .eq => .eq left right
    | .neq => .neq left right
    | .gt => .gt left right
    | .gte => .gte left right
    | .lt => .lt left right
    | .lte => .lte left right

def idsUnique {α : Type} [HasId α] (arr : Array α) : Prop :=
  ∀ a b : Fin arr.size, a ≠ b → HasId.id arr[a] ≠ HasId.id arr[b]

end CpsatSolver
