import CpsatScheduler.CpsatSolver.Helpers
import Mathlib.Data.Finset.Lattice.Basic

namespace CpsatSolver

namespace ScriptIDs
private def model := Python.ValidName.mk "model" (by native_decide)
private def solution := Python.ValidName.mk "solution" (by native_decide)
end ScriptIDs

structure Model where
  bools : Finset CpsatSolver.BoolVar
  ints : Finset CpsatSolver.IntVar
  fixedSizeIntervals : Finset CpsatSolver.FixedSizeIntervalVar
  constraints : Finset CpsatSolver.Constraint

def Model.union (left : Model) (right : Model) : Model :=
  {
    bools := left.bools ∪ right.bools,
    ints := left.ints ∪ right.ints,
    fixedSizeIntervals := left.fixedSizeIntervals ∪ right.fixedSizeIntervals,
    constraints := left.constraints ∪ right.constraints
  }

def Model.repr.boolVar
  (m : Model)
  (var : CpsatSolver.BoolVar)
  (_ : var ∈ m.bools) : Python.Expr :=
    Python.Expr.assign (Python.Expr.id var.name) (
      Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id ScriptIDs.model)
          (Python.ValidName.mk "new_bool_var" (by native_decide)))
        #[
          (Python.Expr.lit (Python.Literal.str var.name.val))
        ]
    )

def Model.repr.intVar
  (m : Model)
  (var : CpsatSolver.IntVar)
  (_ : var ∈ m.ints) :=
    Python.Expr.assign (Python.Expr.id var.name) (
      Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id ScriptIDs.model)
          (Python.ValidName.mk "new_int_var" (by native_decide)))
        #[
          (Python.Expr.lit (Python.Literal.int var.domain.min)),
          (Python.Expr.lit (Python.Literal.int var.domain.max)),
          (Python.Expr.lit (Python.Literal.str var.name.val)),
        ]
    )

def Model.repr.fixedSizeIntervalVar
  (m : Model)
  (var : CpsatSolver.FixedSizeIntervalVar)
  (_ : var ∈ m.fixedSizeIntervals) :=
    Python.Expr.assign (Python.Expr.id var.name) (
      Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id ScriptIDs.model)
          (Python.ValidName.mk "new_fixed_size_interval" (by native_decide)))
        #[
          var.start.toPythonExpr,
          (Python.Expr.lit (Python.Literal.int var.size)),
          (Python.Expr.lit (Python.Literal.str var.name.val)),
        ]
    )

def Model.repr.constraint
  (m : Model)
  (cnst : CpsatSolver.Constraint)
  (_ : cnst ∈ m.constraints) :=
    let modelDot (attr : Python.ValidName) : Python.Expr :=
      Python.Expr.dot (Python.Expr.id ScriptIDs.model) attr
    let constraint : Python.Expr := match cnst.variant with
      | Constraint.Variant.bounded_linear expr =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add" (by native_decide)))
          #[ expr.toPythonExpr ]
      | Constraint.Variant.bool_and terms =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_bool_and" (by native_decide)))
          (terms.map (fun t => t.toPythonExpr))
      | Constraint.Variant.bool_or terms =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_bool_or" (by native_decide)))
          (terms.map (fun t => t.toPythonExpr))
      | Constraint.Variant.implication src dst =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_implication" (by native_decide)))
          #[ src.toPythonExpr, dst.toPythonExpr ]
      | Constraint.Variant.max_equality target exprs =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_max_equality" (by native_decide)))
          (Array.append
            #[ target.toPythonExpr ]
            (exprs.map (fun e => e.toPythonExpr)))
      | Constraint.Variant.cumulative intervals demands capacity =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_cumulative" (by native_decide)))
          #[
            (Python.Expr.lit (Python.Literal.array
              (intervals.map (fun e => e.toPythonExpr)))),
            (Python.Expr.lit (Python.Literal.array
              (demands.map (fun e => e.toPythonExpr)))),
            capacity.toPythonExpr,
          ]
      ;
    let labeled :=
      Python.Expr.call
        (Python.Expr.dot
          constraint
          (Python.ValidName.mk "with_label" (by native_decide)))
        #[ (Python.Expr.lit (Python.Literal.str cnst.name.val)) ]
    let enforced := match cnst.enforcement with
      | Constraint.Enforcement.always => labeled
      | Constraint.Enforcement.onlyWhenAll literals =>
        Python.Expr.call
          (Python.Expr.dot
            labeled
            (Python.ValidName.mk "only_enforce_if" (by native_decide)))
          (literals.toArray.map (fun (l : BoolLit) => l.toPythonExpr))
      ;
    enforced

structure SolveRequest (m : Model) where
  ints : Finset CpsatSolver.IntVar
  intsValid : ints ⊆ m.ints
  -- TODO: implement these later
  -- bools : Finset CpsatSolver.BoolVar
  -- boolsValid : bools ⊆ m.bools
  -- fixedSizeIntervals : Finset CpsatSolver.FixedSizeIntervalVar
  -- fixedSizeIntervalsValid : fixedSizeIntervals ⊆ m.fixedSizeIntervals

structure SolveResponse (m : Model) (r : SolveRequest m) where
  ints : Std.HashMap
    { key // ∃ var ∈ m.ints, var.name.val = key }
    { val // CpsatSolver.Int64.Proof val }
  -- TODO: implement these later
  -- bools : Std.HashMap
  --   { key // ∃ var ∈ m.bools, var.name.val = key }
  --   Bool
  -- fixedSizeIntervals : Std.HashMap
  --   { key // ∃ var ∈ m.fixedSizeIntervals, var.name.val = key }
  --   { val // CpsatSolver.Int64.Proof val }

end CpsatSolver

