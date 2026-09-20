import CpsatScheduler.UnitAware
import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Util.Graphs

namespace CpsatScheduler

/-- Containment in child coordinates using the exact unit ratio:
`parentStart * ratio ≤ childStart` and
`childStart + 1 ≤ (parentStart + 1) * ratio`. -/
def bucketContainedIn.variants
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
def prerequisite.variant (successor predecessor : CpsatSolver.IntVar)
    (addPred :
      CpsatSolver.Int64.Nonoverflow ((predecessor.domain.hull.left : ℤ) + 1) ∧
      CpsatSolver.Int64.Nonoverflow ((predecessor.domain.hull.right : ℤ) + 1)) :
    CpsatSolver.BoundedLinearExpr :=
  let succE := CpsatSolver.LinearExpr.var successor
  let predE := CpsatSolver.LinearExpr.var predecessor
  let one : CpsatSolver.LinearExpr _ :=
    CpsatSolver.LinearExpr.const (CpsatSolver.Int64.of 1)
  let predEnd := CpsatSolver.LinearExpr.add predE one addPred
  {
    rel := .gte
    leftBounds := successor.domain.hull
    rightBounds := predecessor.domain.hull.add
      (CpsatSolver.Interval.fromValue (CpsatSolver.Int64.of 1)) addPred
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

end CpsatScheduler
