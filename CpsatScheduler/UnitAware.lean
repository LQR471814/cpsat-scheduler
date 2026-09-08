import CpsatScheduler.TaskStart

namespace CpsatScheduler.UnitAware

structure LinearExpr (units : Units) where
  cpsat : CpsatSolver.LinearExpr.Proven
  unit : units.set
  deriving DecidableEq

private def Task.startIntVar {scales : Timescales} (t : Task scales) :=
  curryValidName s! "{t.name.val}_start" (fun name => ({
    name := name
    domain := {
      min := t.startBeforeTime.coeff * t.startAfterTime.unit
      max := t.startAfterTime.coeff * t.startAfterTime.unit
    }
  } : CpsatSolver.IntVar))

def Task.start {scales : Timescales} (task : Task scales) :=
  fun hname hvar =>
    ({
      cpsat := CpsatSolver.LinearExpr.var
        (Task.startIntVar task hname)
        hvar
      unit := task.unit
    } : LinearExpr scales.units)

def LinearExpr.add {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun hmin hmax => ({
    cpsat := CpsatSolver.LinearExpr.add
      a.cpsat b.cpsat hmin hmax
    unit := a.unit
  } : LinearExpr units)

def LinearExpr.sub {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun hmin hmax => ({
    cpsat := CpsatSolver.LinearExpr.sub
      a.cpsat b.cpsat hmin hmax
    unit := a.unit
  } : LinearExpr units)

def LinearExpr.mul {units : Units}
  (a b : LinearExpr units) (_ : a.unit = b.unit) :=
  fun hmin hmax => ({
    cpsat := CpsatSolver.LinearExpr.mul
      a.cpsat b.cpsat hmin hmax
    unit := a.unit
  } : LinearExpr units)

structure BoundedLinearExpr (units : Units) where
  op : CpsatSolver.BoundedLinearExpr.Op
  left : LinearExpr units
  right : LinearExpr units
  units_eq : left.unit = right.unit
  no_contradict : CpsatSolver.BoundedLinearExpr.NoContradict op left.cpsat right.cpsat
  deriving DecidableEq

def BoundedLinearExpr.cpsat {units : Units}
  (b : BoundedLinearExpr units) : CpsatSolver.BoundedLinearExpr :=
    {
      op := b.op
      left := b.left.cpsat
      right := b.right.cpsat
      no_contradict := b.no_contradict
    }

inductive Constraint.Variant (units : Units) where
  | bounded_linear (expr : BoundedLinearExpr units)
  | max_equality (target : LinearExpr units) (exprs : Array (LinearExpr units))
  | cumulative
    (intervals : Array CpsatSolver.FixedSizeIntervalVar)
    (demands : Array (LinearExpr units))
    (capacity : (LinearExpr units))
  deriving DecidableEq

structure Constraint (units : Units) where
  name : CpsatSolver.Python.ValidName
  enforcement : CpsatSolver.Constraint.Enforcement
  variant : Constraint.Variant units
  deriving DecidableEq

end CpsatScheduler.UnitAware
