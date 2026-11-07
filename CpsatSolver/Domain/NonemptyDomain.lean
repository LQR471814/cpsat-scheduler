import CpsatSolver.Domain.Domain

namespace CpsatSolver

instance : Coe NonemptyDomain Domain where
  coe d := d.domain

instance : Membership ℤ NonemptyDomain where
  mem d x := x ∈ d.domain

def NonemptyDomain.hull (d : NonemptyDomain) : Interval :=
  d.domain.hullOf d.nonempty

theorem NonemptyDomain.mem_hull (d : NonemptyDomain) {x : ℤ}
    (hx : x ∈ d) : x ∈ d.hull :=
  Domain.mem_hull d.domain d.nonempty hx

def NonemptyDomain.singleton (v : Int64) : NonemptyDomain :=
  ⟨Domain.singleton v, by simp [Domain.singleton]⟩

def NonemptyDomain.interval (i : Interval) : NonemptyDomain :=
  ⟨Domain.interval i, by simp [Domain.interval]⟩

def NonemptyDomain.min (d : NonemptyDomain) : Int64 :=
  (d.domain.intervals.head d.nonempty).left

def NonemptyDomain.max (d : NonemptyDomain) : Int64 :=
  (d.domain.intervals.getLast d.nonempty).right

theorem NonemptyDomain.hull_interval_eq {i : Interval}
  (d : NonemptyDomain) (heq : d = NonemptyDomain.interval i) :
    d.hull = i := by
      dsimp [NonemptyDomain.hull, Domain.hullOf]
      rw [heq]
      dsimp [NonemptyDomain.interval, Domain.interval, List.head]

theorem NonemptyDomain.hull_left_mem (d : NonemptyDomain) :
    (d.hull.left : ℤ) ∈ d.domain := by
  refine ⟨d.domain.intervals.head d.nonempty, List.head_mem d.nonempty, ?_⟩
  exact ⟨le_rfl, (d.domain.intervals.head d.nonempty).left_le_right⟩

theorem NonemptyDomain.hull_right_mem (d : NonemptyDomain) :
    (d.hull.right : ℤ) ∈ d.domain := by
  refine ⟨d.domain.intervals.getLast d.nonempty, List.getLast_mem d.nonempty, ?_⟩
  exact ⟨(d.domain.intervals.getLast d.nonempty).left_le_right, le_rfl⟩

end CpsatSolver
