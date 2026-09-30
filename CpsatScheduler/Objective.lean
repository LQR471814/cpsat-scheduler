import CpsatScheduler.TaskVars

namespace CpsatScheduler.Objective

open CpsatScheduler
open CpsatSolver

private def costSumInner? (vars : Array (TaskVars S)) :
    Option LinearExpr.WithBounds :=
  vars.foldl (init := none) fun acc v =>
    let cur : LinearExpr.WithBounds :=
      ⟨_, LinearExpr.var v.costVar⟩
    match acc with
    | none => some cur
    | some ⟨b, e⟩ =>
      if h : LinearExpr.Nonoverflow.Add b cur.fst then
        some ⟨_, LinearExpr.add e cur.snd h⟩
      else
        none

private abbrev SafeCostSum (vars : Array (TaskVars S)) :=
  (costSumInner? vars).isSome = true

def costSumExpr (vars : Array (TaskVars S))
  (h : SafeCostSum vars := by decide) :
    LinearExpr.WithBounds :=
  (costSumInner? vars).get h

private def normalizedStart (v : TaskVars S) :
    Option LinearExpr.WithBounds :=
  let u : UnitScale := v.task.unit.val
  let expr := LinearExpr.mul
    (LinearExpr.var v.startVar)
    ⟨u.val, u.nonoverflow⟩
    h
  ⟨_, ⟩

private def startSumInner? (vars : Array (TaskVars S)) :
    Option LinearExpr.WithBounds :=
  vars.foldl (init := none) fun acc v =>
    let cur : LinearExpr.WithBounds :=
      ⟨_, (LinearExpr.var v.startVar)⟩
    match acc with
    | none => some cur
    | some ⟨b, e⟩ =>
      if h : Int64.Nonoverflow ((b.left : ℤ) + cur.fst.left) ∧
             Int64.Nonoverflow ((b.right : ℤ) + cur.fst.right) then
        some ⟨_, LinearExpr.add e cur.snd h⟩
      else
        none

private abbrev startsOf (vars : Array (TaskVars S)) :=
  vars.map (·.startVar)

def startSumExpr (vars : Array (TaskVars S))
  (h : SafeIntVarSum (startsOf vars) := by decide) :
    LinearExpr.WithBounds :=
  intSumExpr (startsOf vars) h

end CpsatScheduler.Objective

