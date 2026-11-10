import CpsatSolver.Defs
import CpsatSolver.LinearExpr

import Mathlib.Algebra.Order.Module.Defs
import Mathlib.Algebra.Order.GroupWithZero.Defs
import Mathlib.Tactic.LinearCombination.Lemmas
import Mathlib.Algebra.Order.Group.Unbundled.Basic

namespace CpsatSolver.UnitAwareIntVar

def add (a b : UnitAwareIntVar U)
  (_same_scale : a.scale = b.scale)
  (nonoverflow : LinearExpr.Nonoverflow.Add
    a.intVar.domainHull b.intVar.domainHull) :=
  LinearExpr.add
    (LinearExpr.var a.intVar)
    (LinearExpr.var b.intVar)
    nonoverflow

def sub (a b : UnitAwareIntVar U)
  (_same_scale : a.scale = b.scale)
  (nonoverflow : LinearExpr.Nonoverflow.Sub
    a.intVar.domainHull b.intVar.domainHull) :=
  LinearExpr.sub
    (LinearExpr.var a.intVar)
    (LinearExpr.var b.intVar)
    nonoverflow

def neg (a : UnitAwareIntVar U)
  (nonoverflow : LinearExpr.Nonoverflow.Neg a.intVar.domainHull) :=
  LinearExpr.neg (LinearExpr.var a.intVar) nonoverflow

def mul (a : UnitAwareIntVar U) (v : Int64)
  (nonoverflow : LinearExpr.Nonoverflow.Mul a.intVar.domainHull v) :=
  LinearExpr.mul (LinearExpr.var a.intVar) v nonoverflow

def convertExact (a : UnitAwareIntVar U)
  (newScale : Unit.Scale)
  (h : newScale ∣ a.scale.val)
  (nonoverflow : LinearExpr.Nonoverflow.Mul a.intVar.domainHull
    (Unit.Scale.exactRatio a.scale.val newScale h)) :=
  let ratio := Unit.Scale.exactRatio a.scale.val newScale h;
  LinearExpr.mul (LinearExpr.var a.intVar) ratio nonoverflow

def convertTrunc (a : UnitAwareIntVar U)
  (newScale : Unit.Scale)
  (h : a.scale.val ∣ newScale)
  (nonoverflow : LinearExpr.Nonoverflow.Mul a.intVar.domainHull
    (Unit.Scale.exactRatio newScale a.scale.val h)) :=
  let ratio := Unit.Scale.exactRatio newScale a.scale.val h;
  LinearExpr.mul (LinearExpr.var a.intVar) ratio nonoverflow

end CpsatSolver.UnitAwareIntVar
