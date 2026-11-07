import CpsatSolver.Unit.Scale

namespace CpsatSolver.Unit

def Set.Divisibility (fs : Finset Scale) : Prop :=
  ∀ a ∈ fs, ∀ b ∈ fs, b ≤ a → (b.val : ℕ) ∣ a.val

instance (fs : Finset Scale) : Decidable (Set.Divisibility fs) := by
  unfold Set.Divisibility
  infer_instance

structure Set where
  fs : Finset Scale
  has_atomic : Scale.atomic ∈ fs
  divisibility : Set.Divisibility fs

def Set.of
  (fs : Finset Scale)
  (has_atomic : Scale.atomic ∈ fs := by native_decide)
  (divisibility : Set.Divisibility fs := by native_decide) : Set :=
  ⟨fs, has_atomic, divisibility⟩

def Set.atomic (_units : Set) : Scale := Scale.atomic

def Set.elem (s : Set) : Type := { x : Scale // x ∈ s.fs }

end CpsatSolver.Unit
