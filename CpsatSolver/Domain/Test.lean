import CpsatSolver.Domain.Domain

namespace CpsatSolver

example : ¬ ((100 : ℤ) ∈ Domain.interval
    (Interval.of 0 1 ⟨by native_decide, by native_decide⟩ (by native_decide))) := by
  decide

example : (2 : ℤ) ^ 60 ∈
    Domain.interval (Interval.of 0 ((2 : ℤ) ^ 60)
      ⟨by native_decide, by native_decide⟩ (by native_decide)) := by
  decide

end CpsatSolver
