import CpsatScheduler.TaskVars

namespace CpsatScheduler.Objective

open CpsatScheduler
open CpsatSolver

def sumVars (vars : Array IntVar) : Option ((b : Bounds) × LinearExpr b) :=
  vars.foldl (init := none) fun acc v =>
    let cur : (b : Bounds) × LinearExpr b := ⟨_, LinearExpr.var v⟩
    match acc with
    | none => some cur
    | some ⟨b, e⟩ =>
      if h : Int64.Nonoverflow ((b.left : ℤ) + cur.fst.left) ∧
             Int64.Nonoverflow ((b.right : ℤ) + cur.fst.right) then
        some ⟨_, LinearExpr.add e cur.snd h⟩
      else
        none

def minimizeCostSum {scales : Timescales} (varsList : Array (TaskVars scales)) :
    Builder Bool :=
  match sumVars (varsList.map (·.costVar)) with
  | none => pure false
  | some ⟨_, total⟩ => do
    Builder.setObjective (.minimize total.wrapBounds)
    pure true

end CpsatScheduler.Objective

