import Mathlib.Order.Interval.Basic
import Mathlib.Algebra.Group.Int.Defs

namespace CpsatSolver

abbrev Int64.min : ℤ := -(2 : ℤ) ^ 63
abbrev Int64.max : ℤ := (2 : ℤ) ^ 63 - 1
def Int64.Nonoverflow (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

instance (b : ℤ) : Decidable (Int64.Nonoverflow b) := by
  unfold Int64.Nonoverflow
  infer_instance

abbrev Int64 := { x : ℤ // Int64.Nonoverflow x }

def Int64.of (n : ℤ) (h : Int64.Nonoverflow n := by native_decide) : Int64 :=
  ⟨n, h⟩

def Int64.ofFloat? (f : Float) : Option Int64 :=
  if h :
    f ≥ CpsatSolver.Int64.min.toFloat ∧
    f ≤ CpsatSolver.Int64.max.toFloat then
    .some (Subtype.mk
      (f.toInt64.toInt)
      (by
        dsimp [Int64.Nonoverflow,
          Int64.min,
          Int64.max,
          Int64.toInt,
          Float.toInt64,
          Float.toModel,
          BitVec.toInt]
        omega))
  else
    .none

/-- Closed interval over `Int64`. Also used as conservative expression bounds. -/
structure Interval where
  left : Int64
  right : Int64
  left_le_right : (left : ℤ) ≤ right
deriving DecidableEq

def Interval.of (l r : ℤ)
  (hl : Int64.Nonoverflow l := by native_decide)
  (hr : Int64.Nonoverflow r := by native_decide)
  (hlr : l ≤ r := by native_decide) : Interval :=
  {
    left := Subtype.mk l hl
    right := Subtype.mk r hr
    left_le_right := hlr
  }

def Interval.mem (i : Interval) (x : ℤ) : Prop :=
  (i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)

instance : Membership ℤ Interval where
  mem i x := i.mem x

instance {i : Interval} {x : ℤ} : Decidable (x ∈ i) :=
  inferInstanceAs (Decidable ((i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)))

def Interval.toSet (i : Interval) : Set ℤ :=
  Set.Icc (i.left : ℤ) i.right

def Interval.ofValue (v : Int64) : Interval :=
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
  ⟨[Interval.ofValue v], List.pairwise_singleton _ _⟩

instance : Membership ℤ Domain where
  mem d x := ∃ i ∈ d.intervals, x ∈ i

def Domain.toSet (d : Domain) : Set ℤ := {x | x ∈ d}

def Domain.empty : Domain :=
  ⟨[], List.Pairwise.nil⟩

structure NonemptyDomain where
  domain : Domain
  nonempty : domain.intervals ≠ []
deriving DecidableEq

def NonemptyDomain.of (domain : Domain)
    (h : domain.intervals ≠ [] :=
      by simp [Domain.canonicalize, Domain.mergeOne]) :
      NonemptyDomain :=
  { domain := domain, nonempty := h }

end CpsatSolver

abbrev int (n : ℤ)
  (h : CpsatSolver.Int64.Nonoverflow n := by native_decide) :=
  CpsatSolver.Int64.of n h

