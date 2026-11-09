-- perhaps what we actually want is a "derived identity", where the identity of
-- an object depends on the identity of other objects?
--
-- where such objects may be other derived identities or certain "primitive
-- values"
--
-- if two objects have the same "derived identity" then they are equal
--
-- this solves the problem where: I have an object and I create two objects
-- from that same reference point, if they have different internal properties,
-- then they are different, if they have the exact same internal properties,
-- then by definition, they are exactly the same
--
-- each object should probably also come with a theorem that states if their
-- "derived identity" is equal, then they are definitionally equal
--
-- well what I have described is literally definitional equality. it simply
-- doesn't "feel" like definitional equality because now certain objects may
-- refer to other objects it is completely unrelated to

import Mathlib.Data.Finset.Basic
import Mathlib.Data.Char
import Mathlib.Data.Nat.Pairing
import Mathlib.Logic.Equiv.Nat
import Mathlib.Logic.Encodable.Basic

import CpsatScheduler.Python.Basic
import CpsatSolver.Domain.NonemptyDomain
import CpsatSolver.Unit.Set

namespace CpsatSolver

class HasID (α : Type) where
  id (x : α) : ℕ
  inj : Function.Injective id

structure DerivedIdentity (α : Type) [HasID α] where
  object : α
  otherID : ℕ
deriving DecidableEq

instance {α : Type} [HasID α] : HasID (DerivedIdentity α) where
  id x := Nat.pair (HasID.id x.object) x.otherID
  inj := by
    intro a₁ a₂ h
    simp only [Nat.pair_eq_pair] at h
    cases a₁
    cases a₂
    simp only [DerivedIdentity.mk.injEq]
    exact ⟨HasID.inj h.1, h.2⟩

def encodeOption {α : Type} (f : α → ℕ) : Option α → ℕ
  | .none => 0
  | .some a => f a + 1

theorem encodeOption_inj {α : Type} {f : α → ℕ} (hf : Function.Injective f) :
    Function.Injective (encodeOption f) := by
  intro a b h
  cases a <;> cases b <;> simp only [encodeOption] at h
  · rfl
  · exact absurd h.symm (Nat.succ_ne_zero _)
  · exact absurd h (Nat.succ_ne_zero _)
  · exact congrArg _ (hf (Nat.succ_injective h))

def encodeList {α : Type} (f : α → ℕ) : List α → ℕ
  | [] => 0
  | a :: t => Nat.pair (f a + 1) (encodeList f t) + 1

theorem encodeList_inj {α : Type} {f : α → ℕ} (hf : Function.Injective f) :
    Function.Injective (encodeList f) := by
  intro a
  induction a with
  | nil =>
    intro b h
    cases b with
    | nil => rfl
    | cons bh bt => exact absurd h.symm (Nat.succ_ne_zero _)
  | cons ah at' ih =>
    intro b h
    cases b with
    | nil => exact absurd h (Nat.succ_ne_zero _)
    | cons bh bt =>
      simp only [encodeList, Nat.succ.injEq, Nat.pair_eq_pair] at h
      exact congr (congrArg _ (hf h.1)) (ih h.2)

/--
instance : HasID Int64 where
  id x := Equiv.intEquivNat x.val
  inj := by
    intro a b h
    exact Subtype.ext (Equiv.intEquivNat.injective h)

instance : HasID Interval where
  id i := Nat.pair (HasID.id i.left) (HasID.id i.right)
  inj := by
    intro a b h
    simp only [Nat.pair_eq_pair] at h
    cases a
    cases b
    simp only [Interval.mk.injEq]
    exact ⟨HasID.inj h.1, HasID.inj h.2⟩

instance : HasID Domain where
  id d := encodeList HasID.id d.intervals
  inj := by
    intro a b h
    cases a
    cases b
    simp only [Domain.mk.injEq]
    exact encodeList_inj HasID.inj h

instance : HasID NonemptyDomain where
  id d := HasID.id d.domain
  inj := by
    intro a b h
    cases a
    cases b
    simp only [NonemptyDomain.mk.injEq]
    exact HasID.inj h
-/

structure IntVar where
  label : Option String := none
  domain : NonemptyDomain
deriving DecidableEq

def String.encodeNat (s : String) : ℕ :=
  encodeList Char.toNat s.toList

theorem String.encodeNat_inj : Function.Injective String.encodeNat := by
  intro s₁ s₂ h
  apply String.toList_injective
  exact encodeList_inj (fun _ _ h => Char.toNat_inj.mp h) h

instance : HasID IntVar where
  id x := Nat.pair (encodeOption String.encodeNat x.label) (HasID.id x.domain)
  inj := by
    intro a b h
    simp only [Nat.pair_eq_pair] at h
    cases a
    cases b
    simp only [IntVar.mk.injEq]
    exact ⟨encodeOption_inj String.encodeNat_inj h.1, HasID.inj h.2⟩

end CpsatSolver
