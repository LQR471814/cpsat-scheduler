import CpsatScheduler.CpsatSolver.Helpers
import Lean.Data.Json.Parser

namespace CpsatSolver

namespace ScriptIDs
private def model := Python.ValidName.mk "model" (by native_decide)
private def solution := Python.ValidName.mk "solution" (by native_decide)
end ScriptIDs

structure Model where
  bools : Array CpsatSolver.BoolVar
  boolsUniqueNames : Var.uniqueNames bools
  ints : Array CpsatSolver.IntVar
  intsUniqueNames : Var.uniqueNames ints
  fixedSizeIntervals : Array CpsatSolver.FixedSizeIntervalVar
  fixedSizeIntervalsUniqueNames : Var.uniqueNames fixedSizeIntervals
  constraints : Array CpsatSolver.Constraint

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

private def Model.Python.boolVar (var : CpsatSolver.BoolVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id ScriptIDs.model)
        (Python.ValidName.mk "new_bool_var" (by native_decide)))
      #[
        (Python.Expr.lit (Python.Literal.str var.name.val))
      ]
  ))

private def Model.Python.intVar (var : CpsatSolver.IntVar) : Python.Statement :=
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

private def Model.Python.fixedSizeIntervalVar
  (var : CpsatSolver.FixedSizeIntervalVar) : Python.Statement :=
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

private def Model.Python.constraint (cnst : CpsatSolver.Constraint) : Python.Statement :=
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
        (literals.map (fun (l : BoolLit) => l.toPythonExpr)).toArray)
    ;
  enforced

structure SolveRequest (m : Model) where
  exprs : Array CpsatSolver.LinearExpr.Proven

structure SolveResponse (m : Model) (r : SolveRequest m) where
  exprs : Vector CpsatSolver.Int64.Proven r.exprs.size
  -- TODO: implement other variables later

namespace Model.Python.Name
private def print := Python.ValidName.mk "print" (by native_decide)
private def json := Python.ValidName.mk "json" (by native_decide)
private def cpModelLib := Python.ValidName.mk "cp_model" (by native_decide)
private def model := Python.ValidName.mk "__cpsat_model__" (by native_decide)
private def cpsatSolver := Python.ValidName.mk "__cpsat_solver__" (by native_decide)
private def solveStatus := Python.ValidName.mk "__solve_status__" (by native_decide)
private def output := Python.ValidName.mk "__output__" (by native_decide)
end Model.Python.Name

private def Model.Python.imports : Array Python.Statement := #[
  -- from ortools.sat.python import cp_model
  (Python.Statement.importLine
    (Python.Import.fromForm
      #[
        (Python.ValidName.mk "ortools" (by native_decide)),
        (Python.ValidName.mk "sat" (by native_decide)),
        (Python.ValidName.mk "python" (by native_decide)),
      ]
      #[ (Python.NameAs.unaliased Model.Python.Name.cpModelLib) ])),
  -- import json
  (Python.Statement.importLine
    (Python.Import.basicForm
      #[ Model.Python.Name.json ]
      Option.none)),
]

private def Model.Python.modelDef (m : Model) : Array Python.Statement :=
  let frontmatter : Array Python.Statement := #[
    -- model = cp_model.Model()
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.model)
      (Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id Model.Python.Name.cpModelLib)
          (Python.ValidName.mk "Model" (by native_decide))
        )
        #[])))
  ];
  let intVars := m.ints.map (Model.Python.intVar ·)
  let boolVars := m.bools.map (Model.Python.boolVar ·)
  let fixedSizeIntervalsVars := m.fixedSizeIntervals.map (Model.Python.fixedSizeIntervalVar ·)
  let constraints := m.constraints.map (Model.Python.constraint ·)
  Array.append
    (Array.append
      (Array.append
        (Array.append frontmatter intVars)
        boolVars)
      fixedSizeIntervalsVars)
    constraints

private def Model.Python.reportSolution
  (m : Model) (req : SolveRequest m) : Array Python.Statement :=
  #[
    -- solver = cp_model.CpSolver()
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.cpsatSolver)
      (Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id Model.Python.Name.cpModelLib)
          (Python.ValidName.mk "CpSolver" (by native_decide)))
        #[]))),
    -- solver.solve(model)
    (Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.cpsatSolver)
        (Python.ValidName.mk "solve" (by native_decide))
      )
      #[ (Python.Expr.id Model.Python.Name.model) ])),
    -- output = [ solver.value()... ]
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.output)
      (Python.Expr.lit (Python.Literal.array
        (req.exprs.map (fun linExpr => Python.Expr.call
          (Python.Expr.dot
            (Python.Expr.id Model.Python.Name.cpsatSolver)
            (Python.ValidName.mk "value" (by native_decide)))
          #[ linExpr.toPythonExpr ])))))),
    -- print(json.dumps(output))
    (Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.id Model.Python.Name.print)
      #[ (Python.Expr.call
          (Python.Expr.dot
            (Python.Expr.id Model.Python.Name.json)
            (Python.ValidName.mk "dumps" (by native_decide)))
          #[ (Python.Expr.id Model.Python.Name.output) ]) ]))
  ]

private def Model.parseScriptOutput
  (m : Model) (r : SolveRequest m) (scriptOutput : String)
  : Except String (SolveResponse m r) :=
  match Lean.Json.parse scriptOutput with
  | .ok json => match json with
    | .arr elems =>
      if h : elems.size = r.exprs.size then
        let results : Except String (Vector Int64.Proven elems.size) :=
          Vector.mapM (fun el => match el with
            | Lean.Json.num no =>
              -- 1. JSON Number's value = mantissa * 10^-exponent
              -- 2. therefore, we expect all resulting values (which must be
              -- ints) to have exponent = 0
              if no.exponent = 0 then
                let num := no.mantissa;
                if h : Int64.Proof num then
                  Except.ok { val := num, proof := h }
                else
                  Except.error "Got out-of-bounds integer in resulting array."
              else
                Except.error "Got floating value in resulting array."
            | _ => Except.error "Unexpected type in resulting array.") elems.toVector
        match results with
        | Except.ok provenResults =>
          Except.ok { exprs := {
            toArray := provenResults.toArray,
            size_toArray := Eq.subst h provenResults.size_toArray
          } }
        | Except.error err => Except.error err
      else
        Except.error s!"Unexpected array.size, got {elems.size}, expected {r.exprs.size}."
    | _ => Except.error "Unexpected JSON type, expected JSON array."
  | .error err => Except.error err

end CpsatSolver

