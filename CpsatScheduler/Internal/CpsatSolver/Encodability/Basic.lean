module

public import CpsatScheduler.Internal.CpsatSolver.Encodability.Defs

public section

namespace CpsatSolver

instance : HasRepr ℤ where
  toRepr n := [if n ≥ 0 then 1 else 0, n.natAbs]
  toRepr_inj := by
    intro a b h
    simp only [List.cons.injEq, and_true] at h
    obtain ⟨sign_eq, abs_eq⟩ := h
    by_cases ha : (0 : ℤ) ≤ a <;> by_cases hb : (0 : ℤ) ≤ b <;>
      simp only [ha, hb, ↓reduceIte] at sign_eq <;>
      omega

instance {α : Type} {p : α → Prop} [HasRepr α] : HasRepr (Subtype p) where
  -- a subtype is identified by its underlying value; `Subtype.val` is injective
  toRepr x := HasRepr.toRepr x.val
  toRepr_inj := by
    intro a b h
    simp only at h
    exact Subtype.ext ((HasRepr.toRepr_inj (α := α)) h)

instance : HasRepr Char where
  toRepr c := [c.toNat]
  toRepr_inj := by
    intro a b h
    simp only [List.cons.injEq, and_true] at h
    exact (Char.toNat_inj (c := a) (d := b)).mp h

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

/-! ## Generic combinators

All compound encodings stay length-tagged (via `encodeChunks` or a single
leading element) so that composing variable-length field reprs is still
injective. -/

instance {α β : Type} [HasRepr α] [HasRepr β] : HasRepr (α × β) where
  toRepr p := encodeChunks [HasRepr.toRepr p.1, HasRepr.toRepr p.2]
  toRepr_inj := by
    intro a b h
    simp only at h
    have hchunks := encodeChunks_inj h
    simp only [List.cons.injEq, and_true] at hchunks
    obtain ⟨h1, h2⟩ := hchunks
    have ha := (HasRepr.toRepr_inj (α := α)) h1
    have hb := (HasRepr.toRepr_inj (α := β)) h2
    cases a
    cases b
    simp only at ha hb
    subst ha
    subst hb
    rfl

instance {α : Type} [HasRepr α] : HasRepr (Option α) where
  -- `none ↦ [0]`, `some a ↦ 1 :: toRepr a`; the leading tag keeps them apart
  toRepr
    | none => [0]
    | some a => 1 :: HasRepr.toRepr a
  toRepr_inj := by
    intro a b h
    cases a with
    | none =>
      cases b with
      | none => rfl
      | some bb =>
        simp only [List.cons.injEq] at h
        exact absurd h.1 (by decide)
    | some aa =>
      cases b with
      | none =>
        simp only [List.cons.injEq] at h
        exact absurd h.1 (by decide)
      | some bb =>
        simp only [List.cons.injEq, true_and] at h
        exact congrArg some ((HasRepr.toRepr_inj (α := α)) h)

instance {α : Type} [HasRepr α] : HasRepr (List α) where
  toRepr l := encodeChunks (l.map HasRepr.toRepr)
  toRepr_inj := by
    intro a b h
    simp only at h
    have hmap := encodeChunks_inj h
    exact (List.map_injective_iff.mpr (HasRepr.toRepr_inj (α := α))) hmap

instance {α : Type} [HasRepr α] : HasRepr (Array α) where
  -- encode via the underlying list; `Array.toList` is injective
  toRepr a := HasRepr.toRepr a.toList
  toRepr_inj := by
    intro a b h
    simp only at h
    have hlist := (HasRepr.toRepr_inj (α := List α)) h
    exact Array.toList_inj.mp hlist

instance {α : Type} {n : ℕ} [HasRepr α] : HasRepr (Vector α n) where
  -- encode via the underlying array; `n` is fixed, `Vector.toArray` injective
  toRepr v := HasRepr.toRepr v.toArray
  toRepr_inj := by
    intro a b h
    simp only at h
    have harr := (HasRepr.toRepr_inj (α := Array α)) h
    exact Vector.toArray_inj.mp harr

instance {β : ℕ → Type} [∀ n, HasRepr (β n)] : HasRepr (Σ n : ℕ, β n) where
  -- leading element is the index `n`; the rest is the payload repr
  toRepr s := s.1 :: HasRepr.toRepr s.2
  toRepr_inj := by
    intro a b h
    obtain ⟨na, xa⟩ := a
    obtain ⟨nb, xb⟩ := b
    simp only [List.cons.injEq] at h
    obtain ⟨hn, hx⟩ := h
    subst hn
    have hxx := (HasRepr.toRepr_inj (α := β na)) hx
    subst hxx
    rfl

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

instance : HasRepr Unit.Scale where
  -- `Scale` is `@[ext]` with proof-irrelevant `pos`/`nonoverflow`; its value
  -- field determines identity
  toRepr s := HasRepr.toRepr s.val
  toRepr_inj := by
    intro a b h
    simp only at h
    have hval := (HasRepr.toRepr_inj (α := ℤ)) h
    exact Unit.Scale.ext hval

end CpsatSolver
