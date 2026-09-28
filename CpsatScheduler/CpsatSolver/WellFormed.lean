import CpsatScheduler.CpsatSolver.Defs

namespace CpsatSolver

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
  | .max_equality target exprs _ =>
    exprs.foldl (fun acc e => acc ++ e.intVars) target.intVars
  | .div_eq target numerator _ _ =>
    target.intVars ++ numerator.intVars
  | allowed_assignments vars _ _ _ => vars.toList
  | .cumulative items capacity =>
    items.foldl (fun acc it =>
      acc ++ it.interval.intVars ++ it.demand.intVars) capacity.intVars
  | .bool_and _ _ => []
  | .bool_or _ _ => []
  | .implication _ _ => []

def Constraint.intVars (value : Constraint) : List IntVar :=
  value.variant.intVars

def Constraint.Variant.boolVars : Constraint.Variant → List BoolVar
  | .bool_and terms _ => terms.toList.map BoolLit.varId |>.map (fun id => { id := id })
  | .bool_or terms _ => terms.toList.map BoolLit.varId |>.map (fun id => { id := id })
  | .implication src dst =>
    [{ id := src.varId }, { id := dst.varId }]
  | _ => []

def Constraint.Enforcement.boolVars : Constraint.Enforcement → List BoolVar
  | .always => []
  | .onlyWhenAll literals =>
    literals.toList.map (fun l => { id := l.varId })

def Objective.intVars : Objective → List IntVar
  | .none => []
  | .minimize e => e.intVars
  | .maximize e => e.intVars

end CpsatSolver
