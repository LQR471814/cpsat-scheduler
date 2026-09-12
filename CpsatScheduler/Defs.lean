import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Interval
import Mathlib.Data.Finset.Sort
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Combinatorics.Digraph.Basic
import Mathlib.Data.Int.Star
import Mathlib.Algebra.Order.Ring.Star

import CpsatScheduler.CpsatSolver.Helpers
import CpsatScheduler.Util.Finset
import CpsatScheduler.Util.Graphs

namespace CpsatScheduler

-- ensures no remainder when int division, preventing lossy division
private abbrev Int.losslessDiv (a : ℤ) (b : ℤ) (_ : a % b = 0) :=
  a / b



structure Units where
  set : Finset ℤ
  has_atomic : 1 ∈ set
  nonzero : ∀ u : set, u ≥ { val := 1, property := has_atomic }
  divisibility : ∀ a b : set, a ≥ b → (a : ℤ) % b = 0
  nonoverflow : ∀ a : set, Int64.Nonoverflow a
  deriving DecidableEq

abbrev Units.max (units : Units) : units.set :=
  have nonempty := Exists.intro 1 units.has_atomic;
  {
    val := units.set.max' nonempty,
    property := Finset.max'_mem units.set nonempty
  }

abbrev Units.atomic (units : Units) : units.set := {
  val := 1, property := units.has_atomic
}

theorem Units.one_is_atomic (units : Units) : (1 : ℤ) = units.atomic :=
  by grind

theorem Units.all_ge_atomic {units : Units}
  : ∀ u : units.set, units.atomic ≤ u :=
    units.nonzero



structure UnitValue (units : Units) where
  coeff : CpsatSolver.Int64.Proven
  unit : units.set
  deriving DecidableEq

def UnitValue.add {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : Int64.Nonoverflow (a.unit.val + b.unit.val))
  : UnitValue units :=
    {
      coeff := { val := a.unit.val + b.unit.val, proof := nonoverflow },
      unit := a.unit
    }

def UnitValue.sub {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : Int64.Nonoverflow (a.unit.val - b.unit.val))
  : UnitValue units :=
    {
      coeff := { val := a.unit.val - b.unit.val, proof := nonoverflow }
      unit := a.unit
    }

def UnitValue.mul {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : Int64.Nonoverflow (a.unit.val * b.unit.val))
  : UnitValue units :=
    {
      coeff := { val := a.unit.val * b.unit.val, proof := nonoverflow }
      unit := a.unit
    }

def UnitValue.div {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : Int64.Nonoverflow (a.unit.val / b.unit.val))
  : UnitValue units :=
    {
      coeff := { val := a.unit.val / b.unit.val, proof := nonoverflow }
      unit := a.unit
    }

-- suppose I have a quantity A * X
-- and quantity B * Y
--
-- s.t.
-- X ≥ 1, Y ≥ 1
-- X % Y = 0 (this implies X ≥ Y)
--
-- if I want to find B' s.t. (B * Y) = (B' * X)
-- B * Y = B' * X
-- B' = B * Y / X
--
-- if I want to write A' s.t. (A * X) = (A' * Y)
-- A' * Y = A * X
-- A' = A * X / Y

-- when converting from larger unit -> smaller unit
def UnitValue.convertLossless {units : Units}
  (task : UnitValue units)
  (Y : units.set) :=
  let A := task.coeff.val
  let X : units.set := task.unit
  let curried (div_atomic : Y.val ∣ A * X.val)
    : { A' : ℤ // A * X = A' * Y } :=
      let A' := A * X / Y;
      have proof : A * X.val = A' * Y.val := by
        unfold A'
        rw [Int.ediv_mul_cancel div_atomic];
      {
        val := A'
        property := proof
      }
  curried

