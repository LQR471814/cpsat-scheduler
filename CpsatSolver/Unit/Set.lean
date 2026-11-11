module

public import CpsatSolver.Unit.Scale

public section

namespace CpsatSolver.Unit

@[expose]
def Set.Divisibility (fs : Finset Scale) : Prop :=
  ∀ a ∈ fs, ∀ b ∈ fs, b ≤ a → b.val ∣ a.val

instance (fs : Finset Scale) : Decidable (Set.Divisibility fs) := by
  unfold Set.Divisibility
  infer_instance

structure Set where
  fs : Finset Scale
  has_atomic : Scale.atomic ∈ fs
  divisibility : Set.Divisibility fs
deriving DecidableEq

def Set.of
  (fs : Finset Scale)
  (has_atomic : Scale.atomic ∈ fs := by native_decide)
  (divisibility : Set.Divisibility fs := by native_decide) : Set :=
  ⟨fs, has_atomic, divisibility⟩

def Set.atomic (_units : Set) : Scale := Scale.atomic

abbrev Set.elem (s : Set) : Type := { x : Scale // x ∈ s.fs }

theorem Set.pos {S : Set} (e : S.elem) : e.val > (0 : ℤ) :=
  e.val.pos

end CpsatSolver.Unit
