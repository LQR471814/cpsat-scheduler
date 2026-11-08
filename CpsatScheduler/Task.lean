import CpsatScheduler.Defs
import CpsatSolver.Domain.Defs

namespace CpsatScheduler

open CpsatSolver

def Task.unit (task : Task S) :=
  task.start.scale

def Task.demandDomain (task : Task S) :=
  (NonemptyDomain.interval
    (CpsatSolver.Interval.of 0 task.unit.val
      (hl := by native_decide)
      (hr := task.unit.val.nonoverflow)
      (hlr := Int.le_of_lt task.unit.val.pos)))

def Task.MemDemandInterval (task : Task S) (x : ℤ) : Prop :=
  have h : 0 < (Task.demandDomain task).domain.intervals.length :=
    (Task.demandDomain task).domain.interval_size rfl
  ((Task.demandDomain task).domain.intervals[0]'h).mem x

instance : Decidable (Task.MemDemandInterval T x) := by
  dsimp [
    Task.MemDemandInterval,
    Task.demandDomain,
    NonemptyDomain.interval,
    Domain.interval,
    GetElem.getElem,
    Interval.mem
  ]
  if h : 0 ≤ x ∧ x ≤ T.unit.val then
    exact Decidable.isTrue h
  else
    exact Decidable.isFalse h

def Task.MemDemand (task : Task S) (x : ℤ) : Prop :=
  x ∈ (Task.demandDomain task).domain

theorem Task.mem_demand_domain (task : Task S) (x : ℤ)
  : Task.MemDemandInterval task x ↔ Task.MemDemand task x
  := by
    constructor
    · intro h
      let d := (Task.demandDomain task).domain
      change x ∈ d
      dsimp [Membership.mem]
      let w := d.intervals[0]'(d.interval_size (Eq.refl d))
      exists w
      constructor
      · exact List.mem_of_getElem (a := w) rfl
      · exact h
    · intro h
      dsimp [Task.MemDemandInterval, Task.demandDomain,
        NonemptyDomain.interval, Domain.interval, GetElem.getElem, Interval.mem]
      let d := (Task.demandDomain task).domain
      let fst_intv := d.intervals[0]'(d.interval_size (Eq.refl d))
      dsimp [Task.MemDemand, Membership.mem] at h
      cases h
      rename_i w h
      cases h
      rename_i w_mem_intervals x_mem_w
      apply List.eq_of_mem_singleton at w_mem_intervals
      rw [w_mem_intervals] at x_mem_w
      dsimp [Interval.mem] at x_mem_w
      exact x_mem_w

theorem Task.memDemand_iff (task : Task S) (x : ℤ) :
    Task.MemDemand task x ↔ 0 ≤ x ∧ x ≤ task.unit.val :=
  (Task.mem_demand_domain task x).symm

instance : Decidable (Task.MemDemand T x) :=
  if h : Task.MemDemandInterval T x then
    Decidable.isTrue ((Task.mem_demand_domain T x).mp
      h)
  else
    Decidable.isFalse (fun assump => by
      have h1 := (Task.mem_demand_domain T x).mpr assump
      exact h h1)

-- def Task.startDomainOf {us : Unit.Set} (horizon : Horizon)
--   (unit : us.elem)
--   (lo : ℤ := horizon.start)
--   (hi : ℤ := horizon.end / unit.val.val - 1)
--   (label : Option String := none)
--   (hle : lo ≤ hi := by native_decide)
--   (hbegin : (horizon.start : ℤ) ≤ lo * unit.val.val := by native_decide)
--   (hend : (hi + 1) * unit.val.val ≤ horizon.end := by native_decide) :=
--

-- def Task.ofBucketRange (TP : TaskParams)
--     (unit : TP.units.elem)
--     (kLo : ℤ := TP.horizon.start)
--     (kHi : ℤ := TP.horizon.end / unit.val.val - 1)
--     (hle : kLo ≤ kHi := by native_decide)
--     (hbegin : (TP.horizon.start : ℤ) ≤ kLo * unit.val.val := by native_decide)
--     (hend : (kHi + 1) * unit.val.val ≤ TP.horizon.end := by native_decide)
--     (label : Option String := none) :
--     Task TP :=
--   let u : ℤ := unit.val.val
--   -- Unit is a positive natural, so `u ≥ 1`.
--   have hu1 : (1 : ℤ) ≤ u := by
--     change (1 : ℤ) ≤ ((unit.val.val : ℕ) : ℤ)
--     have hpos : 0 < unit.val.val := unit.val.pos
--     exact_mod_cast hpos
--   have hu0 : (0 : ℤ) < u := lt_of_lt_of_le zero_lt_one hu1
--   have hbegin0 : (0 : ℤ) ≤ (TP.horizon.start : ℤ) := Int.natCast_nonneg _
--   -- `kLo * u ≥ begin ≥ 0` with `u > 0` forces `kLo ≥ 0`.
--   have hkLo0 : (0 : ℤ) ≤ kLo := by nlinarith [hbegin, hbegin0]
--   have hkHi0 : (0 : ℤ) ≤ kHi := le_trans hkLo0 hle
--   -- Horizon end is within Int64.
--   have hendMax : (TP.horizon.end : ℤ) ≤ CpsatSolver.Int64.max :=
--     TP.horizon.end.prop.2
--   have hminNonpos : CpsatSolver.Int64.min ≤ (0 : ℤ) := by native_decide
--   -- Upper anchor: everything in range is `≤ (kHi + 1) * u ≤ end_ ≤ max`.
--   have hkHiu_le_end : kHi * u ≤ (TP.horizon.end : ℤ) := by nlinarith [hend, hu0]
--   -- Interval endpoints are within Int64.
--   have hkLoSafe : CpsatSolver.Int64.Nonoverflow kLo := by
--     refine ⟨le_trans hminNonpos hkLo0, ?_⟩
--     have : kLo ≤ kLo * u := by nlinarith [hu1, hkLo0]
--     have hchain : kLo * u ≤ (TP.horizon.end : ℤ) := by nlinarith [hle, hu0, hkHiu_le_end]
--     linarith [le_trans this hchain, hendMax]
--   have hkHiSafe : CpsatSolver.Int64.Nonoverflow kHi := by
--     refine ⟨le_trans hminNonpos hkHi0, ?_⟩
--     have : kHi ≤ kHi * u := by nlinarith [hu1, hkHi0]
--     linarith [le_trans this hkHiu_le_end, hendMax]
--   {
--     label := label
--     unit := unit
--     startDomain :=
--       CpsatSolver.NonemptyDomain.interval
--         (CpsatSolver.Interval.of kLo kHi
--           hkLoSafe hkHiSafe hle)
--     bucketsFitHorizon := by
--       intro k hk
--       -- Membership reduces to `kLo ≤ k ≤ kHi`.
--       rw [CpsatSolver.NonemptyDomain.interval,
--         CpsatSolver.Domain.mem_interval] at hk
--       obtain ⟨hklo, hkhi⟩ := hk
--       -- endpoints of `Interval.of kLo kHi` are `kLo`, `kHi`.
--       have hklo' : kLo ≤ k := hklo
--       have hkhi' : k ≤ kHi := hkhi
--       have hk0 : (0 : ℤ) ≤ k := le_trans hkLo0 hklo'
--       -- Core arithmetic bounds.
--       have hbeginle : (scales.horizon.start : ℤ) ≤ k * u := by
--         have : kLo * u ≤ k * u := by nlinarith [hklo', hu0]
--         linarith [hbegin, this]
--       have hendle : (k + 1) * u ≤ (scales.horizon.end : ℤ) := by
--         have : (k + 1) * u ≤ (kHi + 1) * u := by nlinarith [hkhi', hu0]
--         linarith [hend, this]
--       have hku0 : (0 : ℤ) ≤ k * u := by nlinarith [hk0, hu0]
--       have hk1u0 : (0 : ℤ) ≤ (k + 1) * u := by nlinarith [hk0, hu0]
--       have hku_le_end : k * u ≤ (scales.horizon.end : ℤ) := by
--         have : k * u ≤ (k + 1) * u := by nlinarith [hu0]
--         linarith [hendle, this]
--       refine ⟨hbeginle, hendle, ?_, ?_⟩
--       · exact ⟨le_trans hminNonpos hku0, le_trans hku_le_end hendMax⟩
--       · exact ⟨le_trans hminNonpos hk1u0, le_trans hendle hendMax⟩
--   }

end CpsatScheduler

