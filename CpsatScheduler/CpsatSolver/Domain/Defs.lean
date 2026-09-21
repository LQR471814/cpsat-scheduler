import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs

namespace CpsatSolver

abbrev Int64.min : ℤ := -(2 : ℤ) ^ 63
abbrev Int64.max : ℤ := (2 : ℤ) ^ 63 - 1
abbrev Int64.Nonoverflow (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

abbrev Int64 := { x : ℤ // Int64.Nonoverflow x }

def Int64.of (n : ℤ) (h : Int64.Nonoverflow n := by decide) : Int64 :=
  ⟨n, h⟩

/-- Closed interval over `Int64`. Also used as conservative expression bounds. -/
structure Interval where
  left : Int64
  right : Int64
  left_le_right : (left : ℤ) ≤ right
deriving DecidableEq

def Interval.mem (i : Interval) (x : ℤ) : Prop :=
  (i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)

instance : Membership ℤ Interval where
  mem i x := i.mem x

instance {i : Interval} {x : ℤ} : Decidable (x ∈ i) :=
  inferInstanceAs (Decidable ((i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)))

abbrev Bounds := Interval

def Interval.toSet (i : Interval) : Set ℤ :=
  Set.Icc (i.left : ℤ) i.right

def Interval.fromValue (v : Int64) : Interval :=
  { left := v, right := v, left_le_right := le_rfl }

/-- Consecutive domain fragments must have a gap of at least one integer. -/
def Interval.separated (a b : Interval) : Prop :=
  (a.right : ℤ) + 1 < (b.left : ℤ)

/-- Canonical sparse domain: pairwise separated, hence sorted, disjoint, and
nonadjacent. Empty domains are allowed. -/
structure Domain where
  intervals : List Interval
  pairwise : intervals.Pairwise Interval.separated
deriving DecidableEq

def Domain.singleton (v : Int64) : Domain :=
  ⟨[Interval.fromValue v], List.pairwise_singleton _ _⟩

instance : Membership ℤ Domain where
  mem d x := ∃ i ∈ d.intervals, x ∈ i

def Domain.toSet (d : Domain) : Set ℤ := {x | x ∈ d}

def Domain.empty : Domain :=
  ⟨[], List.Pairwise.nil⟩

structure NonemptyDomain where
  domain : Domain
  nonempty : domain.intervals ≠ []
deriving DecidableEq

end CpsatSolver

