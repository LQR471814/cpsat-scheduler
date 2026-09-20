import Mathlib.Data.Char
import CpsatScheduler.CpsatSolver.Python
import CpsatScheduler.CpsatSolver.Domain.NonemptyDomain

namespace CpsatSolver

/-- Opaque solver entity identity, allocated from one global builder counter. -/
structure EntityId where
  val : Nat
deriving DecidableEq, Repr

instance : LT EntityId where
  lt a b := a.val < b.val

instance : DecidableLT EntityId :=
  fun a b => inferInstanceAs (Decidable (a.val < b.val))

structure BoolVar where
  id : EntityId
  label : Option String := none
deriving DecidableEq

inductive BoolLit where
  | var (v : BoolVar)
  | neg (v : BoolVar)
deriving DecidableEq

/-- Integer variable with a nonempty canonical domain. -/
structure IntVar where
  id : EntityId
  domain : NonemptyDomain
  label : Option String := none
deriving DecidableEq

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

abbrev LinearExpr.WithBounds := Σ b : Bounds, LinearExpr b

/-- Half-open interval `[start, start + size)`. -/
structure FixedSizeIntervalVar where
  id : EntityId
  startBounds : Bounds
  start : LinearExpr startBounds
  size : Int64
  size_nonneg : (0 : ℤ) ≤ size
  label : Option String := none

inductive BoundedLinearExpr.Rel where
  | eq | neq | gt | gte | lt | lte
deriving DecidableEq

structure BoundedLinearExpr where
  rel : BoundedLinearExpr.Rel
  leftBounds : Bounds
  rightBounds : Bounds
  left : LinearExpr leftBounds
  right : LinearExpr rightBounds

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

inductive Objective where
  | none
  | minimize (expr : LinearExpr.WithBounds)
  | maximize (expr : LinearExpr.WithBounds)

end CpsatSolver
