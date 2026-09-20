import CpsatScheduler.UnitAware

open CpsatScheduler

namespace CpsatScheduler

/-- Coarser conversion from unit `u` to `v` (`u ∣ v`): auxiliary quotient plus
truncating division equality. -/
def UnitAware.truncCoarsen {u v : UnitScale}
    (e : UnitAware.LinearExpr u) (huv : u.val ∣ v.val)
    (quotDomain : CpsatSolver.NonemptyDomain) (label : Option String := none) :
    CpsatSolver.Builder (UnitAware.IntVar v) := do
  let ratio := UnitScale.exactRatio v u huv
  have hdiv : (0 : ℤ) < ratio.val := by
    change (0 : ℤ) < ((v.val / u.val : ℕ) : ℤ)
    have hle : u.val ≤ v.val := Nat.le_of_dvd v.pos huv
    have hpos : 0 < v.val / u.val := Nat.div_pos hle u.pos
    exact_mod_cast hpos
  let q ← CpsatSolver.Builder.truncCoarsen e.cpsat ratio hdiv quotDomain label
  pure ⟨q⟩

structure Model.Task (scales : Timescales) where
  task : Task scales
  startVar : TaskStart scales
  costTable : TaskCostTable (scales := scales) task

end CpsatScheduler
