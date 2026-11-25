module

public import CpsatScheduler.Internal.CpsatSolver.LinearExpr

public section

namespace CpsatSolver.UnitAwareIntVar

def add (a b : UnitAwareIntVar U)
  (_same_scale : a.scale = b.scale)
  (_nonoverflow : Interval.Nonoverflow.Add
    a.intVar.domainHull b.intVar.domainHull) h :=
  LinearExpr.add
    (LinearExpr.var a.intVar)
    (LinearExpr.var b.intVar)
    h

def sub (a b : UnitAwareIntVar U)
  (_same_scale : a.scale = b.scale)
  (_nonoverflow : Interval.Nonoverflow.Add
    a.intVar.domainHull b.intVar.domainHull) h :=
  LinearExpr.sub
    (LinearExpr.var a.intVar)
    (LinearExpr.var b.intVar) h

def neg (a : UnitAwareIntVar U) h :=
  LinearExpr.neg (LinearExpr.var a.intVar) h

def mul (a : UnitAwareIntVar U) (v : Int64) h :=
  LinearExpr.mul (LinearExpr.var a.intVar) v h

def convertExact (a : UnitAwareIntVar U)
  (newScale : Unit.Scale)
  (h : newScale ∣ a.scale.val) nonoverflow :=
  let ratio := Unit.Scale.exactRatio a.scale.val newScale h;
  LinearExpr.mul (LinearExpr.var a.intVar) ratio nonoverflow

def convertTrunc (a : UnitAwareIntVar U)
  (newScale : Unit.Scale)
  (h : a.scale.val ∣ newScale) nonoverflow :=
  let ratio := Unit.Scale.exactRatio newScale a.scale.val h;
  -- have hdiv : 0 < ratio.val := by
  --   unfold ratio
  --   unfold Unit.Scale.exactRatio
  --   dsimp
  --   rw [Unit.instDvdScale, Dvd.dvd, Nat.instDvd] at h
  --   dsimp at h
  --   let ⟨c, h⟩ := h
  --   rw [h]
  --   have h1 : c > 0 := by
  --     let h_ns_pos := newScale.pos
  --     rw [h] at h_ns_pos
  --     let h_as_pos := a.scale.val.pos
  --     exact Nat.pos_of_mul_pos_left h_ns_pos
  --   let h2 := Nat.mul_div_cancel c a.scale.val.pos
  --   grind
  LinearExpr.mul (LinearExpr.var a.intVar) ratio nonoverflow

end CpsatSolver.UnitAwareIntVar
