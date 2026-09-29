import CpsatScheduler.Defs
import CpsatScheduler.Task
import CpsatScheduler.PERT

namespace CpsatScheduler

open CpsatSolver

theorem NonemptyDomain.hull_left_mem (d : CpsatSolver.NonemptyDomain) :
    (d.hull.left : ℤ) ∈ d.domain := by
  refine ⟨d.domain.intervals.head d.nonempty, List.head_mem d.nonempty, ?_⟩
  exact ⟨le_rfl, (d.domain.intervals.head d.nonempty).left_le_right⟩

theorem NonemptyDomain.hull_right_mem (d : CpsatSolver.NonemptyDomain) :
    (d.hull.right : ℤ) ∈ d.domain := by
  refine ⟨d.domain.intervals.getLast d.nonempty, List.getLast_mem d.nonempty, ?_⟩
  exact ⟨(d.domain.intervals.getLast d.nonempty).left_le_right, le_rfl⟩

/-- For any task start endpoint `k` in its start domain, `k + 1` is a valid
`Int64` (derived from the horizon-fit invariants, no per-task `decide`). -/
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
  · have : CpsatSolver.Int64.min ≤ (0 : ℤ) := by decide
    linarith [hk0]
  · exact le_trans hk1_le hk1u.2

/-- Generic discharge of the `prerequisite` nonoverflow obligation for a task's
start variable (as the `pred`). `startVar.domain = task.startDomain`. -/
theorem Task.prereq_nonoverflow (t : Task S) (v : CpsatSolver.IntVar)
    (hv : v.domain = t.startDomain) :
    CpsatSolver.Int64.Nonoverflow ((v.domain.hull.left : ℤ) + 1) ∧
    CpsatSolver.Int64.Nonoverflow ((v.domain.hull.right : ℤ) + 1) := by
  rw [hv]
  exact ⟨Task.succ_nonoverflow_of_mem t (NonemptyDomain.hull_left_mem t.startDomain),
    Task.succ_nonoverflow_of_mem t (NonemptyDomain.hull_right_mem t.startDomain)⟩

/-- Replace a task's id. Every proof field is id-independent, so this needs no
new proof. -/
@[simp] def Task.setId (t : Task S) (id : TaskId) : Task S :=
  { t with id := id }

@[simp] theorem Task.setId_startDomain (t : Task S) (id : TaskId) :
    (t.setId id).startDomain = t.startDomain := rfl

/-- Scaled-endpoint nonoverflow for the containment ("within") constraint.

Given a task whose start endpoint `k` lies in its start domain, and a scale
`ratio` with `0 ≤ ratio ≤ unit`, both `k * ratio` and `(k + 1) * ratio` are valid
`Int64` — because they are bounded above by `k * unit` and `(k + 1) * unit`, which
`Task.bucketsFitHorizon` already keeps within range. No `decide` on the (opaque)
solver variable is needed. -/
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
  have hmin : CpsatSolver.Int64.min ≤ (0 : ℤ) := by decide
  have hkr0 : (0 : ℤ) ≤ k * ratio := by positivity
  have hk1r0 : (0 : ℤ) ≤ (k + 1) * ratio := by positivity
  refine ⟨⟨le_trans hmin hkr0, ?_⟩, ⟨le_trans hmin hk1r0, ?_⟩⟩
  · have : k * ratio ≤ k * u := by nlinarith [hk0, hr0, hru]
    exact le_trans this hku.2
  · have : (k + 1) * ratio ≤ (k + 1) * u := by nlinarith [hk0, hr0, hru]
    exact le_trans this hk1u.2

/-- `min`/`max` of two `Int64`-safe integers stay `Int64`-safe. -/
theorem Int64.nonoverflow_min {a b : ℤ}
    (ha : CpsatSolver.Int64.Nonoverflow a) (hb : CpsatSolver.Int64.Nonoverflow b) :
    CpsatSolver.Int64.Nonoverflow (min a b) :=
  ⟨le_min ha.1 hb.1, le_trans (min_le_left a b) ha.2⟩

theorem Int64.nonoverflow_max {a b : ℤ}
    (ha : CpsatSolver.Int64.Nonoverflow a) (hb : CpsatSolver.Int64.Nonoverflow b) :
    CpsatSolver.Int64.Nonoverflow (max a b) :=
  ⟨le_trans ha.1 (le_max_left a b), max_le ha.2 hb.2⟩