-- when converting from smaller unit -> larger unit
def UnitValue.convertLossy {units : Units}
  (task : UnitValue units) (Y : units.set) :=
  let A := task.coeff.val
  let X := task.unit
  let result : { A' : ℤ // |A * X - A' * Y| < Y } :=
    let N : ℤ := A * X.val
    let B' : ℤ := N / Y.val
    have hYpos : (0 : ℤ) < Y.val :=
      lt_of_lt_of_le
        Int.zero_lt_one
        (show (1 : ℤ) ≤ Y.val from units.nonzero Y)
    have hrem_nonneg : 0 ≤ N % Y.val :=
      Int.emod_nonneg N (ne_of_gt hYpos)
    have hrem_lt : N % Y.val < Y.val :=
      Int.emod_lt_of_pos N hYpos
    have hdiff : N - B' * Y.val = N % Y.val :=
      calc
        N - B' * Y.val
            = N - (N / Y.val) * Y.val := rfl
        _   = N - Y.val * (N / Y.val) :=
              congrArg
                (fun z : ℤ => N - z)
                (Int.mul_comm (N / Y.val) Y.val)
        _   = N % Y.val :=
              (Int.emod_def N Y.val).symm
    {
      val := B'
      property :=
        calc
          |N - B' * Y.val|
              = |N % Y.val| :=
                congrArg (fun z : ℤ => |z|) hdiff
          _   = N % Y.val :=
                abs_of_nonneg hrem_nonneg
          _   < Y.val :=
                hrem_lt
    }
  result

/-- Converting exactly to a no-larger unit cannot decrease the coefficient's magnitude. -/
theorem UnitValue.convertLossless_coeff_abs_le {units : Units}
    (task : UnitValue units) (Y : units.set) (hYX : Y ≤ task.unit) :
    |task.coeff.val| ≤
      |(task.convertLossless Y (dvd_mul_of_dvd_right
        (Int.dvd_iff_emod_eq_zero.mpr (units.divisibility task.unit Y hYX)) _)).val| := by
  have hYpos : 0 < Y.val :=
    lt_of_lt_of_le Int.zero_lt_one (units.nonzero Y)
  obtain ⟨k, hk⟩ : ∃ k : ℤ, task.unit.val = Y.val * k :=
    Int.dvd_iff_emod_eq_zero.mpr (units.divisibility task.unit Y hYX)
  have hk_nonneg : 0 ≤ k := by
    have hXgeY : Y.val ≤ task.unit.val := hYX
    rw [hk] at hXgeY
    nlinarith
  have hk_one : 1 ≤ k := by
    have hXgeY : Y.val ≤ task.unit.val := hYX
    rw [hk] at hXgeY
    nlinarith
  rw [show (task.convertLossless Y (dvd_mul_of_dvd_right
      (Int.dvd_iff_emod_eq_zero.mpr (units.divisibility task.unit Y hYX)) _)).val =
      task.coeff.val * k by
    simp only [UnitValue.convertLossless]
    rw [hk]
    rw [show task.coeff.val * (Y.val * k) = Y.val * (task.coeff.val * k) by ring]
    exact Int.mul_ediv_cancel_left _ (ne_of_gt hYpos)]
  rw [abs_mul, abs_of_nonneg hk_nonneg]
  nlinarith [abs_nonneg task.coeff.val]

/-- Converting to a no-smaller unit cannot increase the coefficient's magnitude. -/
theorem UnitValue.convertLossy_coeff_abs_le {units : Units}
    (task : UnitValue units) (Y : units.set) (hXY : task.unit ≤ Y) :
    |(task.convertLossy Y).val| ≤ |task.coeff.val| := by
  have hXpos : 0 < task.unit.val :=
    lt_of_lt_of_le Int.zero_lt_one (units.nonzero task.unit)
  obtain ⟨k, hk⟩ : ∃ k : ℤ, Y.val = task.unit.val * k :=
    Int.dvd_iff_emod_eq_zero.mpr (units.divisibility Y task.unit hXY)
  rw [show (task.convertLossy Y).val = task.coeff.val / k by
    simp only [UnitValue.convertLossy]
    rw [hk]
    calc
      task.coeff.val * task.unit.val / (task.unit.val * k)
          = task.unit.val * task.coeff.val / (task.unit.val * k) := by rw [mul_comm]
      _ = task.coeff.val / k := Int.mul_ediv_mul_of_pos _ _ hXpos]
  exact Int.abs_ediv_le_abs _ _

