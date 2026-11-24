module

public import Mathlib.Data.Finset.Sort

public section

def Finset.sortByKey
  {α β : Type} [DecidableEq α] [LinearOrder β]
  (set : Finset α)
  (key : set → β)
  (key_injective : Function.Injective key) :
    List α :=
  letI : LinearOrder set := LinearOrder.lift' key key_injective
  set.attach.sort

theorem Finset.mem_sortByKey
  {α β : Type} [DecidableEq α] [LinearOrder β]
  {set : Finset α}
  {key : set → β}
  {key_injective : Function.Injective key}
  {a : α} :
    a ∈ set ↔ a ∈ Finset.sortByKey set key key_injective := by
  unfold Finset.sortByKey
  unfold Finset.attach
  unfold Finset.sort
  simp only [List.pure_def, List.bind_eq_flatMap, List.flatMap_subtype, List.flatMap_singleton',
    List.mem_unattach, Multiset.mem_sort]
  exact {
    mp := fun h => by
      apply (Exists.intro h)
      apply Finset.mem_attach
    mpr := fun h => by
      let ⟨h1, _⟩ := h
      exact h1
  }

