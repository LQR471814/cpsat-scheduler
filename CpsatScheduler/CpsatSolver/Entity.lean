import CpsatScheduler.CpsatSolver.Defs

namespace CpsatSolver

abbrev EntityID := ℕ

def BoolLit.varId : BoolLit → EntityID
  | .var v => v.id
  | .neg v => v.id

def LinearExpr.intVars {bounds : Interval} : LinearExpr bounds → Array IntVar
  | .fromVar value => #[value]
  | .fromConst _ => #[]
  | .fromNeg a _ => a.intVars
  | .fromMulConst a _ _ => a.intVars
  | .fromAdd a b _ => a.intVars ++ b.intVars
  | .fromSub a b _ => a.intVars ++ b.intVars

def BoundedLinearExpr.intVars (v : BoundedLinearExpr) : Array IntVar :=
  v.left.intVars ++ v.right.intVars

def LinearExpr.WithInterval.intVars (e : LinearExpr.WithInterval) : Array IntVar :=
  e.snd.intVars

def FixedSizeIntervalVar.intVars (v : FixedSizeIntervalVar) : Array IntVar :=
  v.start.intVars

def Constraint.Variant.fixedSizeIntervalVars :
    Constraint.Variant → Array FixedSizeIntervalVar
  | .cumulative items _ => items.map (fun i => i.interval)
  | _ => #[]

def Constraint.fixedSizeIntervalVars (c : Constraint) :
    Array FixedSizeIntervalVar :=
  c.variant.fixedSizeIntervalVars

def Constraint.Variant.intVars : Constraint.Variant → Array IntVar
  | .bounded_linear expr => expr.intVars
  | .max_equality target exprs _ =>
    exprs.foldl (fun acc e => acc ++ e.intVars) target.intVars
  | .div_eq target numerator _ _ =>
    target.intVars ++ numerator.intVars
  | allowed_assignments vars _ _ _ => vars.toArray
  | .cumulative items capacity =>
    items.foldl (fun acc it =>
      acc ++ it.interval.intVars ++ it.demand.intVars) capacity.intVars
  | .bool_and _ _ => #[]
  | .bool_or _ _ => #[]
  | .implication _ _ => #[]

def Constraint.intVars (v : Constraint) : Array IntVar :=
  v.variant.intVars

def Constraint.Variant.boolVars : Constraint.Variant → Array BoolVar
  | .bool_and terms _ => terms.map BoolLit.varId |>.map (fun id => { id := id })
  | .bool_or terms _ => terms.map BoolLit.varId |>.map (fun id => { id := id })
  | .implication src dst =>
    #[{ id := src.varId }, { id := dst.varId }]
  | _ => #[]

def Constraint.Enforcement.boolVars : Constraint.Enforcement → Array BoolVar
  | .always => #[]
  | .onlyWhenAll literals =>
    (literals.map (fun l => { id := l.varId })).toArray

def Constraint.boolVars (v : Constraint) : Array BoolVar :=
  v.variant.boolVars ++ v.enforcement.boolVars

def Objective.intVars : Objective → Array IntVar
  | .none => #[]
  | .minimize e => e.intVars
  | .maximize e => e.intVars


class Entity (α : Type) where
  id : α → EntityID

instance : Entity BoolVar where
  id v := v.id

instance : Entity IntVar where
  id v := v.id

instance : Entity FixedSizeIntervalVar where
  id v := v.id

instance : Entity Constraint where
  id c := c.id

instance : Entity (UnitAwareIntVar U) where
  id v := v.intVar.id


class RefVars (α : Type) where
  intVars : α → Array IntVar
  boolVars : α → Array BoolVar
  fixedSizeIntervalVar : α → Array FixedSizeIntervalVar

instance : RefVars (LinearExpr β) where
  intVars expr := expr.intVars
  boolVars _ := #[]
  fixedSizeIntervalVar _ := #[]

instance : RefVars Constraint where
  intVars c := c.intVars
  boolVars c := c.boolVars
  fixedSizeIntervalVar c := c.fixedSizeIntervalVars

instance : RefVars Objective where
  intVars obj := obj.intVars
  boolVars _ := #[]
  fixedSizeIntervalVar _ := #[]

end CpsatSolver
