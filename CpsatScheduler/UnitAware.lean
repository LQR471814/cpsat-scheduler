import CpsatScheduler.UnitScale

namespace CpsatScheduler.UnitAware

structure IntVar (u : UnitScale) where
  var : CpsatSolver.IntVar

def LinearExpr (_ : UnitScale) := CpsatSolver.LinearExpr.WithBounds

def LinearExpr.var {u : UnitScale} (v : IntVar u) : LinearExpr u :=
  ⟨
    v.var.domain.hull,
    CpsatSolver.LinearExpr.var v.var
  ⟩

def LinearExpr.add {u : UnitScale} (a b : LinearExpr u)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((a.fst.left : ℤ) + b.fst.left) ∧
      CpsatSolver.Int64.Nonoverflow ((a.fst.right : ℤ) + b.fst.right)) :
    LinearExpr u :=
  ⟨
    a.fst.add b.fst nonoverflow,
    CpsatSolver.LinearExpr.add a.snd b.snd nonoverflow
  ⟩

def LinearExpr.sub {u : UnitScale} (a b : LinearExpr u)
    (nonoverflow :
      CpsatSolver.Int64.Nonoverflow ((a.fst.left : ℤ) - b.fst.right) ∧
      CpsatSolver.Int64.Nonoverflow ((a.fst.right : ℤ) - b.fst.left)) :
    LinearExpr u :=
  ⟨
    a.fst.sub b.fst nonoverflow,
    CpsatSolver.LinearExpr.sub a.snd b.snd nonoverflow
  ⟩

/-- Exact conversion from a coarser unit `u` to a finer unit `v` by multiplying
by the integral scale ratio `u/v`. -/
def LinearExpr.rescaleExact {u v : UnitScale}
    (e : LinearExpr u) (hv : v.val ∣ u.val)
    (mul_nonoverflow :
      CpsatSolver.Int64.Nonoverflow
        (e.fst.mulLower (CpsatSolver.Interval.fromValue (UnitScale.exactRatio u v hv))) ∧
      CpsatSolver.Int64.Nonoverflow
        (e.fst.mulUpper (CpsatSolver.Interval.fromValue (UnitScale.exactRatio u v hv)))) :
    LinearExpr v :=
  let ratio := UnitScale.exactRatio u v hv
  ⟨
    e.fst.mul (CpsatSolver.Interval.fromValue ratio) mul_nonoverflow,
    CpsatSolver.LinearExpr.mul e.snd ratio mul_nonoverflow
  ⟩

structure FixedSizeInterval (u : UnitScale) where
  start : LinearExpr u
  size : CpsatSolver.Int64
  size_nonneg : (0 : ℤ) ≤ size

structure CumulativeItem (timeline demandU : UnitScale) where
  interval : FixedSizeInterval timeline
  demand : LinearExpr demandU

/-- Coarser conversion from unit `u` to `v` (`u ∣ v`): auxiliary quotient plus
truncating division equality. -/
def truncCoarsen {u v : UnitScale}
    (e : UnitAware.LinearExpr u) (huv : u.val ∣ v.val)
    (label : Option String := none) :
    CpsatSolver.Builder (UnitAware.IntVar v) := do
  let ratio := UnitScale.exactRatio v u huv
  have hdiv : (0 : ℤ) < ratio.val := by
    change (0 : ℤ) < ((v.val / u.val : ℕ) : ℤ)
    have hle : u.val ≤ v.val := Nat.le_of_dvd v.pos huv
    have hpos : 0 < v.val / u.val := Nat.div_pos hle u.pos
    exact_mod_cast hpos
  let quotDomain : CpsatSolver.NonemptyDomain := NonemptyDomain.mk
  let q ← CpsatSolver.Builder.truncCoarsen e.snd ratio hdiv quotDomain label
  pure ⟨q⟩

end CpsatScheduler.UnitAware
