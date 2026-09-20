import Mathlib.Data.Char
import CpsatScheduler.CpsatSolver.Python
import CpsatScheduler.CpsatSolver.Domain

namespace CpsatSolver

/-- Opaque solver entity identity, allocated from one global builder counter. -/
structure EntityId where
  val : Nat
deriving DecidableEq, Repr

instance : LT EntityId where
  lt a b := a.val < b.val

instance : DecidableLT EntityId :=
  fun a b => inferInstanceAs (Decidable (a.val < b.val))

private theorem char_ge_zero_or_le_nine (c : Char) : '0' ≤ c ∨ c ≤ '9' := by
  by_cases h : '0' ≤ c
  · exact Or.inl h
  · exact Or.inr (le_of_lt (lt_of_lt_of_le (lt_of_not_ge h) (by decide)))

theorem EntityId.validIdent_e_suffix (s : String) :
    Python.ValidIdent ("e_" ++ s) := by
  intro i
  exact Or.inr (Or.inr (Or.inr fun _ => char_ge_zero_or_le_nine _))

theorem EntityId.not_reserved_e_suffix (s : String) :
    ¬ ("e_" ++ s) ∈ Python.ReservedKeywords := by
  have hkw : ∀ kw ∈ Python.ReservedKeywords, '_' ∉ kw.toList := by
    decide
  intro hmem
  have : '_' ∈ ("e_" ++ s).toList := by
    simp [String.toList_append]
  exact (hkw _ hmem) this

theorem EntityId.toPythonName_proof (n : Nat) :
    Python.ValidName.Proof ("e_" ++ toString n) :=
  ⟨EntityId.not_reserved_e_suffix (toString n),
    EntityId.validIdent_e_suffix (toString n)⟩

/-- Collision-free Python identifier derived from an ID, never from a label. -/
def EntityId.toPythonName (id : EntityId) : Python.ValidName :=
  ⟨"e_" ++ toString id.val, EntityId.toPythonName_proof id.val⟩

class HasId (α : Type) where
  id : α → EntityId

def HasId.pythonName {α : Type} [HasId α] (x : α) : Python.ValidName :=
  EntityId.toPythonName (HasId.id x)

structure BoolVar where
  id : EntityId
  label : Option String := none
deriving DecidableEq

instance : HasId BoolVar where
  id v := v.id

inductive BoolLit where
  | var (v : BoolVar)
  | neg (v : BoolVar)
deriving DecidableEq

def BoolLit.varId : BoolLit → EntityId
  | .var v => v.id
  | .neg v => v.id

/-- Integer variable with a nonempty canonical domain. -/
structure IntVar where
  id : EntityId
  domain : NonemptyDomain
  label : Option String := none
deriving DecidableEq

instance : HasId IntVar where
  id v := v.id

inductive LinearExpr : Bounds → Type where
  | fromVar (value : IntVar) : LinearExpr value.domain.hull
  | fromConst (value : Int64) : LinearExpr (Interval.fromValue value)
  | fromNeg
    (a : LinearExpr α)
    (neg_nonoverflow : Int64.Nonoverflow (-α.right : ℤ) ∧ Int64.Nonoverflow (-α.left : ℤ))
      : LinearExpr (α.neg neg_nonoverflow)
  | fromMulConst
    (a : LinearExpr α) (value : Int64)
    (mul_nonoverflow :
      Int64.Nonoverflow (α.mulLower (Interval.fromValue value)) ∧
      Int64.Nonoverflow (α.mulUpper (Interval.fromValue value)))
      : LinearExpr (α.mul (Interval.fromValue value) mul_nonoverflow)
  | fromAdd
    (a : LinearExpr α) (b : LinearExpr β)
    (add_nonoverflow :
      Int64.Nonoverflow ((α.left : ℤ) + β.left) ∧
      Int64.Nonoverflow ((α.right : ℤ) + β.right))
      : LinearExpr (α.add β add_nonoverflow)
  | fromSub
    (a : LinearExpr α) (b : LinearExpr β)
    (sub_nonoverflow :
      Int64.Nonoverflow ((α.left : ℤ) - β.right) ∧
      Int64.Nonoverflow ((α.right : ℤ) - β.left))
      : LinearExpr (α.sub β sub_nonoverflow)

def LinearExpr.intVars {bounds : Bounds} : LinearExpr bounds → List IntVar
  | .fromVar value => [value]
  | .fromConst _ => []
  | .fromNeg a _ => a.intVars
  | .fromMulConst a _ _ => a.intVars
  | .fromAdd a b _ => a.intVars ++ b.intVars
  | .fromSub a b _ => a.intVars ++ b.intVars

