import CpsatScheduler.CpsatSolver.Python
import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs

namespace CpsatSolver

def Int64.min : ℤ := -(2 : ℤ)^63
def Int64.max : ℤ := ((2 : ℤ)^63 - 1)
def Int64.Proof (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max


structure Interval where
  min : ℤ
  max : ℤ

def Interval.Proof (it : Interval) :=
  it.min ≤ it.max ∧
  Int64.Proof it.min ∧
  Int64.Proof it.max


/-- BoolVar is a boolean variable -/
structure BoolVar where
  name : String
  nameValid : CpsatSolver.Python.ValidID name


-- BoolLit is a CpsatSolver.BoolVar or its negation
inductive BoolLit where
  | var (v : CpsatSolver.BoolVar)
  | neg (v : CpsatSolver.BoolVar)


/-- IntVar is an integer variable bounded to a finite domain -/
structure IntVar where
  /-- name is the identifier of the variable -/
  name : String
  nameValid : CpsatSolver.Python.ValidID name
  domain : CpsatSolver.Interval

def IntVar.Proof (var : IntVar) :=
  Interval.Proof var.domain


mutual

/-- LinearExpr is a linear expr that evaluates to an ℤ -/
inductive LinearExpr.Op where
  | var (value : CpsatSolver.IntVar) (H : CpsatSolver.IntVar.Proof value)
  | const (value : ℤ) (H : CpsatSolver.Int64.Proof value)
  | neg (a : LinearExpr.Proven)
  | add (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | mul (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | sub (a : LinearExpr.Proven) (b : LinearExpr.Proven)

structure LinearExpr.Proof where
  domain : CpsatSolver.Interval
  domainValid : CpsatSolver.Interval.Proof domain

structure LinearExpr.Proven where
  op : LinearExpr.Op
  proof : LinearExpr.Proof

end


structure FixedSizeIntervalVar where
  -- name is also the identifier
  name : String
  nameValid : CpsatSolver.Python.ValidID name
  start : LinearExpr.Proven
  size : ℕ


-- BoundedLinearExpr is LinearExpr with some bounding operators applied on it
-- (e.g. >, <, ==)
inductive BoundedLinearExpr where
  | eq (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | neq (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | gt (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | gte (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | lt (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | lte (a : LinearExpr.Proven) (b : LinearExpr.Proven)


inductive Constraint.Enforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))

inductive Constraint.Variant where
  /-- Corresponds to <model>.add -/
  | bounded_linear (expr : CpsatSolver.BoundedLinearExpr)
  /-- Corresponds to <model>.add_max_equality -/
  | max_equality (target : LinearExpr.Proven) (exprs : List LinearExpr.Proven)
  /-- Corresponds to <model>.add_cumulative -/
  | cumulative
    (intervals : List CpsatSolver.Interval)
    (demands : List LinearExpr.Proven)
    (capacity : LinearExpr.Proven)
  /-- Corresponds to <model>.add_bool_and -/
  | bool_and (terms : List CpsatSolver.BoolLit)
  /-- Corresponds to <model>.add_bool_or -/
  | bool_or (terms : List CpsatSolver.BoolLit)
  /-- Corresponds to <model>.add_implication -/
  | implication (src : CpsatSolver.BoolLit) (dst : CpsatSolver.BoolLit)

structure Constraint where
  name : String
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant

end CpsatSolver
