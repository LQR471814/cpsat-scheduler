import Mathlib.Order.Interval.Finset.Defs
import Mathlib.Data.Int.Interval
import Mathlib.Data.Finset.Union

def ModelIntDomain := Finset.Icc (-(2 : ℤ)^63) ((2 : ℤ)^63 - 1)
abbrev ModelInt := {x : ℤ // x ∈ ModelIntDomain}

-- BoolVar is a boolean variable
structure BoolVar where
  name : String

-- Intvar is an integer variable bounded to a finite domain
structure IntVar where
  name : String
  min : ModelInt
  max : ModelInt

def IntVar.domain (v : IntVar) := Finset.Icc v.min v.max

-- LinearExpr is a linear expr that evaluates to an ℤ
inductive LinearExpr where
  | id (value : IntVar)
  | const (value : ModelInt)
  | neg (a : LinearExpr)
  | add (a : LinearExpr) (b : LinearExpr)
  | mul (a : LinearExpr) (b : LinearExpr)
  | sub (a : LinearExpr) (b : LinearExpr)

-- BoolLit is a BoolVar or its negation
inductive BoolLit where
  | id (v : BoolVar)
  | neg (v : BoolVar)

-- BoundedLinearExpr is LinearExpr with some bounding operators applied on it
-- (e.g. >, <, ==)
inductive BoundedLinearExpr where
  | eq (a : LinearExpr) (b : LinearExpr)
  | neq (a : LinearExpr) (b : LinearExpr)
  | gt (a : LinearExpr) (b : LinearExpr)
  | gte (a : LinearExpr) (b : LinearExpr)
  | lt (a : LinearExpr) (b : LinearExpr)
  | lte (a : LinearExpr) (b : LinearExpr)

inductive ConstraintEnforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))

structure Constraint where
  name : String
  expr : BoundedLinearExpr
  enforce : ConstraintEnforcement

