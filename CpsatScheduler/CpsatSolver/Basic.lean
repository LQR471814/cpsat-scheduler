import CpsatScheduler.CpsatSolver.Python
import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs

namespace CpsatSolver

def Int64.min : ℤ := -(2 : ℤ)^63
def Int64.max : ℤ := ((2 : ℤ)^63 - 1)
def Int64.Proof (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

structure Int64.Proven where
  val : ℤ
  proof : Int64.Proof val

structure Interval where
  min : ℤ
  max : ℤ
  deriving DecidableEq

def Interval.Proof (it : Interval) :=
  it.min ≤ it.max ∧
  Int64.Proof it.min ∧
  Int64.Proof it.max


class Var (α : Type) where
  name (var : α) : CpsatSolver.Python.ValidName


/-- BoolVar is a boolean variable -/
structure BoolVar where
  name : CpsatSolver.Python.ValidName
  deriving DecidableEq

instance : Var BoolVar where
  name var := var.name


-- BoolLit is a CpsatSolver.BoolVar or its negation
inductive BoolLit where
  | var (v : CpsatSolver.BoolVar)
  | neg (v : CpsatSolver.BoolVar)
  deriving DecidableEq


/-- IntVar is an integer variable bounded to a finite domain -/
structure IntVar where
  /-- name is the identifier of the variable -/
  name : CpsatSolver.Python.ValidName
  domain : CpsatSolver.Interval
  deriving DecidableEq

def IntVar.Proof (var : IntVar) :=
  Interval.Proof var.domain

instance : Var IntVar where
  name var := var.name

mutual

/-- LinearExpr is a linear expr that evaluates to an ℤ -/
inductive LinearExpr.Op where
  | var (value : CpsatSolver.IntVar) (H : CpsatSolver.IntVar.Proof value)
  | const (value : ℤ) (H : CpsatSolver.Int64.Proof value)
  | neg (a : LinearExpr.Proven)
  | add (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | mul (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | sub (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  deriving DecidableEq

structure LinearExpr.Proof where
  domain : CpsatSolver.Interval
  domainValid : CpsatSolver.Interval.Proof domain
  deriving DecidableEq

structure LinearExpr.Proven where
  op : LinearExpr.Op
  proof : LinearExpr.Proof
  deriving DecidableEq

end


structure FixedSizeIntervalVar where
  -- name is also the identifier
  name : CpsatSolver.Python.ValidName
  start : LinearExpr.Proven
  size : ℕ
  deriving DecidableEq

instance : Var FixedSizeIntervalVar where
  name var := var.name


-- BoundedLinearExpr is LinearExpr with some bounding operators applied on it
-- (e.g. >, <, ==)
inductive BoundedLinearExpr where
  | eq (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | neq (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | gt (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | gte (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | lt (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | lte (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  deriving DecidableEq


inductive Constraint.Enforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))
  deriving DecidableEq

inductive Constraint.Variant where
  /-- Corresponds to <model>.add -/
  | bounded_linear (expr : CpsatSolver.BoundedLinearExpr)
  /-- Corresponds to <model>.add_max_equality -/
  | max_equality (target : LinearExpr.Proven) (exprs : Array LinearExpr.Proven)
  /-- Corresponds to <model>.add_cumulative -/
  | cumulative
    (intervals : Array CpsatSolver.FixedSizeIntervalVar)
    (demands : Array LinearExpr.Proven)
    (capacity : LinearExpr.Proven)
  /-- Corresponds to <model>.add_bool_and -/
  | bool_and (terms : Array CpsatSolver.BoolLit)
  /-- Corresponds to <model>.add_bool_or -/
  | bool_or (terms : Array CpsatSolver.BoolLit)
  /-- Corresponds to <model>.add_implication -/
  | implication (src : CpsatSolver.BoolLit) (dst : CpsatSolver.BoolLit)
  deriving DecidableEq

structure Constraint where
  name : Python.ValidName
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant
  deriving DecidableEq

end CpsatSolver
