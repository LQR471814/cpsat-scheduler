import CpsatScheduler.CpsatSolver.Helpers
import Mathlib.Data.Finset.Lattice.Basic
import Mathlib.Data.Finset.Fold
import Mathlib.Data.Finset.Sort
import Mathlib.Data.Nat.SuccPred
import Mathlib.Data.List.Sort
import Mathlib.Algebra.Order.Ring.Nat

namespace CpsatSolver

namespace ScriptIDs
private def model := Python.ValidName.mk "model" (by native_decide)
private def solution := Python.ValidName.mk "solution" (by native_decide)
end ScriptIDs

def Var.uniqueNames {α : Type} [Var α] (ls : List α) :=
  ∀ a b : Fin ls.length, a ≠ b → (Var.name (ls.get a)) ≠ (Var.name (ls.get b))

structure Model where
  bools : List CpsatSolver.BoolVar
  boolsUniqueNames : Var.uniqueNames bools
  ints : List CpsatSolver.IntVar
  intsUniqueNames : Var.uniqueNames ints
  fixedSizeIntervals : List CpsatSolver.FixedSizeIntervalVar
  fixedSizeIntervalsUniqueNames : Var.uniqueNames fixedSizeIntervals
  constraints : List CpsatSolver.Constraint

def Model.union (left : Model) (right : Model)
  (boolsUniqueNames : Var.uniqueNames (left.bools ++ right.bools))
  (intsUniqueNames : Var.uniqueNames (left.ints ++ right.ints))
  (fixedSizeIntervalsUniqueNames :
    Var.uniqueNames (left.fixedSizeIntervals ++ right.fixedSizeIntervals))
  : Model :=
  {
    bools := left.bools ++ right.bools,
    boolsUniqueNames := boolsUniqueNames,
    ints := left.ints ++ right.ints,
    intsUniqueNames := intsUniqueNames,
    fixedSizeIntervals := left.fixedSizeIntervals ++ right.fixedSizeIntervals,
    fixedSizeIntervalsUniqueNames := fixedSizeIntervalsUniqueNames,
    constraints := left.constraints ++ right.constraints
  }

def Model.repr.boolVar (var : CpsatSolver.BoolVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id ScriptIDs.model)
        (Python.ValidName.mk "new_bool_var" (by native_decide)))
      #[
        (Python.Expr.lit (Python.Literal.str var.name.val))
      ]
  ))

def Model.repr.intVar (var : CpsatSolver.IntVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id ScriptIDs.model)
        (Python.ValidName.mk "new_int_var" (by native_decide)))
      #[
        (Python.Expr.lit (Python.Literal.int var.domain.min)),
        (Python.Expr.lit (Python.Literal.int var.domain.max)),
        (Python.Expr.lit (Python.Literal.str var.name.val)),
      ]
  ))

def Model.repr.fixedSizeIntervalVar (var : CpsatSolver.FixedSizeIntervalVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id ScriptIDs.model)
        (Python.ValidName.mk "new_fixed_size_interval" (by native_decide)))
      #[
        var.start.toPythonExpr,
        (Python.Expr.lit (Python.Literal.int var.size)),
        (Python.Expr.lit (Python.Literal.str var.name.val)),
      ]
  ))

def Model.repr.constraint (cnst : CpsatSolver.Constraint) : Python.Statement :=
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
    | Constraint.Enforcement.always => Python.Statement.exprLine labeled
    | Constraint.Enforcement.onlyWhenAll literals =>
      Python.Statement.exprLine (Python.Expr.call
        (Python.Expr.dot
          labeled
          (Python.ValidName.mk "only_enforce_if" (by native_decide)))
        (literals.toArray.map (fun (l : BoolLit) => l.toPythonExpr)))
    ;
  enforced

structure SolveRequest (m : Model) where
  exprs : List CpsatSolver.LinearExpr.Proven

structure SolveResponse (m : Model) (r : SolveRequest m) where
  exprs : List CpsatSolver.Int64.Proven
  exprsValid : exprs.length = r.exprs.length
  -- TODO: implement other variables later

private def namePrint := Python.ValidName.mk "print" (by native_decide)
private def nameJson := Python.ValidName.mk "json" (by native_decide)
private def nameCpModelLib := Python.ValidName.mk "cp_model" (by native_decide)
private def nameModel := Python.ValidName.mk "__cpsat_model__" (by native_decide)
private def nameCpsatSolver := Python.ValidName.mk "__cpsat_solver__" (by native_decide)
private def nameSolveStatus := Python.ValidName.mk "__solve_status__" (by native_decide)
private def nameOutput := Python.ValidName.mk "__output__" (by native_decide)
private def outKeyInts := Python.Literal.str "ints"
private def outKeyBools := Python.Literal.str "bools"
private def outKeyExprs := Python.Literal.str "exprs"

def Model.python.imports : Array Python.Statement := #[
  -- from ortools.sat.python import cp_model
  (Python.Statement.importLine
    (Python.Import.fromForm
      #[
        (Python.ValidName.mk "ortools" (by native_decide)),
        (Python.ValidName.mk "sat" (by native_decide)),
        (Python.ValidName.mk "python" (by native_decide)),
      ]
      #[ (Python.NameAs.unaliased nameCpModelLib) ])),
  -- import json
  (Python.Statement.importLine
    (Python.Import.basicForm
      #[ nameJson ]
      Option.none)),
]

def Model.python.modelDef (m : Model) : Array Python.Statement :=
  let frontmatter : Array Python.Statement := #[
    -- model = cp_model.Model()
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id nameModel)
      (Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id nameCpModelLib)
          (Python.ValidName.mk "Model" (by native_decide))
        )
        #[])))
  ];
  let intVars := m.ints.map (Model.repr.intVar ·)
  let boolVars := m.bools.map (Model.repr.boolVar ·)
  let fixedSizeIntervalsVars := m.fixedSizeIntervals.map (Model.repr.fixedSizeIntervalVar ·)
  let constraints := m.constraints.map (Model.repr.constraint ·)
  Array.append
    (Array.append
      (Array.append
        (Array.append frontmatter intVars.toArray)
        boolVars.toArray)
      fixedSizeIntervalsVars.toArray)
    constraints.toArray

def Model.python.solve (m : Model) (req : SolveRequest m) : Array Python.Statement :=
  #[
    -- solver = cp_model.CpSolver()
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id nameCpsatSolver)
      (Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id nameCpModelLib)
          (Python.ValidName.mk "CpSolver" (by native_decide)))
        #[]))),
    -- solver.solve(model)
    (Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id nameCpsatSolver)
        (Python.ValidName.mk "solve" (by native_decide))
      )
      #[ (Python.Expr.id nameModel) ])),
    -- output = [ solver.value()... ]
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.index
        (Python.Expr.id nameOutput)
        (Python.Expr.lit outKeyInts))
      (Python.Expr.lit (Python.Literal.array
        (req.exprs.map (fun linExpr => Python.Expr.call
          (Python.Expr.dot
            (Python.Expr.id nameCpsatSolver)
            (Python.ValidName.mk "value" (by native_decide)))
          #[ linExpr.toPythonExpr ])).toArray)))),
    -- print(json.dumps(output))
    (Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.id namePrint)
      #[ (Python.Expr.call
          (Python.Expr.dot
            (Python.Expr.id nameJson)
            (Python.ValidName.mk "dumps" (by native_decide)))
          #[ (Python.Expr.id nameOutput) ]) ]))
  ]

end CpsatSolver

