import LeanCpsatScheduler.CpsatSolver.Int

namespace CpsatSolver

-- BoolVar is a boolean variable
structure BoolVar where
  name : String

-- Intvar is an integer variable bounded to a finite domain
structure IntVar where
  name : String
  domain : CpsatSolver.Interval

def IntVar.Proof (var : IntVar) :=
  Interval.Proof var.domain

instance : Decidable (IntVar.Proof α) :=
  (inferInstance : Decidable (CpsatSolver.Interval.Proof α.domain))

def IntVar.repr (var : IntVar) :=
  var.name

end CpsatSolver
