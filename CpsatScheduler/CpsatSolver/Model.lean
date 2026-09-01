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

structure SolveRequest (model : Model) where
  exprs : Array CpsatSolver.LinearExpr.Proven

inductive SolveStatus where
  | unknown
  | infeasible
  | modelInvalid
  | feasible
  | optimal

structure SolveResponse (model : Model) (req : SolveRequest model) where
  objectiveValue : ℤ
  status : SolveStatus
  exprs : Vector CpsatSolver.Int64.Proven req.exprs.size

namespace Model.Python.Name
private def print := Python.ValidName.mk "print" (by native_decide)
private def json := Python.ValidName.mk "json" (by native_decide)
private def cpModelLib := Python.ValidName.mk "cp_model" (by native_decide)
private def model := Python.ValidName.mk "__cpsat_model__" (by native_decide)
private def cpsatSolver := Python.ValidName.mk "__cpsat_solver__" (by native_decide)
private def solveStatus := Python.ValidName.mk "__solve_status__" (by native_decide)
private def output := Python.ValidName.mk "__output__" (by native_decide)
end Model.Python.Name

namespace Model.Python.Literals
private def exprs := "exprs"
private def status := "status"
private def objectiveValue := "objective_value"
end Model.Python.Literals

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

private def Model.Python.modelDef (model : Model) : Array Python.Statement :=
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
  let intVars := model.ints.map (Model.Python.intVar ·)
  let boolVars := model.bools.map (Model.Python.boolVar ·)
  let fixedSizeIntervalsVars := model.fixedSizeIntervals.map (Model.Python.fixedSizeIntervalVar ·)
  let constraints := model.constraints.map (Model.Python.constraint ·)
  Array.append
    (Array.append
      (Array.append
        (Array.append frontmatter intVars)
        boolVars)
      fixedSizeIntervalsVars)
    constraints

private def Model.Python.reportSolution
  (model : Model) (req : SolveRequest model) : Array Python.Statement :=
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
    -- output = {
    --   "exprs": [ solver.value()... ]
    --   "status": str(status)
    --   "objective_value": solver.objective_value
    -- }
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.output)
      (Python.Expr.lit (Python.Literal.dict
        #[
          (Prod.mk
            (Python.Expr.lit (Python.Literal.str Model.Python.Literals.exprs))
            (Python.Expr.lit (Python.Literal.array
              (req.exprs.map (fun linExpr => Python.Expr.call
                (Python.Expr.dot
                  (Python.Expr.id Model.Python.Name.cpsatSolver)
                  (Python.ValidName.mk "value" (by native_decide)))
                #[ linExpr.toPythonExpr ]))))),
          (Prod.mk
            (Python.Expr.lit (Python.Literal.str Model.Python.Literals.status))
            (Python.Expr.call
              (Python.Expr.id (Python.ValidName.mk "str" (by native_decide)))
              #[ (Python.Expr.id Model.Python.Name.solveStatus) ])),
          (Prod.mk
            (Python.Expr.lit (Python.Literal.str Model.Python.Literals.objectiveValue))
            (Python.Expr.dot
              (Python.Expr.id Model.Python.Name.cpsatSolver)
              (Python.ValidName.mk "objective_value" (by native_decide))))
        ]
      ))
      )),
    -- print(json.dumps(output))
    (Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.id Model.Python.Name.print)
      #[ (Python.Expr.call
          (Python.Expr.dot
            (Python.Expr.id Model.Python.Name.json)
            (Python.ValidName.mk "dumps" (by native_decide)))
          #[ (Python.Expr.id Model.Python.Name.output) ]) ]))
  ]

private def parseJsonInteger (json : Lean.Json) : Except String ℤ :=
  match json with
  | .num num =>
    if num.exponent = 0 then
      Except.ok num.mantissa
    else
      Except.error "Expected no decimal numbers."
  | _ => Except.error "Expected number type."

private def Model.parseScriptOutput
  (model : Model) (req : SolveRequest model) (scriptOutput : String)
  : Except String (SolveResponse model req) :=
  let parseStatus (map : Std.TreeMap.Raw String Lean.Json compare)
    : Except String SolveStatus :=
    match map.get? Model.Python.Literals.status with
    | .none => Except.error "Missing value."
    | .some statusJson => match statusJson with
      | .str statusStr =>
        Except.ok (match statusStr with
          | "INFEASIBLE" => SolveStatus.infeasible
          | "MODEL_INVALID" => SolveStatus.modelInvalid
          | "FEASIBLE" => SolveStatus.feasible
          | "OPTIMAL" => SolveStatus.optimal
          | _ => SolveStatus.unknown)
      | _ => Except.error "Expected string.";
  let parseObjectiveValue (map : Std.TreeMap.Raw String Lean.Json compare)
    : Except String ℤ :=
    match map.get? Model.Python.Literals.objectiveValue with
    | .some objectiveValueJson => match parseJsonInteger objectiveValueJson with
      | .ok objectiveValue => Except.ok objectiveValue
      | .error err => Except.error s!"Parse integer: {err}"
    | .none => Except.error "Missing value."
  let parseExprs (map : Std.TreeMap.Raw String Lean.Json compare)
    : Except String (Vector CpsatSolver.Int64.Proven req.exprs.size) :=
    match map.get? Model.Python.Literals.exprs with
    | .some exprsJson => match exprsJson with
      | .arr array =>
        if h : array.size = req.exprs.size then
          Vector.mapM
            (fun el => match parseJsonInteger el with
              | .ok num =>
                if h : Int64.Proof num then
                  Except.ok { val := num, proof := h }
                else
                  Except.error "Got out-of-bounds integer in resulting array."
              | .error err => Except.error s!"Parse Integer: {err}")
            {
              toArray := array,
              size_toArray := h
            }
        else
          Except.error ""
      | _ => Except.error "Expected array."
    | .none => Except.error "Missing value."
  match Lean.Json.parse scriptOutput with
  | .ok json => match json with
    | .obj map => match
      (parseStatus map),
      (parseObjectiveValue map),
      (parseExprs map) with
      | .ok status, .ok objectiveValue, .ok exprs =>
        Except.ok {
          status := status
          objectiveValue := objectiveValue
          exprs := exprs
        }
      | .error err, _, _ => Except.error s!"Parse 'status': {err}"
      | _, .error err, _ => Except.error s!"Parse 'objective_value': {err}"
      | _, _, .error err => Except.error s!"Parse 'exprs': {err}"
    | _ => Except.error "Unexpected JSON type, expected JSON object at root."
  | .error err => Except.error s!"Parse JSON: {err}"

def Model.solve
  (model : Model)
  (pythonRuntime : Python.Runtime)
  (req : SolveRequest model) : IO (Except String (SolveResponse model req)) := do
  let script : Python.Script := {
    statements := Array.append
      (Array.append
        Model.Python.imports
        (Model.Python.modelDef model))
      (Model.Python.reportSolution model req)
  }
  let out <- Python.Script.exec pythonRuntime script
  return Model.parseScriptOutput model req out.stdout

end CpsatSolver

