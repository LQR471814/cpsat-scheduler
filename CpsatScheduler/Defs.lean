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



-- perhaps what we actually want is a "derived identity", where the identity of
-- an object depends on the identity of other objects?
--
-- where such objects may be other derived identities or certain "primitive
-- values"
--
-- if two objects have the same "derived identity" then they are equal
--
-- this solves the problem where: I have an object and I create two objects
-- from that same reference point, if they have different internal properties,
-- then they are different, if they have the exact same internal properties,
-- then by definition, they are exactly the same
--
-- each object should probably also come with a theorem that states if their
-- "derived identity" is equal, then they are definitionally equal
--
-- well what I have described is literally definitional equality. it simply
-- doesn't "feel" like definitional equality because now certain objects may
-- refer to other objects it is completely unrelated to

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

