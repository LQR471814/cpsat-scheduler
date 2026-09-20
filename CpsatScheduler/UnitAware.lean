import CpsatScheduler.UnitScale

namespace CpsatScheduler.UnitAware

structure IntVar (u : UnitScale) where
  var : CpsatSolver.IntVar

structure LinearExpr (u : UnitScale) where
  bounds : CpsatSolver.Bounds
  cpsat : CpsatSolver.LinearExpr bounds

def LinearExpr.var {u : UnitScale} (v : IntVar u) : LinearExpr u :=
  { bounds := v.var.domain.hull, cpsat := CpsatSolver.LinearExpr.var v.var }

def LinearExpr.add {u : UnitScale} (a b : LinearExpr u)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((a.bounds.left : ℤ) + b.bounds.left) ∧
      CpsatSolver.Int64.Nonoverflow ((a.bounds.right : ℤ) + b.bounds.right)) :
    LinearExpr u :=
  {
    bounds := a.bounds.add b.bounds nonoverflow
    cpsat := CpsatSolver.LinearExpr.add a.cpsat b.cpsat nonoverflow
  }

def LinearExpr.sub {u : UnitScale} (a b : LinearExpr u)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((a.bounds.left : ℤ) - b.bounds.right) ∧
      CpsatSolver.Int64.Nonoverflow ((a.bounds.right : ℤ) - b.bounds.left)) :
    LinearExpr u :=
  {
    bounds := a.bounds.sub b.bounds nonoverflow
    cpsat := CpsatSolver.LinearExpr.sub a.cpsat b.cpsat nonoverflow
  }

/-- Exact conversion from a coarser unit `u` to a finer unit `v` by multiplying
by the integral scale ratio `u/v`. -/
def LinearExpr.rescaleExact {u v : UnitScale}
    (e : LinearExpr u) (hv : v.val ∣ u.val)
    (mul_nonoverflow :
      CpsatSolver.Int64.Nonoverflow
        (e.bounds.mulLower (CpsatSolver.Interval.fromValue (UnitScale.exactRatio u v hv))) ∧
      CpsatSolver.Int64.Nonoverflow
        (e.bounds.mulUpper (CpsatSolver.Interval.fromValue (UnitScale.exactRatio u v hv)))) :
    LinearExpr v :=
  let ratio := UnitScale.exactRatio u v hv
  {
    bounds := e.bounds.mul (CpsatSolver.Interval.fromValue ratio) mul_nonoverflow
    cpsat := CpsatSolver.LinearExpr.mul e.cpsat ratio mul_nonoverflow
  }

structure FixedSizeInterval (u : UnitScale) where
  start : LinearExpr u
  size : CpsatSolver.Int64
  size_nonneg : (0 : ℤ) ≤ size

structure CumulativeItem (timeline demandU : UnitScale) where
  interval : FixedSizeInterval timeline
  demand : LinearExpr demandU

end CpsatScheduler.UnitAware
