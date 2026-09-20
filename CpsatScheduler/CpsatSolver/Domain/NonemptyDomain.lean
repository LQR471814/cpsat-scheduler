import CpsatScheduler.CpsatSolver.Domain.Domain

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

end CpsatSolver
