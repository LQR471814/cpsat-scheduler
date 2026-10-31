import CpsatScheduler.CpsatSolver

namespace CpsatScheduler.New

-- we can use decl_name% (Lean.Name.hash.toNat) for ID
-- we can also use global macro

structure Task (U : CpsatSolver.Unit.Set) where
  id : ℕ
  label : Option String
  start : CpsatSolver.UnitAwareIntVar U
  demand : CpsatSolver.IntVar
  cost : CpsatSolver.IntVar

end CpsatScheduler.New

