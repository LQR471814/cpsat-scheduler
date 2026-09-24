import CpsatScheduler.UnitAware
import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Util.Graphs
import CpsatScheduler.UnitScale

namespace CpsatScheduler

/-- Containment in child coordinates using the exact unit ratio:
`parentStart * ratio ≤ childStart` and
`childStart + 1 ≤ (parentStart + 1) * ratio`. -/
def Constraint.bucketContainedIn
    (child parent : CpsatSolver.IntVar) (ratio : CpsatSolver.Int64)
    (mul₁ :
      CpsatSolver.Int64.Nonoverflow
        (parent.domain.hull.mulLower (CpsatSolver.Interval.fromValue ratio)) ∧
      CpsatSolver.Int64.Nonoverflow
        (parent.domain.hull.mulUpper (CpsatSolver.Interval.fromValue ratio)))
    (add₁ :
      CpsatSolver.Int64.Nonoverflow ((parent.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((parent.domain.hull.right : ℤ) + 1))
    (mul₂ :
      CpsatSolver.Int64.Nonoverflow
        (((parent.domain.hull.add (CpsatSolver.Interval.fromValue (CpsatSolver.Int64.of 1))
            add₁).mulLower (CpsatSolver.Interval.fromValue ratio))) ∧
      CpsatSolver.Int64.Nonoverflow
        (((parent.domain.hull.add (CpsatSolver.Interval.fromValue (CpsatSolver.Int64.of 1))
            add₁).mulUpper (CpsatSolver.Interval.fromValue ratio))))
    (addChild :
      CpsatSolver.Int64.Nonoverflow ((child.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((child.domain.hull.right : ℤ) + 1)) :
    CpsatSolver.BoundedLinearExpr × CpsatSolver.BoundedLinearExpr :=
  let childE := CpsatSolver.LinearExpr.var child
  let parentE := CpsatSolver.LinearExpr.var parent
  let parentScaled := CpsatSolver.LinearExpr.mul parentE ratio mul₁
  let one : CpsatSolver.LinearExpr _ :=
    CpsatSolver.LinearExpr.const (CpsatSolver.Int64.of 1)
  let parentPlus := CpsatSolver.LinearExpr.add parentE one add₁
  let parentPlusScaled := CpsatSolver.LinearExpr.mul parentPlus ratio mul₂
  let childPlus := CpsatSolver.LinearExpr.add childE one addChild
  {
    fst := {
      rel := .gte
      leftBounds := child.domain.hull
      rightBounds := parent.domain.hull.mul (CpsatSolver.Interval.fromValue ratio) mul₁
      left := childE
      right := parentScaled
    },
    snd := {
      rel := .lte
      leftBounds := child.domain.hull.add (CpsatSolver.Interval.fromValue (CpsatSolver.Int64.of 1))
        addChild
      rightBounds :=
        (parent.domain.hull.add (CpsatSolver.Interval.fromValue (CpsatSolver.Int64.of 1)) add₁).mul
          (CpsatSolver.Interval.fromValue ratio) mul₂
      left := childPlus
      right := parentPlusScaled
    }
  }

/-- Successor start after predecessor bucket end, already in a common unit. -/
def Constraint.prerequisite (succ pred : CpsatSolver.IntVar)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((pred.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((pred.domain.hull.right : ℤ) + 1)) :
    CpsatSolver.BoundedLinearExpr :=
  let succE := CpsatSolver.LinearExpr.var succ
  let predE := CpsatSolver.LinearExpr.var pred
  let one : CpsatSolver.LinearExpr _ :=
    CpsatSolver.LinearExpr.const (CpsatSolver.Int64.of 1)
  let predEnd := CpsatSolver.LinearExpr.add predE one nonoverflow
  {
    rel := .gte
    leftBounds := succ.domain.hull
    rightBounds := pred.domain.hull.add
      (CpsatSolver.Interval.fromValue (CpsatSolver.Int64.of 1)) nonoverflow
    left := succE
    right := predEnd
  }

/-- Parents form a forest: at most one immediate parent, acyclic, and strict
unit growth on every edge. Multiple roots are allowed. -/
def ParentsForest {scales : Timescales} [DecidableEq (Task scales)]
    (g : FinDigraph (Task scales)) : Prop :=
  g.IsTree ∧ g.IsAcyclic ∧
    ∀ e : g.edges, e.val.src.val.unit.val.val < e.val.dst.val.unit.val.val

def PrerequisitesAcyclic {scales : Timescales} [DecidableEq (Task scales)]
    (g : FinDigraph (Task scales)) : Prop :=
  g.IsAcyclic

/-- Capacity of a per-scale packing cumulative: the bucket width in atomic units. -/
def scaleCapacity (u : UnitScale) : CpsatSolver.LinearExpr.WithBounds :=
  let c : CpsatSolver.Int64 := ⟨u.val, u.nonoverflow⟩
  ⟨CpsatSolver.Interval.fromValue c, CpsatSolver.LinearExpr.const c⟩

/-- Packing cumulative at one bucket scale: interval size is 1 in bucket-index
coordinates, demand is atomic `timeDemanded`, capacity is the scale. -/
def packScaleCumulative (items : Array CpsatSolver.CumulativeItem) (u : UnitScale) :
    CpsatSolver.Constraint.Variant :=
  .cumulative items (scaleCapacity u)

-- we do add_cumulative for each timescale and incorporate the intervals and
-- demands of both the current and the lower timescales (normalized to fit
-- inside the current timescale)

-- add_cumulative constraint for a single timescale
def Constraint.packSingleLayer
  {scales : Timescales}
  (u : UnitScale)
  (u_in_scales : u ∈ scales.units.set := by decide)
  (tasks : Array (TaskVars scales))
    : CpsatSolver.Builder CpsatSolver.Constraint.Variant := do
  let tasksUnitEq := tasks.filter
    (fun x => decide (x.task.unit = u))
  let itemsUnitEq <- tasksUnitEq.mapM
    (fun (t : TaskVars scales) => do
      let interval <- CpsatSolver.Builder.newFixedSizeInterval
        (.var t.startVar) u
        (by exact Int.natCast_nonneg u.val)
      let result : CpsatSolver.CumulativeItem := {
        interval := interval.val
        demand := (
          CpsatSolver.LinearExpr.var t.timeDemandedVar
        ).wrapBounds
      }
      pure result)
  let tasksUnitLt :=
    (tasks.filter
      (fun x => decide (x.task.unit < u))).attachWith
        (fun x => decide (x.task.unit < u) = true)
        (fun x hx => (Array.mem_filter.mp hx).2)
  let itemsUnitLt <- tasksUnitLt.mapM
    (α := { x : TaskVars scales // decide (↑x.task.unit < u) = true })
    (β := CpsatSolver.CumulativeItem)
    (fun el => do
      let task := el.val.task
      let startVar := el.val.startVar
      let startLinExpr := CpsatSolver.LinearExpr.var startVar
      have taskunit_lt_u : task.unit < u := of_decide_eq_true el.prop
      have taskunit_le_u : task.unit.val ≤ u.val :=
        LT.lt.le (a := task.unit.val.val) (b := u.val) taskunit_lt_u
      let normalized : UnitAware.IntVar u <-
        UnitAware.truncCoarsen
          (u := task.unit) (v := u)
          ⟨startVar.domain.hull, startLinExpr⟩
          (scales.units.divisibility
            u
            u_in_scales
            task.unit.val
            task.unit.mem
            taskunit_le_u)
          none
      let interval <- CpsatSolver.Builder.newFixedSizeInterval
        (.var normalized.var) u
        (by exact Int.natCast_nonneg u.val)
      let result : CpsatSolver.CumulativeItem := {
        interval := interval.val
        demand := (
          CpsatSolver.LinearExpr.var el.val.timeDemandedVar
        ).wrapBounds
      }
      pure result
    )
  let capacity : CpsatSolver.LinearExpr.WithBounds :=
    {
      fst := {
        left := u
        right := u
        left_le_right := by exact Int.le_refl u
      }
      snd := .const u
    }
  let result : CpsatSolver.Constraint.Variant :=
    .cumulative (itemsUnitEq ++ itemsUnitLt) capacity
  pure result

def Constraint.packing
  {scales : Timescales}
  (tasks : Array (TaskVars scales))
    : CpsatSolver.Builder Unit := do
  let _ <- (UnitScale.sort scales.units.set).attach.mapM
    (fun unit => do
      let cnstr <- (Constraint.packSingleLayer
        unit.val
        (unit.val.mem_sort unit.prop)
        tasks)
      let _ <- CpsatSolver.Builder.addConstraint .always cnstr none)
  pure ()

end CpsatScheduler
