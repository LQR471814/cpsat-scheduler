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
      (hlr := by exact Int.natCast_nonneg task.unit.val)))

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

end CpsatScheduler

