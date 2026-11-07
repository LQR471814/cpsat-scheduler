import CpsatScheduler.TaskVars

namespace CpsatScheduler.Objective

open CpsatScheduler
open CpsatSolver

abbrev weightedSum.Terms := Array (CpsatSolver.Int64 × IntVar)

def weightedSum.NoParamOverflow (ts : weightedSum.Terms) : Prop :=
  ∀ t ∈ ts, LinearExpr.Nonoverflow.Mul t.snd.domainHull t.fst

def weightedSum.SumNoOverflow (ts : weightedSum.Terms) : Prop :=
  ts.foldl
    (fun acc t => sorry)
    (LinearExpr.Nonoverflow.Add )

end CpsatScheduler.Objective

