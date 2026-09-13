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
  nonoverflow : ∀ a : set, CpsatSolver.Int64.Nonoverflow a
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
  coeff : CpsatSolver.Int64
  unit : units.set
  deriving DecidableEq

def UnitValue.add {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val + b.coeff.val))
  : UnitValue units :=
    {
      coeff := { val := a.coeff.val + b.coeff.val, nonoverflow := nonoverflow },
      unit := a.unit
    }

def UnitValue.sub {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val - b.coeff.val))
  : UnitValue units :=
    {
      coeff := { val := a.coeff.val - b.coeff.val, nonoverflow := nonoverflow }
      unit := a.unit
    }

def UnitValue.mul {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val * b.coeff.val))
  : UnitValue units :=
    {
      coeff := { val := a.coeff.val * b.coeff.val, nonoverflow := nonoverflow }
      unit := a.unit
    }

def UnitValue.div {units : Units}
  (a b : UnitValue units)
  (_ : a.unit = b.unit)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val / b.coeff.val))
  : UnitValue units :=
    {
      coeff := { val := a.coeff.val / b.coeff.val, nonoverflow := nonoverflow }
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
    CpsatSolver.Int64.Nonoverflow (task.convertLossy Y).val := by
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
  exact CpsatSolver.Int64.proof_ediv_of_pos task.coeff.nonoverflow hkpos

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
  validGe : CpsatSolver.Int64.Nonoverflow greater
  validLe : CpsatSolver.Int64.Nonoverflow lesser
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
        coeff := CpsatSolver.Int64.mk 0 (by decide),
        unit := { val := 1, property := by decide }
      }
      ending := {
        coeff := CpsatSolver.Int64.mk 32 (by decide),
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
        nonoverflow := by
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
        nonoverflow := by
          have hunit : horizon.ending.unit ≤ t.unit := by
            rw [horizon.end_is_atomic]
            exact units.nonzero t.unit
          exact UnitValue.convertLossy_coeff_proof horizon.ending t.unit hunit

      },
      unit := t.unit,
    }
  | Option.some time => time.val

def Task.costVar {scales : Timescales} (t : Task scales)
  (min max : ℤ)
  (min_nonoverflow : CpsatSolver.Int64.Nonoverflow min)
  (max_nonoverflow : CpsatSolver.Int64.Nonoverflow max)
  (min_le_max : min ≤ max) :=
  curryValidName s! "{t.name.val}_cost" (fun name => ({
    name := name
    domain := {
      left := { val := min, nonoverflow := min_nonoverflow }
      right := { val := max, nonoverflow := max_nonoverflow }
      left_le_right := min_le_max
    }
  } : CpsatSolver.IntVar))

def Task.durationVar {scales : Timescales} (t : Task scales) :=
  curryValidName s! "{t.name.val}_duration" (fun name => ({
    name := name
    domain := {
      left := { val := 0, nonoverflow := by decide }
      right := {
        val := t.unit.val
        nonoverflow := scales.units.nonoverflow t.unit
      }
      left_le_right := by
        change (0 : ℤ) ≤ t.unit.val
        have hunit := scales.units.nonzero t.unit
        change (1 : ℤ) ≤ t.unit.val at hunit
        omega
    }
  } : CpsatSolver.IntVar))



namespace UnitAware

structure IntVar (units : Units) where
  var : CpsatSolver.IntVar
  unit : units.set

def IntVar.name {units : Units} (container : IntVar units) :=
  container.var.name

structure LinearExpr (units : Units) where
  domain : CpsatSolver.Interval
  cpsat : CpsatSolver.LinearExpr domain
  unit : units.set

def LinearExpr.valueSet {units : Units} (l : LinearExpr units)
  : Set (UnitValue units) :=
    fun v =>
      v.unit = l.unit ∧
      v.coeff ∈ l.domain

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
    domain := awareVar.var.domain
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
  fun (result : CpsatSolver.Interval) nonoverflow result_eq => ({
    domain := result
    cpsat := CpsatSolver.LinearExpr.add
      a.cpsat b.cpsat result nonoverflow result_eq
    unit := a.unit
  } : LinearExpr units)

