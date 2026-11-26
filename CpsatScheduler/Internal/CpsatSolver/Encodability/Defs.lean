module

public import CpsatScheduler.Internal.CpsatSolver.Defs
public import Mathlib.Data.Nat.Notation

public section

namespace CpsatSolver

abbrev ReprType := List ℕ

class HasRepr (α : Type) where
  toRepr : α → ReprType
  toRepr_inj : Function.Injective toRepr

instance : HasRepr String where
  toRepr a := a.toList.map Char.toNat
  toRepr_inj := by
    unfold Function.Injective
    intro a b eq
    simp only at eq
    -- prove that toNat is injective
    have toNat_inj := fun (x y : Char) =>
      (Char.toNat_inj (c := x) (d := y)).mp
    -- prove that fn that applies injective fn on every element of a list is injective
    have map_inj := List.map_inj_right (α := Char) (β := ℕ)
      (l := a.toList) (l' := b.toList)
      toNat_inj
    -- prove that String.toList is injective
    have toList_inj := String.toList_inj (s₁ := a) (s₂ := b)
    -- chain them together
    have toList_eq_toList := map_inj.mp eq
    exact toList_inj.mp toList_eq_toList

instance : HasRepr Int64 where
  toRepr i := [
    if i.val ≥ 0 then 1 else 0,
    i.val.natAbs
  ]
  toRepr_inj := by
    unfold Function.Injective
    intro a b h
    simp only [List.cons.injEq, and_true] at h
    obtain ⟨bool_eq, nat_eq⟩ := h
    apply Subtype.ext
    -- recover sign agreement from the sign-bit component
    by_cases ha : (0 : ℤ) ≤ a.val <;> by_cases hb : (0 : ℤ) ≤ b.val <;>
      simp only [ha, hb, ↓reduceIte] at bool_eq <;>
      omega

instance : HasRepr Interval where
  toRepr i := HasRepr.toRepr i.left ++ HasRepr.toRepr i.right
  toRepr_inj := by
    unfold Function.Injective
    intro a b h
    have hlen : (HasRepr.toRepr a.left).length = 2 := rfl
    have hlen' : (HasRepr.toRepr b.left).length = 2 := rfl
    -- split the concatenation back into the two endpoint reprs
    have hsplit :=
      (List.append_inj h (by rw [hlen, hlen']))
    obtain ⟨hleft, hright⟩ := hsplit
    have hl := (HasRepr.toRepr_inj (α := Int64)) hleft
    have hr := (HasRepr.toRepr_inj (α := Int64)) hright
    cases a
    cases b
    simp only at hl hr
    subst hl
    subst hr
    rfl

def encodeChunks : List ReprType → ReprType
  | [] => []
  | c :: rest => c.length :: (c ++ encodeChunks rest)

theorem encodeChunks_inj : Function.Injective encodeChunks := by
  intro a
  induction a with
  | nil =>
    intro b h
    cases b with
    | nil => rfl
    | cons c rest =>
      -- `encodeChunks [] = []` but a non-empty list encodes to a cons
      simp only [encodeChunks] at h
      exact (List.cons_ne_nil _ _ h.symm).elim
  | cons ca resta ih =>
    intro b h
    cases b with
    | nil =>
      simp only [encodeChunks] at h
      exact (List.cons_ne_nil _ _ h).elim
    | cons cb restb =>
      simp only [encodeChunks, List.cons.injEq] at h
      obtain ⟨hlen, hbody⟩ := h
      -- the leading length entry pins the split point of the two bodies
      have hsplit := List.append_inj hbody hlen
      obtain ⟨hhead, htail⟩ := hsplit
      rw [hhead, ih htail]

instance : HasRepr Domain where
  -- flatten the per-interval reprs with length prefixes; the `pairwise`
  -- field is a proof, so equal interval lists give equal domains
  toRepr d := encodeChunks (d.intervals.map HasRepr.toRepr)
  toRepr_inj := by
    intro a b h
    simp only at h
    have hmap := encodeChunks_inj h
    have hlists :=
      (List.map_injective_iff.mpr (HasRepr.toRepr_inj (α := Interval))) hmap
    cases a
    cases b
    simp only at hlists
    subst hlists
    rfl

instance : HasRepr NonemptyDomain where
  -- reuse the `Domain` repr; the `nonempty` field is a proof
  toRepr d := HasRepr.toRepr d.domain
  toRepr_inj := by
    intro a b h
    simp only at h
    have hdom := (HasRepr.toRepr_inj (α := Domain)) h
    cases a
    cases b
    simp only at hdom
    subst hdom
    rfl

end CpsatSolver

