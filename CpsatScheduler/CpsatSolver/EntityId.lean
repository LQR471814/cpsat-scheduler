import CpsatScheduler.CpsatSolver.Defs

namespace CpsatSolver

instance : DecidableLT EntityId :=
  fun a b => inferInstanceAs (Decidable (a.val < b.val))

private theorem char_ge_zero_or_le_nine (c : Char) : '0' ≤ c ∨ c ≤ '9' := by
  by_cases h : '0' ≤ c
  · exact Or.inl h
  · exact Or.inr (le_of_lt (lt_of_lt_of_le (lt_of_not_ge h) (by decide)))

theorem EntityId.validIdent_e_suffix (s : String) :
    Python.ValidIdent ("e_" ++ s) := by
  intro i
  exact Or.inr (Or.inr (Or.inr fun _ => char_ge_zero_or_le_nine _))

theorem EntityId.not_reserved_e_suffix (s : String) :
    ¬ ("e_" ++ s) ∈ Python.ReservedKeywords := by
  have hkw : ∀ kw ∈ Python.ReservedKeywords, '_' ∉ kw.toList := by
    decide
  intro hmem
  have : '_' ∈ ("e_" ++ s).toList := by
    simp [String.toList_append]
  exact (hkw _ hmem) this

theorem EntityId.toPythonName_proof (n : Nat) :
    Python.ValidName.Proof ("e_" ++ toString n) :=
  ⟨EntityId.not_reserved_e_suffix (toString n),
    EntityId.validIdent_e_suffix (toString n)⟩

end CpsatSolver
