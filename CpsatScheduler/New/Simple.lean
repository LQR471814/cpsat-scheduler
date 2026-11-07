import CpsatScheduler.CpsatSolver
-- import CpsatScheduler.CpsatSolver.Domain.Interval

namespace CpsatScheduler.New

-- we can use decl_name% (Lean.Name.hash.toNat) for ID
-- we can also use global macro

structure Horizon where
  -- closed interval of possible start times
  start_times : CpsatSolver.Interval
  start_pos : start_times.left ≥ (0 : ℤ)

def Horizon.of
  (start_times : CpsatSolver.Interval)
  (start_pos : start_times.left ≥ (0 : ℤ) := by native_decide) :
    Horizon :=
  ⟨start_times, start_pos⟩

def Horizon.contains_interval (h : Horizon) (d : CpsatSolver.Interval) :=
  d ⊆ h.start_times

structure TaskParams where
  horizon : Horizon
  units : CpsatSolver.Unit.Set

structure Task (P : TaskParams) where
  id : ℕ
  label : Option String
  start : CpsatSolver.UnitAwareIntVar P.units
  demand : CpsatSolver.IntVar
  cost : CpsatSolver.IntVar
  start_in_horizon :
    P.horizon.contains_interval start.intVar.domain.hull

end CpsatScheduler.New

