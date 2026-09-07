import CpsatScheduler.Defs

namespace CpsatScheduler

def Task.costVar {scales : Timescales} (t : Task scales)
  (min max : ℤ) :=
  curryValidName s! "{t.name.val}_cost" (fun name => ({
    name := name
    domain := {
      min := min
      max := max
    }
  } : CpsatSolver.IntVar))

def Task.durationVar {scales : Timescales} (t : Task scales) :=
  curryValidName s! "{t.name.val}_duration" (fun name => ({
    name := name
    domain := {
      min := 0
      max := t.unit
    }
  } : CpsatSolver.IntVar))

end CpsatScheduler
