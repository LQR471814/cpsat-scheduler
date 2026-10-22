import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task

open CpsatScheduler
open CpsatSolver

namespace CpsatScheduler

structure TaskVars (S : Timescales) where
  task : Task S
  startVar : CpsatSolver.IntVar
  unit_eq : startVar.domain = task.startDomain
  costVar : CpsatSolver.IntVar
  timeDemandedVar : CpsatSolver.IntVar
  time_demanded_le_unit :
    timeDemandedVar.domain.min ≥ (0 : ℤ) ∧
    timeDemandedVar.domain.max.val ≤ task.unit.val

@[simp] def Task.demandDomain (task : Task S) :=
  (NonemptyDomain.interval
    (CpsatSolver.Interval.of 0 task.unit
      (hl := by decide)
      (hr := task.unit.val.nonoverflow)
      (hlr := by exact Int.natCast_nonneg task.unit.val)))

def Task.MemDemandInterval (task : Task S) (x : ℤ) : Prop :=
  (Task.demandDomain task).domain.intervals[0].mem x

instance : Decidable (Task.MemDemandInterval T x) :=
  if h : 0 ≤ x ∧ x ≤ T.unit.val then
    Decidable.isTrue (by
      dsimp [
        Task.MemDemandInterval,
        GetElem.getElem,
        Interval.mem
      ]
      exact h)
  else
    Decidable.isFalse (by
      dsimp [
        Task.MemDemandInterval,
        GetElem.getElem,
        Interval.mem
      ]
      exact h)

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
      dsimp [Task.MemDemandInterval, GetElem.getElem, Interval.mem]
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

def TaskVars.of (t : Task S) (costDomain : NonemptyDomain)
    (startVarID costVarID timeDemandedVarID : EntityID) :=
  let labelFor (suffix : String) : Option String :=
    t.label.map (s!"{·}_{suffix}")
  let vars : TaskVars S := {
    task := t
    startVar := {
      id := startVarID
      domain := t.startDomain
      label := labelFor "start"
    }
    costVar := {
      id := costVarID
      domain := costDomain
      label := labelFor "cost"
    }
    timeDemandedVar := {
      id := timeDemandedVarID
      domain := Task.demandDomain t
      label := labelFor "demand"
    }
    unit_eq := rfl
    time_demanded_le_unit := by simp
  }
  vars

end CpsatScheduler
