import CpsatScheduler.CpsatSolver.Domain.Domain

namespace CpsatSolver

example : ¬ ((100 : ℤ) ∈ Domain.interval
    (Interval.of 0 1 ⟨by decide, by decide⟩ (by decide))) := by
  decide

example : (2 : ℤ) ^ 60 ∈
    Domain.interval (Interval.of 0 ((2 : ℤ) ^ 60)
      ⟨by decide, by decide⟩ (by decide)) := by
  decide

end CpsatSolver
