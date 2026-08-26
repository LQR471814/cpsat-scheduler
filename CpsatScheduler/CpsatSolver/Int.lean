import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs

namespace CpsatSolver

def Int64.min : ℤ := -(2 : ℤ)^63

def Int64.max : ℤ := ((2 : ℤ)^63 - 1)

def Int64.Proof (b : ℤ) : Prop :=
  b ≥ Int64.min ∧ b ≤ Int64.max

instance : Decidable (Int64.Proof α) :=
  (inferInstance : Decidable (α ≥ Int64.min ∧ α ≤ Int64.max))

structure Interval where
  min : ℤ
  max : ℤ

def Interval.Proof (it : Interval) :=
  it.min ≤ it.max ∧
  Int64.Proof it.min ∧
  Int64.Proof it.max

instance : Decidable (Interval.Proof α) :=
  (inferInstance : Decidable (
    α.min ≤ α.max ∧
    Int64.Proof α.min ∧
    Int64.Proof α.max
  ))

end CpsatSolver
