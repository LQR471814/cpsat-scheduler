import CpsatScheduler.CpsatSolver.Domain.NonemptyDomain
import CpsatScheduler.Defs

namespace Constraint.PERT

open CpsatSolver

structure Config where
  steps : ℕ
  steps_nonzero : steps > 0

def steps (c : Config) (opt exp pes : Float) :=
  let step :=

def costVarDomain (c : Config) : CpsatSolver.NonemptyDomain :=
  {
    domain := Domain.ofValues
  }

end Constraint.PERT