/-- Lossy conversion to a no-smaller unit produces an Int64-valid coefficient. -/
theorem UnitValue.convertLossy_coeff_proof {units : Units}
    (task : UnitValue units) (Y : units.set) (hXY : task.unit ≤ Y) :
    Int64.Nonoverflow (task.convertLossy Y).val := by
  have hXpos : 0 < task.unit.val :=
    lt_of_lt_of_le Int.zero_lt_one (units.nonzero task.unit)
  obtain ⟨k, hk⟩ : ∃ k : ℤ, Y.val = task.unit.val * k :=
    Int.dvd_iff_emod_eq_zero.mpr (units.divisibility Y task.unit hXY)
  have hkpos : 0 < k := by
    have hYpos : 0 < Y.val :=
      lt_of_lt_of_le Int.zero_lt_one (units.nonzero Y)
    rw [hk] at hYpos
    nlinarith
  rw [show (task.convertLossy Y).val = task.coeff.val / k by
    simp only [UnitValue.convertLossy]
    rw [hk]
    calc
      task.coeff.val * task.unit.val / (task.unit.val * k)
          = task.unit.val * task.coeff.val / (task.unit.val * k) := by rw [mul_comm]
      _ = task.coeff.val / k := Int.mul_ediv_mul_of_pos _ _ hXpos]
  exact CpsatSolver.Int64.proof_ediv_of_pos task.coeff.proof hkpos

abbrev UnitValue.lt {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit) : Prop :=
  a.coeff.val < b.coeff.val



structure Horizon (units : Units) where
  beginning : UnitValue units
  ending : UnitValue units
  begin_is_atomic : beginning.unit = units.atomic
  end_is_atomic : ending.unit = units.atomic
  begin_lt_end : beginning.lt ending (by grind)
  deriving DecidableEq

structure Timescales where
  units : Units
  horizon : Horizon units
  deriving DecidableEq



structure Interval where
  greater : ℤ
  lesser : ℤ
  validLt : lesser ≤ greater
  validGe : Int64.Nonoverflow greater
  validLe : Int64.Nonoverflow lesser
  deriving DecidableEq

structure IntervalWithValue (α : Type) where
  interval : Interval
  value : α
  deriving DecidableEq

abbrev Interval.mutuallyExclusive (s : Finset Interval) :=
  ∀ a b : Interval, a ∈ s ∧ b ∈ s →
    (Finset.Icc a.lesser a.greater) ∪ (Finset.Icc b.lesser b.greater) = ∅



structure DiscretizedFunction (α : Type) where
  intervals : Finset (IntervalWithValue α)
  mutuallyExclusive :
    Interval.mutuallyExclusive (Finset.image (·.interval) intervals)
  deriving DecidableEq

inductive CostConfiguration (scales : Timescales) where
  | duration (value : UnitValue scales.units)
  deriving DecidableEq

