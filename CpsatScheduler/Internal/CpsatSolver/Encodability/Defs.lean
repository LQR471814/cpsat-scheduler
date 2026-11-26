module

public import CpsatScheduler.Internal.CpsatSolver.Defs
public import Mathlib.Data.Nat.Notation

public section

namespace CpsatSolver

abbrev ReprType := List ℕ

class HasRepr (α : Type) where
  toRepr : α → ReprType
  toRepr_inj : Function.Injective toRepr

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

end CpsatSolver