/-- If both endpoints of an interval stay `Int64`-safe when multiplied by a
nonnegative `ratio`, so do its `mulLower`/`mulUpper` against `ofValue ratio`. -/
theorem Interval.scaled_nonoverflow (i : CpsatSolver.Interval) (ratio : CpsatSolver.Int64)
    (hL : CpsatSolver.Int64.Nonoverflow ((i.left : ℤ) * ratio))
    (hR : CpsatSolver.Int64.Nonoverflow ((i.right : ℤ) * ratio)) :
    CpsatSolver.Int64.Nonoverflow (i.mulLower (CpsatSolver.Interval.ofValue ratio)) ∧
    CpsatSolver.Int64.Nonoverflow (i.mulUpper (CpsatSolver.Interval.ofValue ratio)) := by
  refine ⟨?_, ?_⟩
  · unfold CpsatSolver.Interval.mulLower
    simp only [CpsatSolver.Interval.ofValue, min_self]
    exact Int64.nonoverflow_min hL hR
  · unfold CpsatSolver.Interval.mulUpper
    simp only [CpsatSolver.Interval.ofValue, max_self]
    exact Int64.nonoverflow_max hL hR

theorem Task.within_mul_group (t : Task S) (v : CpsatSolver.IntVar)
    (ratio : CpsatSolver.Int64)
    (hv : v.domain = t.startDomain)
    (hr0 : 0 ≤ (ratio : ℤ)) (hru : (ratio : ℤ) ≤ (t.unit.val.val : ℤ)) :
    CpsatSolver.Int64.Nonoverflow
        (v.domain.hull.mulLower (CpsatSolver.Interval.ofValue ratio)) ∧
    CpsatSolver.Int64.Nonoverflow
        (v.domain.hull.mulUpper (CpsatSolver.Interval.ofValue ratio)) := by
  have hLmem : (v.domain.hull.left : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_left_mem t.startDomain
  have hRmem : (v.domain.hull.right : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_right_mem t.startDomain
  exact Interval.scaled_nonoverflow v.domain.hull ratio
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hLmem hr0 hru).1
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hRmem hr0 hru).1

/-- The `mul₂` obligation: the `parent + 1` interval scaled by `ratio` stays
`Int64`-safe. Takes the `add₁` witness so the shifted interval is well-formed;
proof irrelevance makes the choice of witness immaterial to the value. -/
theorem Task.within_succ_mul_group (t : Task S) (v : CpsatSolver.IntVar)
    (ratio : CpsatSolver.Int64)
    (hv : v.domain = t.startDomain)
    (hr0 : 0 ≤ (ratio : ℤ)) (hru : (ratio : ℤ) ≤ (t.unit.val.val : ℤ))
    (add₁ :
      CpsatSolver.Int64.Nonoverflow ((v.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((v.domain.hull.right : ℤ) + 1)) :
    CpsatSolver.Int64.Nonoverflow
        ((v.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁).mulLower
          (CpsatSolver.Interval.ofValue ratio)) ∧
    CpsatSolver.Int64.Nonoverflow
        ((v.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁).mulUpper
          (CpsatSolver.Interval.ofValue ratio)) := by
  have hLmem : (v.domain.hull.left : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_left_mem t.startDomain
  have hRmem : (v.domain.hull.right : ℤ) ∈ t.startDomain.domain := by
    rw [hv]; exact NonemptyDomain.hull_right_mem t.startDomain
  have hLsucc : CpsatSolver.Int64.Nonoverflow (((v.domain.hull.left : ℤ) + 1) * ratio) :=
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hLmem hr0 hru).2
  have hRsucc : CpsatSolver.Int64.Nonoverflow (((v.domain.hull.right : ℤ) + 1) * ratio) :=
    (Task.scaled_nonoverflow_of_mem t (ratio : ℤ) hRmem hr0 hru).2
  exact Interval.scaled_nonoverflow
    (v.domain.hull.add (CpsatSolver.Interval.ofValue (CpsatSolver.Int64.of 1)) add₁) ratio
    hLsucc hRsucc

end CpsatScheduler

namespace PERT

open CpsatScheduler

/-- Retarget a task config onto a fresh id. `DemandEstimate.Valid` only reads
`task.unit`, which `Task.setId` preserves, so the validity proof transports by
`rfl`. -/
@[simp] def TaskConfig.setId (cfg : PERT.TaskConfig S) (id : CpsatScheduler.TaskId) :
    PERT.TaskConfig S :=
  { cfg with
    task := cfg.task.setId id
    demand :=
      { opt := cfg.demand.opt
        exp := cfg.demand.exp
        pes := cfg.demand.pes
        valid := cfg.demand.valid } }

end PERT

