module

public import Mathlib.Algebra.Order.Ring.Int
public import Mathlib.Order.Interval.Set.Defs
public import Mathlib.Data.List.Pairwise
public import Mathlib.Data.List.Basic

public section

namespace CpsatSolver

abbrev Int64.min : ℤ := -(2 : ℤ) ^ 63

abbrev Int64.max : ℤ := (2 : ℤ) ^ 63 - 1

@[expose]
def Int64.Nonoverflow (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

instance (b : ℤ) : Decidable (Int64.Nonoverflow b) := by
  unfold Int64.Nonoverflow
  infer_instance

abbrev Int64 := { x : ℤ // Int64.Nonoverflow x }

@[expose]
def Int64.of (n : ℤ) (h : Int64.Nonoverflow n := by native_decide) : Int64 :=
  ⟨n, h⟩

@[expose]
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

@[expose]
def Interval.of (l r : ℤ)
  (hl : Int64.Nonoverflow l := by native_decide)
  (hr : Int64.Nonoverflow r := by native_decide)
  (hlr : l ≤ r := by native_decide) : Interval :=
  {
    left := Subtype.mk l hl
    right := Subtype.mk r hr
    left_le_right := hlr
  }

@[expose]
def Interval.mem (i : Interval) (x : ℤ) : Prop :=
  (i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)

instance : Membership ℤ Interval where
  mem i x := i.mem x

instance : HasSubset Interval where
  Subset a b := b.left ≤ a.left ∧ a.right ≤ b.right

instance {i : Interval} {x : ℤ} : Decidable (x ∈ i) := by
  simp only [Membership.mem, Interval.mem]
  infer_instance

@[expose]
def Interval.toSet (i : Interval) : Set ℤ :=
  Set.Icc (i.left : ℤ) i.right

@[expose]
def Interval.ofValue (v : Int64) : Interval :=
  { left := v, right := v, left_le_right := le_rfl }

/-- Consecutive domain fragments must have a gap of at least one integer. -/
@[expose]
def Interval.separated (a b : Interval) : Prop :=
  (a.right : ℤ) + 1 < (b.left : ℤ)

instance : DecidableRel Interval.separated :=
  fun a b => inferInstanceAs (Decidable ((a.right : ℤ) + 1 < (b.left : ℤ)))

structure Domain where
  intervals : List Interval
  pairwise : intervals.Pairwise Interval.separated
deriving DecidableEq

@[expose]
def Domain.singleton (v : Int64) : Domain :=
  ⟨[Interval.ofValue v], List.pairwise_singleton _ _⟩

instance : Membership ℤ Domain where
  mem d x := ∃ i ∈ d.intervals, x ∈ i

@[expose]
def Domain.toSet (d : Domain) : Set ℤ := {x | x ∈ d}

@[expose]
def Domain.empty : Domain :=
  ⟨[], List.Pairwise.nil⟩

structure NonemptyDomain where
  domain : Domain
  nonempty : domain.intervals ≠ []
deriving DecidableEq

@[expose]
def NonemptyDomain.of
  (domain : Domain)
  (h : domain.intervals ≠ [] :=
    by
      simp [Domain.canonicalize, Domain.mergeOne]
      native_decide) : NonemptyDomain :=
  ⟨domain, h⟩

end CpsatSolver

abbrev int (n : ℤ)
  (h : CpsatSolver.Int64.Nonoverflow n := by native_decide) :=
  CpsatSolver.Int64.of n h

