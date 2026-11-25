-- perhaps what we actually want is a "derived identity", where the identity of
-- an object depends on the identity of other objects?
--
-- where such objects may be other derived identities or certain "primitive
-- values"
--
-- if two objects have the same "derived identity" then they are equal
--
-- this solves the problem where: I have an object and I create two objects
-- from that same reference point, if they have different internal properties,
-- then they are different, if they have the exact same internal properties,
-- then by definition, they are exactly the same
--
-- each object should probably also come with a theorem that states if their
-- "derived identity" is equal, then they are definitionally equal
--
-- well what I have described is literally definitional equality. it simply
-- doesn't "feel" like definitional equality because now certain objects may
-- refer to other objects it is completely unrelated to

module

public import CpsatScheduler.Internal.CpsatSolver.Domain.Interval
public import CpsatScheduler.Internal.CpsatSolver.Unit.Set
public import CpsatScheduler.Internal.CpsatSolver.Domain.NonemptyDomain

public section

namespace CpsatSolver

structure IntVar where
  label : Option String := none
  domain : NonemptyDomain
deriving DecidableEq

structure BoolVar where
  label : Option String := none
deriving DecidableEq

inductive BoolLit where
  | var (v : BoolVar)
  | neg (v : BoolVar)
deriving DecidableEq

structure UnitAwareIntVar (us : Unit.Set) where
  intVar : IntVar
  scale : us.elem
deriving DecidableEq

def IntVar.domainHull (i : IntVar) : Interval :=
  i.domain.hull

inductive LinearExpr.Raw where
  | fromVar (value : IntVar)
  | fromConst (value : Int64)
  | fromNeg (a : LinearExpr.Raw)
  | fromMulConst (a : LinearExpr.Raw) (v : Int64)
  | fromAdd (a b : LinearExpr.Raw)
  | fromSub (a b : LinearExpr.Raw)
deriving DecidableEq

inductive LinearExpr.Proof : LinearExpr.Raw → Interval → Prop where
  | fromVar (value : IntVar) :
      LinearExpr.Proof (.fromVar value) value.domainHull
  | fromConst (value : Int64) :
      LinearExpr.Proof (.fromConst value) (Interval.ofValue value)
  | fromNeg {a : LinearExpr.Raw} {B : Interval}
      (ha : LinearExpr.Proof a B) (h : Interval.Nonoverflow.Neg B) :
        LinearExpr.Proof (.fromNeg a) (B.neg h)
  | fromMulConst {a : LinearExpr.Raw} {B : Interval} (v : Int64)
      (ha : LinearExpr.Proof a B) (h : Interval.Nonoverflow.MulConst B v) :
        LinearExpr.Proof
          (.fromMulConst a v)
          (B.mul (Interval.ofValue v) h)
  | fromAdd {a b : LinearExpr.Raw} {A B : Interval}
      (ha : LinearExpr.Proof a A)
      (hb : LinearExpr.Proof b B)
      (h : Interval.Nonoverflow.Add A B) :
        LinearExpr.Proof (.fromAdd a b) (A.add B h)
  | fromSub {a b : LinearExpr.Raw} {A B : Interval}
      (ha : LinearExpr.Proof a A)
      (hb : LinearExpr.Proof b B)
      (h : Interval.Nonoverflow.Sub A B) :
        LinearExpr.Proof (.fromSub a b) (A.sub B h)

structure LinearExpr where
  raw : LinearExpr.Raw
  interval : Interval
  proof : LinearExpr.Proof raw interval
deriving DecidableEq

/-- Half-open interval `[start, start + size)`. -/
structure FixedSizeIntervalVar where
  start : LinearExpr
  size : Int64
  size_nonneg : (0 : ℤ) ≤ size
  label : Option String := none
deriving DecidableEq

inductive BoundedLinearExpr.Rel where
  | eq | neq | gt | gte | lt | lte
deriving DecidableEq

structure BoundedLinearExpr where
  rel : BoundedLinearExpr.Rel
  left : LinearExpr
  right : LinearExpr
deriving DecidableEq

structure Constraint.CumulativeItem where
  interval : FixedSizeIntervalVar
  demand : LinearExpr
deriving DecidableEq

inductive Constraint.Enforcement where
  | always
  | onlyWhenAll (literals : Array BoolLit) (h : literals ≠ #[])
deriving DecidableEq

inductive Constraint.Variant where
  | bounded_linear (expr : BoundedLinearExpr)
  | max_equality
    (target : LinearExpr)
    (exprs : Array LinearExpr)
    (nonempty : exprs.size > 0 := by native_decide)
  | div_eq
    (target : LinearExpr)
    (numerator : LinearExpr)
    (divisor : Int64)
    (divisor_pos : (0 : ℤ) < divisor := by native_decide)
  | allowed_assignments {n : Nat}
    (vars : Vector IntVar n)
    (rows : Array (Vector Int64 n))
    (nonempty : rows.size > 0 := by native_decide)
    (within_domain :
      ∀ row ∈ rows,
      ∀ i : Fin vars.size,
        (row[i].val : ℤ) ∈ vars[i].domain.domain
      := by native_decide)
  | cumulative
    (items : Array Constraint.CumulativeItem)
    (capacity : LinearExpr)
  | bool_and (terms : Array BoolLit)
    (nonempty : terms.size > 0)
  | bool_or (terms : Array BoolLit)
    (nonempty : terms.size > 0)
  | implication (src : BoolLit) (dst : BoolLit)
deriving DecidableEq

structure Constraint where
  label : Option String := none
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant
deriving DecidableEq

inductive Objective where
  | none
  | minimize (expr : LinearExpr)
  | maximize (expr : LinearExpr)
deriving DecidableEq

end CpsatSolver
