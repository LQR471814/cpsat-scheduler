import CpsatScheduler.CpsatSolver.Defs

namespace CpsatSolver

/-- Cheap necessary condition on closed bounds (interval overlap), used only
for unconditional constraints. Does not enumerate interior points. -/
def BoundedLinearExpr.NoContradict (expr : BoundedLinearExpr) : Prop :=
  match expr.rel with
  | .eq =>
    (max (expr.leftBounds.left : ℤ) expr.rightBounds.left) ≤
      min (expr.leftBounds.right : ℤ) expr.rightBounds.right
  | .neq =>
    ¬ ((expr.leftBounds.left : ℤ) = expr.leftBounds.right ∧
      (expr.rightBounds.left : ℤ) = expr.rightBounds.right ∧
      (expr.leftBounds.left : ℤ) = expr.rightBounds.left)
  | .gt => (expr.leftBounds.right : ℤ) > expr.rightBounds.left
  | .gte => (expr.leftBounds.right : ℤ) ≥ expr.rightBounds.left
  | .lt => (expr.leftBounds.left : ℤ) < expr.rightBounds.right
  | .lte => (expr.leftBounds.left : ℤ) ≤ expr.rightBounds.right

class HasId (α : Type) where
  id : α → EntityId

def BoolLit.varId : BoolLit → EntityId
  | .var v => v.id
  | .neg v => v.id

instance : HasId BoolVar where
  id v := v.id

instance : HasId IntVar where
  id v := v.id

instance : HasId FixedSizeIntervalVar where
  id v := v.id

instance : HasId Constraint where
  id c := c.id

def LinearExpr.intVars {bounds : Bounds} : LinearExpr bounds → List IntVar
  | .fromVar value => [value]
  | .fromConst _ => []
  | .fromNeg a _ => a.intVars
  | .fromMulConst a _ _ => a.intVars
  | .fromAdd a b _ => a.intVars ++ b.intVars
  | .fromSub a b _ => a.intVars ++ b.intVars

def BoundedLinearExpr.intVars (value : BoundedLinearExpr) : List IntVar :=
  value.left.intVars ++ value.right.intVars

def LinearExpr.WithBounds.intVars (e : LinearExpr.WithBounds) : List IntVar :=
  e.snd.intVars

def FixedSizeIntervalVar.intVars (value : FixedSizeIntervalVar) : List IntVar :=
  value.start.intVars

def Constraint.Variant.intVars : Constraint.Variant → List IntVar
  | .bounded_linear expr => expr.intVars
  | .max_equality target exprs =>
    exprs.foldl (fun acc e => acc ++ e.intVars) target.intVars
  | .div_eq target numerator _ _ =>
    target.intVars ++ numerator.intVars
  | allowed_assignments vars _ => vars.toList
  | .cumulative items capacity =>
    items.foldl (fun acc it =>
      acc ++ it.interval.intVars ++ it.demand.intVars) capacity.intVars
  | .bool_and _ => []
  | .bool_or _ => []
  | .implication _ _ => []

def Constraint.intVars (value : Constraint) : List IntVar :=
  value.variant.intVars

def Constraint.Variant.boolVars : Constraint.Variant → List BoolVar
  | .bool_and terms => terms.toList.map BoolLit.varId |>.map (fun id => { id := id })
  | .bool_or terms => terms.toList.map BoolLit.varId |>.map (fun id => { id := id })
  | .implication src dst =>
    [{ id := src.varId }, { id := dst.varId }]
  | _ => []

def Constraint.Enforcement.boolVars : Constraint.Enforcement → List BoolVar
  | .always => []
  | .onlyWhenAll literals =>
    literals.toList.map (fun l => { id := l.varId })

/-- Structural well-formedness of a constraint variant. -/
def Constraint.Variant.WellFormed : Constraint.Variant → Prop
  | .bounded_linear _ => True
  | .max_equality _ exprs => 0 < exprs.size
  | .div_eq _ _ _ _ => True
  | allowed_assignments vars rows =>
    0 < rows.size ∧
      ∀ row ∈ rows, ∀ i : Fin vars.size, (row[i].val : ℤ) ∈ vars[i].domain.domain
  | .cumulative _ _ => True
  | .bool_and terms => 0 < terms.size
  | .bool_or terms => 0 < terms.size
  | .implication _ _ => True

/-- Cheap necessary checks for unconditional constraints only. -/
def Constraint.PassesPresolveSanityChecks (c : Constraint) : Prop :=
  match c.enforcement with
  | .onlyWhenAll _ => True
  | .always =>
    match c.variant with
    | .bounded_linear expr => expr.NoContradict
    | .max_equality _ _ => True
    | .div_eq _ _ _ _ => True
    | .allowed_assignments _ rows => 0 < rows.size
    | .cumulative _ _ => True
    | .bool_and terms => 0 < terms.size
    | .bool_or terms => 0 < terms.size
    | .implication _ _ => True

def Objective.intVars : Objective → List IntVar
  | .none => []
  | .minimize e => e.intVars
  | .maximize e => e.intVars

instance (expr : BoundedLinearExpr) : Decidable expr.NoContradict := by
  unfold BoundedLinearExpr.NoContradict
  split <;> infer_instance

instance (v : Constraint.Variant) : Decidable v.WellFormed := by
  cases v <;> dsimp [Constraint.Variant.WellFormed] <;> infer_instance

instance (c : Constraint) : Decidable c.PassesPresolveSanityChecks := by
  unfold Constraint.PassesPresolveSanityChecks
  split <;> try infer_instance
  split <;> infer_instance

end CpsatSolver
