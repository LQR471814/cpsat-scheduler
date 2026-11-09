import CpsatSolver

namespace CpsatScheduler

-- we can use decl_name% (Lean.Name.hash.toNat) for ID
-- we can also use global macro

-- - unique Nat identity not necessary for all entities
-- - entity already somewhat identified by value:
--     type
--     deps
--     settings
--
-- ex. constraint does not need ID, reasonably speaking, two constraints with
-- the exact same contents and enforcement does not need to be duplicated
--
-- objective/linearexpr have same reasoning

-- sorting of objects may be taken care of by simply defining a deterministic
-- method of getting a Nat from any entity

-- the problem is that variables may be constructed dynamically based on
-- runtime factors

-- to predict how many variables will be constructed requires runtime knowledge?




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

def Horizon.start (h : Horizon) := h.start_times.left

def Horizon.end (h : Horizon) := h.start_times.right

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
    P.horizon.contains_interval start.intVar.domainHull

end CpsatScheduler

