import CpsatScheduler.Defs
import CpsatScheduler.Task
import CpsatScheduler.PERT

namespace CpsatScheduler

open CpsatSolver

theorem Task.succ_nonoverflow_of_mem (t : Task S) {k : ℤ}
    (hk : k ∈ t.startDomain.domain) :
    CpsatSolver.Int64.Nonoverflow (k + 1) := by
  obtain ⟨hbegin, _hend, _, hk1u⟩ := t.bucketsFitHorizon k hk
  let u : ℤ := t.unit.val.val
  have hu1 : (1 : ℤ) ≤ u := by
    change (1 : ℤ) ≤ ((t.unit.val.val : ℕ) : ℤ)
    exact_mod_cast t.unit.val.pos
  have hu0 : (0 : ℤ) < u := lt_of_lt_of_le zero_lt_one hu1
  have hbegin0 : (0 : ℤ) ≤ (S.horizon.begin : ℤ) := Int.natCast_nonneg _
  have hk0 : (0 : ℤ) ≤ k := by nlinarith [hbegin, hbegin0, hu0]
  have hk1_le : k + 1 ≤ (k + 1) * u := by nlinarith [hu1, hk0]
  refine ⟨?_, ?_⟩
  · have : CpsatSolver.Int64.min ≤ (0 : ℤ) := by native_decide
    linarith [hk0]
  · exact le_trans hk1_le hk1u.2

theorem Task.prereq_nonoverflow (t : Task S) (v : CpsatSolver.IntVar)
    (hv : v.domain = t.startDomain) :
    CpsatSolver.Int64.Nonoverflow ((v.domainHull.left : ℤ) + 1) ∧
    CpsatSolver.Int64.Nonoverflow ((v.domainHull.right : ℤ) + 1) := by
  rw [hv]
  exact ⟨Task.succ_nonoverflow_of_mem t (NonemptyDomain.hull_left_mem t.startDomain),
    Task.succ_nonoverflow_of_mem t (NonemptyDomain.hull_right_mem t.startDomain)⟩

theorem Task.scaled_nonoverflow_of_mem (t : Task S) {k : ℤ} (ratio : ℤ)
    (hk : k ∈ t.startDomain.domain)
    (hr0 : 0 ≤ ratio) (hru : ratio ≤ (t.unit.val.val : ℤ)) :
    CpsatSolver.Int64.Nonoverflow (k * ratio) ∧
    CpsatSolver.Int64.Nonoverflow ((k + 1) * ratio) := by
  obtain ⟨hbegin, _hend, hku, hk1u⟩ := t.bucketsFitHorizon k hk
  let u : ℤ := t.unit.val.val
  have hu1 : (1 : ℤ) ≤ u := by
    change (1 : ℤ) ≤ ((t.unit.val.val : ℕ) : ℤ)
    exact_mod_cast t.unit.val.pos
  have hu0 : (0 : ℤ) < u := lt_of_lt_of_le zero_lt_one hu1
  have hbegin0 : (0 : ℤ) ≤ (S.horizon.begin : ℤ) := Int.natCast_nonneg _
  have hk0 : (0 : ℤ) ≤ k := by nlinarith [hbegin, hbegin0, hu0]
  have hmin : CpsatSolver.Int64.min ≤ (0 : ℤ) := by native_decide
  have hkr0 : (0 : ℤ) ≤ k * ratio := by positivity
  have hk1r0 : (0 : ℤ) ≤ (k + 1) * ratio := by positivity
  refine ⟨⟨le_trans hmin hkr0, ?_⟩, ⟨le_trans hmin hk1r0, ?_⟩⟩
  · have : k * ratio ≤ k * u := by nlinarith [hk0, hr0, hru]
    exact le_trans this hku.2
  · have : (k + 1) * ratio ≤ (k + 1) * u := by nlinarith [hk0, hr0, hru]
    exact le_trans this hk1u.2

theorem Task.within_mul_group (t : Task S) (v : CpsatSolver.IntVar)
    (ratio : CpsatSolver.Int64)
    (hv : v.domain = t.startDomain)
    (hr0 : 0 ≤ (ratio : ℤ)) (hru : (ratio : ℤ) ≤ (t.unit.val.val : ℤ)) :
    CpsatSolver.Int64.Nonoverflow
        (v.domainHull.mulLower (CpsatSolver.Interval.ofValue ratio)) ∧
    CpsatSolver.Int64.Nonoverflow
        (v.domainHull.mulUpper (CpsatSolver.Interval.ofValue ratio)) := by
  have hLmem : (v.domainHull.left : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_left_mem t.startDomain
  have hRmem : (v.domainHull.right : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_right_mem t.startDomain
  exact Interval.scaled_nonoverflow v.domainHull ratio
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hLmem hr0 hru).1
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hRmem hr0 hru).1

theorem Task.within_succ_mul_group (t : Task S) (v : CpsatSolver.IntVar)
    (ratio : CpsatSolver.Int64)
    (hv : v.domain = t.startDomain)
    (hr0 : 0 ≤ (ratio : ℤ)) (hru : (ratio : ℤ) ≤ (t.unit.val.val : ℤ))
    (add₁ :
      CpsatSolver.Int64.Nonoverflow ((v.domainHull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((v.domainHull.right : ℤ) + 1)) :
    CpsatSolver.Int64.Nonoverflow
        ((v.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁).mulLower
          (CpsatSolver.Interval.ofValue ratio)) ∧
    CpsatSolver.Int64.Nonoverflow
        ((v.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁).mulUpper
          (CpsatSolver.Interval.ofValue ratio)) := by
  have hLmem : (v.domainHull.left : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_left_mem t.startDomain
  have hRmem : (v.domainHull.right : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_right_mem t.startDomain
  have hLsucc : CpsatSolver.Int64.Nonoverflow (((v.domainHull.left : ℤ) + 1) * ratio) :=
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hLmem hr0 hru).2
  have hRsucc : CpsatSolver.Int64.Nonoverflow (((v.domainHull.right : ℤ) + 1) * ratio) :=
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hRmem hr0 hru).2
  exact Interval.scaled_nonoverflow
    (v.domainHull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁) ratio
    hLsucc hRsucc

end CpsatScheduler

