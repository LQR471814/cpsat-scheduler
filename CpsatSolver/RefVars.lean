import CpsatSolver.Defs

namespace CpsatSolver

class RefVars (α : Type) where
  ints : α → Finset IntVar
  bools : α → Finset BoolVar
  fixedSizeIntervals : α → Finset FixedSizeIntervalVar

def LinearExpr.Raw.instRefVarsInts : LinearExpr.Raw → Finset IntVar
  | .fromVar v => { v }
  | .fromConst _ => {}
  | .fromNeg a' => instRefVarsInts a'
  | .fromMulConst a' _ => instRefVarsInts a'
  | .fromAdd a b => instRefVarsInts a ∪ instRefVarsInts b
  | .fromSub a b => instRefVarsInts a ∪ instRefVarsInts b

instance : RefVars LinearExpr where
  ints a := a.raw.instRefVarsInts
  bools _ := {}
  fixedSizeIntervals _ := {}

instance : RefVars BoundedLinearExpr where
  ints a := (RefVars.ints a.left) ∪ (RefVars.ints a.right)
  bools a := (RefVars.bools a.left) ∪ (RefVars.bools a.right)
  fixedSizeIntervals a := (RefVars.fixedSizeIntervals a.left) ∪ (RefVars.fixedSizeIntervals a.right)

instance : RefVars Constraint.CumulativeItem where
  ints a := RefVars.ints a.demand
  bools _ := {}
  fixedSizeIntervals a := {a.interval}

instance : RefVars BoolLit where
  ints _ := {}
  bools a := match a with
    | .var v => {v}
    | .neg v => {v}
  fixedSizeIntervals _ := {}

def Constraint.Variant.instRefVarsInts : Constraint.Variant → Finset IntVar
  | .bounded_linear expr => RefVars.ints expr
  | .max_equality target exprs _ =>
    (RefVars.ints target) ∪ (exprs.foldl
      (fun acc x => acc ∪ RefVars.ints x)
      {})
  | .div_eq target numerator _ _ =>
    (RefVars.ints target) ∪ (RefVars.ints numerator)
  | .allowed_assignments vars _ _ _ => vars.toList.toFinset
  | .cumulative items capacity =>
    RefVars.ints capacity ∪ (items.foldl
      (fun acc x => acc ∪ RefVars.ints x)
      {})
  | .bool_and _ _ => {}
  | .bool_or _ _ => {}
  | .implication _ _ => { }

def Constraint.Variant.instRefVarsBools : Constraint.Variant → Finset BoolVar
  | .bounded_linear expr => RefVars.bools expr
  | .max_equality target exprs _ =>
    (RefVars.bools target) ∪ (exprs.foldl
      (fun acc x => acc ∪ RefVars.bools x)
      {})
  | .div_eq target numerator _ _ =>
    (RefVars.bools target) ∪ (RefVars.bools numerator)
  | .allowed_assignments _ _ _ _ => {}
  | .cumulative items capacity =>
    RefVars.bools capacity ∪ (items.foldl
      (fun acc x => acc ∪ RefVars.bools x)
      {})
  | .bool_and terms _ => (terms.foldl
    (fun acc x => acc ∪ RefVars.bools x)
    {})
  | .bool_or terms _ => (terms.foldl
    (fun acc x => acc ∪ RefVars.bools x)
    {})
  | .implication src dst =>
    RefVars.bools src ∪ RefVars.bools dst

def Constraint.Variant.instRefVarsFixedSizeIntervals :
    Constraint.Variant → Finset FixedSizeIntervalVar
  | .bounded_linear expr => RefVars.fixedSizeIntervals expr
  | .max_equality target exprs _ =>
    (RefVars.fixedSizeIntervals target) ∪ (exprs.foldl
      (fun acc x => acc ∪ RefVars.fixedSizeIntervals x)
      {})
  | .div_eq target numerator _ _ =>
    (RefVars.fixedSizeIntervals target) ∪ (RefVars.fixedSizeIntervals numerator)
  | .allowed_assignments _ _ _ _ => {}
  | .cumulative items capacity =>
    RefVars.fixedSizeIntervals capacity ∪ (items.foldl
      (fun acc x => acc ∪ RefVars.fixedSizeIntervals x)
      {})
  | .bool_and terms _ => (terms.foldl
    (fun acc x => acc ∪ RefVars.fixedSizeIntervals x)
    {})
  | .bool_or terms _ => (terms.foldl
    (fun acc x => acc ∪ RefVars.fixedSizeIntervals x)
    {})
  | .implication src dst =>
    RefVars.fixedSizeIntervals src ∪ RefVars.fixedSizeIntervals dst

instance : RefVars Constraint where
  ints a := a.variant.instRefVarsInts
  bools a := a.variant.instRefVarsBools
  fixedSizeIntervals a := a.variant.instRefVarsFixedSizeIntervals

instance : RefVars Objective where
  ints a := match a with
    | .none => {}
    | .minimize expr => RefVars.ints expr
    | .maximize expr => RefVars.ints expr
  bools a := match a with
    | .none => {}
    | .minimize expr => RefVars.bools expr
    | .maximize expr => RefVars.bools expr
  fixedSizeIntervals a := match a with
    | .none => {}
    | .minimize expr => RefVars.fixedSizeIntervals expr
    | .maximize expr => RefVars.fixedSizeIntervals expr

end CpsatSolver
