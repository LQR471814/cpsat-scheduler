import Mathlib.Data.Char
import CpsatScheduler.Python.Basic
import CpsatScheduler.CpsatSolver.Domain.NonemptyDomain
import CpsatScheduler.CpsatSolver.Unit.Set

namespace CpsatSolver

structure BoolVar where
  id : Nat
  label : Option String := none
deriving DecidableEq

inductive BoolLit where
  | var (v : BoolVar)
  | neg (v : BoolVar)
deriving DecidableEq

/-- Integer variable with a nonempty canonical domain. -/
structure IntVar where
  id : Nat
  domain : NonemptyDomain
  label : Option String := none
deriving DecidableEq

structure UnitAwareIntVar (us : Unit.Set) where
  intVar : IntVar
  scale : us.elem

def LinearExpr.Nonoverflow.Neg (b : Interval) : Prop :=
  Int64.Nonoverflow (-b.right : ℤ) ∧
  Int64.Nonoverflow (-b.left : ℤ)

def LinearExpr.Nonoverflow.Mul (b : Interval) (v : Int64) : Prop :=
  Int64.Nonoverflow (b.mulLower (Interval.ofValue v)) ∧
  Int64.Nonoverflow (b.mulUpper (Interval.ofValue v))

def LinearExpr.Nonoverflow.Add (a b : Interval) : Prop :=
  Int64.Nonoverflow ((a.left : ℤ) + b.left) ∧
  Int64.Nonoverflow ((a.right : ℤ) + b.right)

def LinearExpr.Nonoverflow.Sub (a b : Interval) : Prop :=
  Int64.Nonoverflow ((a.left : ℤ) - b.right) ∧
  Int64.Nonoverflow ((a.right : ℤ) - b.left)

instance (b : Interval) : Decidable (LinearExpr.Nonoverflow.Neg b) := by
  unfold LinearExpr.Nonoverflow.Neg
  infer_instance

instance (b : Interval) (v : Int64) : Decidable (LinearExpr.Nonoverflow.Mul b v) := by
  unfold LinearExpr.Nonoverflow.Mul
  infer_instance

instance (a b : Interval) : Decidable (LinearExpr.Nonoverflow.Add a b) := by
  unfold LinearExpr.Nonoverflow.Add
  infer_instance

instance (a b : Interval) : Decidable (LinearExpr.Nonoverflow.Sub a b) := by
  unfold LinearExpr.Nonoverflow.Sub
  infer_instance

inductive LinearExpr : Interval → Type where
  | fromVar (value : IntVar) : LinearExpr value.domain.hull
  | fromConst (value : Int64) : LinearExpr (Interval.ofValue value)
  | fromNeg
    (a : LinearExpr B)
    (h : LinearExpr.Nonoverflow.Neg B)
      : LinearExpr (B.neg h)
  | fromMulConst
    (a : LinearExpr B) (v : Int64)
    (h : LinearExpr.Nonoverflow.Mul B v)
      : LinearExpr (B.mul (Interval.ofValue v) h)
  | fromAdd
    (a : LinearExpr A) (b : LinearExpr B)
    (h : LinearExpr.Nonoverflow.Add A B)
      : LinearExpr (A.add B h)
  | fromSub
    (a : LinearExpr A) (b : LinearExpr B)
    (h : LinearExpr.Nonoverflow.Sub A B)
      : LinearExpr (A.sub B h)

abbrev LinearExpr.WithInterval := Σ b : Interval, LinearExpr b

def LinearExpr.wrapInterval (e : LinearExpr α) : LinearExpr.WithInterval :=
  Sigma.mk α e

/-- Half-open interval `[start, start + size`. -/
structure FixedSizeIntervalVar where
  id : Nat
  startInterval : Interval
  start : LinearExpr startInterval
  size : Int64
  size_nonneg : (0 : ℤ) ≤ size
  label : Option String := none

inductive BoundedLinearExpr.Rel where
  | eq | neq | gt | gte | lt | lte
deriving DecidableEq

structure BoundedLinearExpr where
  rel : BoundedLinearExpr.Rel
  leftInterval : Interval
  rightInterval : Interval
  left : LinearExpr leftInterval
  right : LinearExpr rightInterval

inductive Constraint.Enforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))
deriving DecidableEq

structure CumulativeItem where
  interval : FixedSizeIntervalVar
  demand : LinearExpr.WithInterval

inductive Constraint.Variant where
  | bounded_linear (expr : BoundedLinearExpr)
  | max_equality
    (target : LinearExpr.WithInterval)
    (exprs : Array LinearExpr.WithInterval)
    (nonempty : exprs.size > 0 := by native_decide)
  | div_eq
    (target : LinearExpr.WithInterval)
    (numerator : LinearExpr.WithInterval)
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
    (items : Array CumulativeItem)
    (capacity : LinearExpr.WithInterval)
  | bool_and (terms : Array BoolLit)
    (nonempty : terms.size > 0)
  | bool_or (terms : Array BoolLit)
    (nonempty : terms.size > 0)
  | implication (src : BoolLit) (dst : BoolLit)

structure Constraint where
  id : Nat
  label : Option String := none
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant

inductive Objective where
  | none
  | minimize (expr : LinearExpr.WithInterval)
  | maximize (expr : LinearExpr.WithInterval)

end CpsatSolver