def LinearExpr.sub {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun (result : CpsatSolver.Interval) nonoverflow result_eq => ({
    domain := result
    cpsat := CpsatSolver.LinearExpr.sub
      a.cpsat b.cpsat result nonoverflow result_eq
    unit := a.unit
  } : LinearExpr units)

def LinearExpr.mul {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun (result : CpsatSolver.Interval) nonoverflow result_eq => ({
    domain := result
    cpsat := CpsatSolver.LinearExpr.mul
      a.cpsat b.cpsat result nonoverflow result_eq
    unit := a.unit
  } : LinearExpr units)

structure BoundedLinearExpr (units : Units) where
  rel : CpsatSolver.BoundedLinearExpr.Rel
  left : LinearExpr units
  right : LinearExpr units
  units_eq : left.unit = right.unit
  no_contradict : CpsatSolver.BoundedLinearExpr.NoContradict
    (L := left.domain) (R := right.domain) rel left.cpsat right.cpsat

def BoundedLinearExpr.cpsat {units : Units}
  (b : BoundedLinearExpr units) : CpsatSolver.BoundedLinearExpr :=
    {
      rel := b.rel
      leftDomain := b.left.domain
      rightDomain := b.right.domain
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

structure Constraint (units : Units) where
  name : CpsatSolver.Python.ValidName
  enforcement : CpsatSolver.Constraint.Enforcement
  variant : Constraint.Variant units

end UnitAware


def Task.start {scales : Timescales} (task : Task scales) :=
  let startIntVar {scales : Timescales} (t : Task scales)
      (start_le_end :
        t.startAfterTime.coeff.val ≤ t.startBeforeTime.coeff.val) :=
    curryValidName s! "{t.name.val}_start" (fun name => ({
      name := name
      domain := {
        left := t.startAfterTime.coeff
        right := t.startBeforeTime.coeff
        left_le_right := start_le_end
      }
    } : CpsatSolver.IntVar))
  fun hname hvar =>
    ({
      var := startIntVar task hvar hname
      unit := task.unit
    } : UnitAware.IntVar scales.units)



def TaskConstrain.afterTask {scales : Timescales}
  (self other : UnitAware.IntVar scales.units) :=
  let curried name_valid no_contradict :
    UnitAware.Constraint scales.units :=
    let selfStart := UnitAware.LinearExpr.var self
    let otherStart := UnitAware.LinearExpr.var other
    let converted := otherStart.convertUnit self.unit
    {
      name := CpsatSolver.Python.ValidName.mk
        s!"{self.name.val}_after_{other.name.val}_start"
        name_valid
      enforcement := CpsatSolver.Constraint.Enforcement.always
      variant := UnitAware.Constraint.Variant.bounded_linear
        {
          rel := CpsatSolver.BoundedLinearExpr.Rel.gte,
          left := selfStart
          right := converted.val
          no_contradict := no_contradict
          units_eq := converted.property.symm
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
    let selfStart : CpsatSolver.LinearExpr self.var.domain :=
      CpsatSolver.LinearExpr.var self.var
    let parentStart : CpsatSolver.LinearExpr parent.var.domain :=
      CpsatSolver.LinearExpr.var parent.var
    let parentUnit : CpsatSolver.Int64 := {
      val := parent.unit.val
      nonoverflow := scales.units.nonoverflow parent.unit
    }
    let parentUnitDomain := (CpsatSolver.Interval.fromValue parentUnit).val
    let parentEndNonoverflow :=
      And.intro parent_end_domain_min_valid parent_end_domain_max_valid
    let parentEndDomain :=
      (parent.var.domain.add parentUnitDomain parentEndNonoverflow).val
    let parentEnd : CpsatSolver.LinearExpr parentEndDomain :=
      CpsatSolver.LinearExpr.add
        parentStart
        (CpsatSolver.LinearExpr.const parentUnit)
        parentEndDomain
        parentEndNonoverflow
        rfl
    let afterParentStart : CpsatSolver.Constraint :=
      {
        name := CpsatSolver.Python.ValidName.mk
          s!"{self.name.val}_after_{parent.name.val}_start"
          constraint_name1_valid
        enforcement := CpsatSolver.Constraint.Enforcement.always
        variant := CpsatSolver.Constraint.Variant.bounded_linear
          {
            rel := CpsatSolver.BoundedLinearExpr.Rel.gte,
            leftDomain := parent.var.domain
            rightDomain := self.var.domain
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
          rel := CpsatSolver.BoundedLinearExpr.Rel.lt,
          leftDomain := self.var.domain
          rightDomain := parentEndDomain
          left := selfStart,
          right := parentEnd,
          no_contradict := no_contradict_before_end
        }
    };
    #[ afterParentStart, beforeParentEnd ]

end CpsatScheduler
