import Std.Time
import Mathlib.Algebra.Order.Ring.Defs

import CpsatScheduler.Task

namespace CpsatScheduler.Schedule

open CpsatScheduler
open CpsatSolver

/-- schedule time, converted to and from real time (Std.Time) -/
@[ext]
structure Time where
  val : ℤ
  unit : Unit.Scale
  nonneg : 0 ≤ val
  le_max : val ≤ CpsatSolver.Int64.max
deriving DecidableEq

def Duration := Time

structure Config where
  /-- the unix time treated as time 0 in schedule time -/
  reference : Std.Time.Timestamp
  /-- the real time duration of the atomic unit (1) in schedule time -/
  atomicDur : Std.Time.Duration
  atomic_dur_pos : atomicDur > 0

end CpsatScheduler.Schedule

