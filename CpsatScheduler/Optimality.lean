import CpsatScheduler.Defs

namespace CpsatScheduler

theorem true_le_encoded_add_err {t e ε : ℚ} (h : |t - e| ≤ ε) : t ≤ e + ε := by
  have := (abs_le.mp h).2
  linarith

theorem encoded_le_true_add_err {t e ε : ℚ} (h : |t - e| ≤ ε) : e ≤ t + ε := by
  have := (abs_le.mp h).1
  linarith

theorem sum_true_le_sum_enc_add_err (pairs : List (ℚ × ℚ × ℚ))
    (hclose : ∀ p ∈ pairs, |p.1 - p.2.1| ≤ p.2.2) :
    (pairs.map (·.1)).sum ≤ (pairs.map (·.2.1)).sum + (pairs.map (·.2.2)).sum := by
  induction pairs with
  | nil => simp
  | cons p rest ih =>
    rcases p with ⟨t, e, ε⟩
    have hrest : ∀ q ∈ rest, |q.1 - q.2.1| ≤ q.2.2 :=
      fun q hq => hclose q (List.mem_cons.mpr (Or.inr hq))
    have ht := true_le_encoded_add_err
      (hclose ⟨t, e, ε⟩ List.mem_cons_self)
    have ih' := ih hrest
    simp [List.sum_cons] at ih' ⊢
    linarith

theorem sum_enc_le_sum_true_add_err (pairs : List (ℚ × ℚ × ℚ))
    (hclose : ∀ p ∈ pairs, |p.1 - p.2.1| ≤ p.2.2) :
    (pairs.map (·.2.1)).sum ≤ (pairs.map (·.1)).sum + (pairs.map (·.2.2)).sum := by
  induction pairs with
  | nil => simp
  | cons p rest ih =>
    rcases p with ⟨t, e, ε⟩
    have hrest : ∀ q ∈ rest, |q.1 - q.2.1| ≤ q.2.2 :=
      fun q hq => hclose q (List.mem_cons.mpr (Or.inr hq))
    have ht := encoded_le_true_add_err
      (hclose ⟨t, e, ε⟩ List.mem_cons_self)
    have ih' := ih hrest
    simp [List.sum_cons] at ih' ⊢
    linarith

/-- If an encoded-cost vector is optimal among encoded alternatives for the same
tasks, the corresponding true total is at most the true alternative plus twice
the summed error bounds. No claim is made for merely feasible responses. -/
theorem encodedOptimal_trueCost_le
    (chosen alt : List (ℚ × ℚ × ℚ))
    (hclose₀ : ∀ p ∈ chosen, |p.1 - p.2.1| ≤ p.2.2)
    (hclose₁ : ∀ p ∈ alt, |p.1 - p.2.1| ≤ p.2.2)
    (herr : (chosen.map (·.2.2)).sum = (alt.map (·.2.2)).sum)
    (hopt : (chosen.map (·.2.1)).sum ≤ (alt.map (·.2.1)).sum) :
    (chosen.map (·.1)).sum ≤ (alt.map (·.1)).sum + 2 * (chosen.map (·.2.2)).sum := by
  have hch := sum_true_le_sum_enc_add_err chosen hclose₀
  have halt := sum_enc_le_sum_true_add_err alt hclose₁
  linarith

end CpsatScheduler

