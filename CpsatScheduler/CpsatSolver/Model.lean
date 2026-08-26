import LeanSearchClient
import CpsatScheduler.CpsatSolver.Constraint

namespace CpsatSolver

structure Model where
  boolVars : List CpsatSolver.BoolVar
  intVars : List CpsatSolver.IntVar
  constraints : List CpsatSolver.Constraint

-- TODO: add an "extend model" function that extends a model with additional
-- definitions or constraints

-- TODO: add a structure representing a "solve request" along with "queries"
-- for information in the solution

end CpsatSolver