structure Task (scales : Timescales) where
  name : CpsatSolver.Python.ValidName
  unit : scales.units.set
  startAfter : Option ({ t : UnitValue scales.units // t.unit = unit })
  startBefore : Option ({ t : UnitValue scales.units // t.unit = unit })
  deriving DecidableEq



structure TaskSet (scales : Timescales) where
  tasks : Finset (Task scales)
  -- prereqs : FinDigraph (Task scales)
  -- prereqsAcyclic : prereqs.IsAcyclic
  -- -- for any edge, src is the child & dst is the parent
  -- parents : FinDigraph (Task scales)
  -- parentsAcyclic : parents.IsAcyclic
  -- parentsTree : parents.IsTree
  -- parentsMonotonicUnit :
  --   ∀ e : parents.edges, e.val.src.val.unit.val < e.val.dst.val.unit.val

#check
  let scales : Timescales := {
    units := {
      set := { 1, 2, 4, 8 }
      nonzero := by decide
      nonoverflow := by decide
      has_atomic := by decide
      divisibility := by decide
    }
    horizon := {
      beginning := {
        coeff := CpsatSolver.Int64.Proven.mk 0 (by decide),
        unit := { val := 1, property := by decide }
      }
      ending := {
        coeff := CpsatSolver.Int64.Proven.mk 32 (by decide),
        unit := { val := 1, property := by decide }
      }
      begin_is_atomic := by decide
      end_is_atomic := by decide
      begin_lt_end := by decide
    }
  };
  let t1 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task1" (by decide)
    unit := { val := 1, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let t2 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task2" (by decide)
    unit := { val := 2, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let t3 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "task3" (by decide)
    unit := { val := 2, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let pt1 : Task scales := {
    name := CpsatSolver.Python.ValidName.mk "ptask1" (by decide)
    unit := { val := 4, property := by decide }
    startAfter := Option.none
    startBefore := Option.none
  };
  let tasks : Finset (Task scales) := {
    t1,
    t2,
    t3,
    pt1
  };
  let set : TaskSet scales := {
    tasks := tasks
    -- prereqs := {
    --   nodes := tasks
    --   edges := {
    --     {
    --       src := { val := t1, property := by decide },
    --       dst := { val := t2, property := by decide },
    --     },
    --     {
    --       src := { val := t1, property := by decide },
    --       dst := { val := t3, property := by decide },
    --     },
    --     {
    --       src := { val := t2, property := by decide },
    --       dst := { val := t3, property := by decide },
    --     }
    --   }
    -- },
    -- parents := {
    --   nodes := tasks
    --   edges := {
    --     {
    --       src := { val := t3, property := by decide },
    --       dst := { val := pt1, property := by decide }
    --     }
    --   }
    -- }
    -- -- prove every edge strictly increases or decreases an order
    -- -- prove that given a cycle, this contradicts the previous
    -- prereqsAcyclic := by decide
    -- parentsAcyclic := by decide
    -- parentsTree := by decide
    -- parentsMonotonicUnit := by decide
  };
  set



def curryValidName (name : String) (callback : CpsatSolver.Python.ValidName → α) :=
  let curried (name_valid : CpsatSolver.Python.ValidName.Proof name) :=
    callback { val := name, proof := name_valid };
  curried

def Task.startAfterTime {scales : Timescales}
  (t : Task scales) : UnitValue scales.units :=
  let units := scales.units;
  let horizon := scales.horizon;
  match t.startAfter with
  | Option.none =>
    {
      coeff := {
        val := (horizon.beginning.convertLossy t.unit).val
        proof := by
          have hunit : horizon.beginning.unit ≤ t.unit := by
            rw [horizon.begin_is_atomic]
            exact units.nonzero t.unit
          exact UnitValue.convertLossy_coeff_proof horizon.beginning t.unit hunit
      }
      unit := t.unit
    }
  | Option.some time => time.val

def Task.startBeforeTime {scales : Timescales}
  (t : Task scales) : UnitValue scales.units :=
  let units := scales.units;
  let horizon := scales.horizon;
  match t.startBefore with
  | Option.none =>
    {
      coeff := {
        val := (horizon.ending.convertLossy t.unit).val
        proof := by
          have hunit : horizon.ending.unit ≤ t.unit := by
            rw [horizon.end_is_atomic]
            exact units.nonzero t.unit
          exact UnitValue.convertLossy_coeff_proof horizon.ending t.unit hunit

      },
      unit := units.atomic,
    }
  | Option.some time => time.val

def Task.costVar {scales : Timescales} (t : Task scales)
  (min max : ℤ) :=
  curryValidName s! "{t.name.val}_cost" (fun name => ({
    name := name
    domain := {
      left := min
      right := max
    }
  } : CpsatSolver.IntVar))

def Task.durationVar {scales : Timescales} (t : Task scales) :=
  curryValidName s! "{t.name.val}_duration" (fun name => ({
    name := name
    domain := {
      left := 0
      right := t.unit
    }
  } : CpsatSolver.IntVar))



namespace UnitAware

structure IntVar (units : Units) where
  var : CpsatSolver.IntVar.Proven
  unit : units.set

def IntVar.name {units : Units} (container : IntVar units) :=
  container.var.val.name

structure LinearExpr (units : Units) where
  cpsat : CpsatSolver.LinearExpr.Proven
  unit : units.set
  deriving DecidableEq

def LinearExpr.domain {units : Units} (l : LinearExpr units)
  : Set (UnitValue units) :=
    fun v =>
      v.unit = l.unit ∧
      v.coeff.val ∈ l.cpsat.proof.domain

-- prove injectivity?
-- namely we can state that two exprs are injective via some relation?
--
-- Function.Injective?
-- prove: f x = f y -> x = y

/-- what are the rules for unit manipulation?

here, we have a situation where all units can be defined in terms of every other unit

we may have a "unit aware value" in which operations on it only make sense
between unit aware values of the same unit

or rather, operations between the same unit will result in a result of the same unit

operations between different units require conversion to the same unit

we define a "conversion" function:

C : unit -> value+unit -> value+unit

the properties of C are such that:

Let
a b : unit
v_a : value+unit, s.t. unit = a
v_b : value+unit, s.t. unit = b

C a v_a = v_a
(C b v_a).unit = b
(C b v_a).value / v_a.value = a / b

conversion between units is such that:

- every value in one unit can be found in the other unit

along the way, we might as well define the rest of the linear expr arithmetic
relationships

-/

def LinearExpr.var {units : Units}
  (awareVar : IntVar units) : LinearExpr units :=
  {
    cpsat := CpsatSolver.LinearExpr.var awareVar.var
    unit := awareVar.unit
  }

def LinearExpr.convertUnit {units : Units}
  (newUnit : units.set)
  (expr : LinearExpr units) : { x : LinearExpr units // x.unit = newUnit } :=
  {
    val := sorry
    property := sorry
  }

def LinearExpr.add {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun hmin hmax => ({
    cpsat := CpsatSolver.LinearExpr.add
      a.cpsat b.cpsat hmin hmax
    unit := a.unit
  } : LinearExpr units)

def LinearExpr.sub {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun hmin hmax => ({
    cpsat := CpsatSolver.LinearExpr.sub
      a.cpsat b.cpsat hmin hmax
    unit := a.unit
  } : LinearExpr units)

def LinearExpr.mul {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun hmin hmax => ({
    cpsat := CpsatSolver.LinearExpr.mul
      a.cpsat b.cpsat hmin hmax
    unit := a.unit
  } : LinearExpr units)

structure BoundedLinearExpr (units : Units) where
  op : BoundedLinearExpr.Type
  left : LinearExpr units
  right : LinearExpr units
  units_eq : left.unit = right.unit
  no_contradict : CpsatSolver.BoundedLinearExpr.NoContradict op left.cpsat right.cpsat
  deriving DecidableEq

def BoundedLinearExpr.cpsat {units : Units}
  (b : BoundedLinearExpr units) : CpsatSolver.BoundedLinearExpr :=
    {
      op := b.op
      left := b.left.cpsat
      right := b.right.cpsat
      no_contradict := b.no_contradict
    }

inductive Constraint.Variant (units : Units) where
  | bounded_linear (expr : BoundedLinearExpr units)
  | max_equality (target : LinearExpr units) (exprs : Array (LinearExpr units))
  | cumulative
    (intervals : Array CpsatSolver.FixedSizeIntervalVar)
    (demands : Array (LinearExpr units))
    (capacity : (LinearExpr units))
  deriving DecidableEq

structure Constraint (units : Units) where
  name : CpsatSolver.Python.ValidName
  enforcement : CpsatSolver.Constraint.Enforcement
  variant : Constraint.Variant units
  deriving DecidableEq

end UnitAware


def Task.start {scales : Timescales} (task : Task scales) :=
  let startIntVar {scales : Timescales} (t : Task scales) :=
    curryValidName s! "{t.name.val}_start" (fun name => ({
      name := name
      domain := {
        left := t.startBeforeTime.coeff * t.startAfterTime.unit
        right := t.startAfterTime.coeff * t.startAfterTime.unit
      }
    } : CpsatSolver.IntVar))
  fun hname hvar =>
    ({
      var := {
        val := startIntVar task hname
        property := hvar
      }
      unit := task.unit
    } : UnitAware.IntVar scales.units)



def TaskConstrain.afterTask {scales : Timescales}
  (self other : UnitAware.IntVar scales.units) :=
  let curried name_valid no_contradict :
    UnitAware.Constraint scales.units :=
    let selfStart : UnitAware.LinearExpr scales.units :=
      {
        cpsat := CpsatSolver.LinearExpr.var self.var
        unit := self.unit
      };
    let otherStart : UnitAware.LinearExpr scales.units :=
      {
        cpsat := CpsatSolver.LinearExpr.var other.var
        unit := other.unit
      };
    let converted := otherStart
    {
      name := CpsatSolver.Python.ValidName.mk
        s!"{self.name.val}_after_{other.name.val}_start"
        name_valid
      enforcement := CpsatSolver.Constraint.Enforcement.always
      variant := UnitAware.Constraint.Variant.bounded_linear
        {
          op := CpsatSolver.BoundedLinearExpr.Op.gte,
          left := otherStart
          right := selfStart
          no_contradict := no_contradict
          units_eq := sorry
        }
    }
  curried

def TaskConstrain.withinParent {scales : Timescales}
  (self parent : UnitAware.IntVar scales.units) :=
  fun
    constraint_name1_valid
    constraint_name2_valid
    parent_end_domain_min_valid
    parent_end_domain_max_valid
    no_contradict_after_start
    no_contradict_before_end
  =>
    let selfStart : CpsatSolver.LinearExpr.Proven :=
      CpsatSolver.LinearExpr.var self.var
    let parentStart : CpsatSolver.LinearExpr.Proven :=
      CpsatSolver.LinearExpr.var parent.var
    let parentEnd : CpsatSolver.LinearExpr.Proven :=
      CpsatSolver.LinearExpr.add
        parentStart
        (CpsatSolver.LinearExpr.const
          parent.unit
          (scales.units.nonoverflow parent.unit))
        parent_end_domain_min_valid
        parent_end_domain_max_valid
    let afterParentStart : CpsatSolver.Constraint :=
      {
        name := CpsatSolver.Python.ValidName.mk
          s!"{self.name.val}_after_{parent.name.val}_start"
          constraint_name1_valid
        enforcement := CpsatSolver.Constraint.Enforcement.always
        variant := CpsatSolver.Constraint.Variant.bounded_linear
          {
            op := CpsatSolver.BoundedLinearExpr.Op.gte,
            left := parentStart
            right := selfStart
            no_contradict := no_contradict_after_start
          }
      };
    let beforeParentEnd : CpsatSolver.Constraint := {
      name := CpsatSolver.Python.ValidName.mk
        s!"{self.name.val}_before_{parent.name.val}_end"
        constraint_name2_valid
      enforcement := CpsatSolver.Constraint.Enforcement.always
      variant := CpsatSolver.Constraint.Variant.bounded_linear
        {
          op := CpsatSolver.BoundedLinearExpr.Op.lt,
          left := selfStart,
          right := parentEnd,
          no_contradict := no_contradict_before_end
        }
    };
    #[ afterParentStart, beforeParentEnd ]

end CpsatScheduler