def LinearExpr.eval (valuation : EntityId → ℤ)
    {bounds : Bounds} : LinearExpr bounds → ℤ
  | .fromVar value => valuation value.id
  | .fromConst value => value.val
  | .fromNeg a _ => -eval valuation a
  | .fromMulConst a value _ => value.val * eval valuation a
  | .fromAdd a b _ => eval valuation a + eval valuation b
  | .fromSub a b _ => eval valuation a - eval valuation b

/-- Expression bounds are a sound over-approximation under domain-respecting
assignments. -/
theorem LinearExpr.eval_mem_bounds (valuation : EntityId → ℤ)
    {bounds : Bounds} (expr : LinearExpr bounds)
    (inDomain : ∀ v ∈ expr.intVars,
      valuation v.id ∈ v.domain.domain) :
    expr.eval valuation ∈ bounds := by
  induction expr with
  | fromVar value =>
    exact NonemptyDomain.mem_hull value.domain
      (inDomain value (List.mem_singleton.mpr rfl))
  | fromConst value =>
    simp [LinearExpr.eval, Interval.mem_fromValue]
  | fromNeg a h ih =>
    exact Interval.eval_neg _ h (ih (fun v hv => inDomain v hv))
  | fromMulConst a value h ih =>
    simpa [LinearExpr.eval] using
      Interval.mul_const_mem _ value _
        (ih (fun v hv => inDomain v hv)) h
  | fromAdd a b h iha ihb =>
    exact Interval.eval_add _ _ h
      (iha (fun v hv => inDomain v (List.mem_append.mpr (Or.inl hv))))
      (ihb (fun v hv => inDomain v (List.mem_append.mpr (Or.inr hv))))
  | fromSub a b h iha ihb =>
    exact Interval.eval_sub _ _ h
      (iha (fun v hv => inDomain v (List.mem_append.mpr (Or.inl hv))))
      (ihb (fun v hv => inDomain v (List.mem_append.mpr (Or.inr hv))))

abbrev LinearExpr.WithBounds := Σ b : Bounds, LinearExpr b

/-- Half-open interval `[start, start + size)`. -/
structure FixedSizeIntervalVar where
  id : EntityId
  startBounds : Bounds
  start : LinearExpr startBounds
  size : Int64
  size_nonneg : (0 : ℤ) ≤ size
  label : Option String := none

instance : HasId FixedSizeIntervalVar where
  id v := v.id

def FixedSizeIntervalVar.intVars (value : FixedSizeIntervalVar) : List IntVar :=
  value.start.intVars

inductive BoundedLinearExpr.Rel where
  | eq | neq | gt | gte | lt | lte
deriving DecidableEq

structure BoundedLinearExpr where
  rel : BoundedLinearExpr.Rel
  leftBounds : Bounds
  rightBounds : Bounds
  left : LinearExpr leftBounds
  right : LinearExpr rightBounds

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

inductive Constraint.Enforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))
deriving DecidableEq

structure CumulativeItem where
  interval : FixedSizeIntervalVar
  demand : LinearExpr.WithBounds

inductive Constraint.Variant where
  | bounded_linear (expr : BoundedLinearExpr)
  | max_equality
    (target : LinearExpr.WithBounds)
    (exprs : Array LinearExpr.WithBounds)
  | div_eq
    (target : LinearExpr.WithBounds)
    (numerator : LinearExpr.WithBounds)
    (divisor : Int64)
    (divisor_pos : (0 : ℤ) < divisor)
  | allowed_assignments {n : Nat}
    (vars : Vector IntVar n)
    (rows : Array (Vector Int64 n))
  | cumulative
    (items : Array CumulativeItem)
    (capacity : LinearExpr.WithBounds)
  | bool_and (terms : Array BoolLit)
  | bool_or (terms : Array BoolLit)
  | implication (src : BoolLit) (dst : BoolLit)

structure Constraint where
  id : EntityId
  label : Option String := none
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant

instance : HasId Constraint where
  id c := c.id

def BoundedLinearExpr.intVars (value : BoundedLinearExpr) : List IntVar :=
  value.left.intVars ++ value.right.intVars

def LinearExpr.WithBounds.intVars (e : LinearExpr.WithBounds) : List IntVar :=
  e.snd.intVars

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

inductive Objective where
  | none
  | minimize (expr : LinearExpr.WithBounds)
  | maximize (expr : LinearExpr.WithBounds)

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
