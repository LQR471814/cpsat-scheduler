import CpsatScheduler.CpsatSolver.Helpers

import Lean.Data.Json.Parser

namespace CpsatSolver

namespace Model.Python.Name
private def print := Python.ValidName.mk "print" (by decide)
private def json := Python.ValidName.mk "json" (by decide)
private def cpModelLib := Python.ValidName.mk "cp_model" (by decide)
private def model := Python.ValidName.mk "__cpsat_model__" (by decide)
private def cpsatSolver := Python.ValidName.mk "__cpsat_solver__" (by decide)
private def solveStatus := Python.ValidName.mk "__solve_status__" (by decide)
private def output := Python.ValidName.mk "__output__" (by decide)
end Model.Python.Name

namespace Model.Python.Literals
private def exprs := "exprs"
private def status := "status"
private def objectiveValue := "objective_value"
end Model.Python.Literals

structure Model where
  bools : Array CpsatSolver.BoolVar
  boolsUniqueNames : Var.uniqueNames bools
  ints : Array CpsatSolver.IntVar
  intsUniqueNames : Var.uniqueNames ints
  fixedSizeIntervals : Array CpsatSolver.FixedSizeIntervalVar
  fixedSizeIntervalsUniqueNames : Var.uniqueNames fixedSizeIntervals
  constraints : Array CpsatSolver.Constraint

namespace Model

def declaredInts (model : Model) : Finset IntVar :=
  model.ints.foldl (fun acc value => acc ∪ {value}) ∅

/-- All integer variables mentioned by a model are declared by that model. -/
def ReferencesWellFormed (model : Model) : Prop :=
  ∀ i : Fin model.constraints.size,
    (model.constraints[i]).intVars ⊆ model.declaredInts

structure Assignment (model : Model) where
  value : Python.ValidName → ℤ
  inDomain : ∀ v ∈ model.declaredInts,
    (v.domain.left : ℤ) ≤ value v.name ∧ value v.name ≤ v.domain.right

end Model

namespace LinearExpr

@[simp] theorem intVars_var (value : IntVar) :
    (LinearExpr.var value).intVars = {value} := by
  rfl

def eval {model : Model} (assignment : model.Assignment)
    {domain : Interval} : LinearExpr domain → ℤ
  | .fromVar value => assignment.value value.name
  | .fromConst value => value.val
  | .fromNeg a _ _ _ => -eval assignment a
  | .fromMulConst a value _ _ _ => value.val * eval assignment a
  | .fromAdd a b _ _ _ => eval assignment a + eval assignment b
  | .fromSub a b _ _ _ => eval assignment a - eval assignment b

@[simp] theorem eval_fromVar {model : Model} (assignment : model.Assignment)
    (value : IntVar) : eval assignment (.fromVar value) = assignment.value value.name := rfl

@[simp] theorem eval_fromConst {model : Model} (assignment : model.Assignment)
    (value : Int64) : eval assignment (.fromConst value) = value.val := rfl

@[simp] theorem eval_fromNeg {model : Model} (assignment : model.Assignment)
    (a : LinearExpr α) (domain negNonoverflow domainIsNeg) :
    eval assignment (.fromNeg a domain negNonoverflow domainIsNeg) = -eval assignment a := rfl

@[simp] theorem eval_fromMulConst {model : Model} (assignment : model.Assignment)
    (a : LinearExpr α) (value : Int64) (domain mulNonoverflow domainIsMul) :
    eval assignment (.fromMulConst a value domain mulNonoverflow domainIsMul) =
      value.val * eval assignment a := rfl

@[simp] theorem eval_fromAdd {model : Model} (assignment : model.Assignment)
    (a : LinearExpr α) (b : LinearExpr β) (domain addNonoverflow domainIsAdd) :
    eval assignment (.fromAdd a b domain addNonoverflow domainIsAdd) =
      eval assignment a + eval assignment b := rfl

@[simp] theorem eval_fromSub {model : Model} (assignment : model.Assignment)
    (a : LinearExpr α) (b : LinearExpr β) (domain subNonoverflow domainIsSub) :
    eval assignment (.fromSub a b domain subNonoverflow domainIsSub) =
      eval assignment a - eval assignment b := rfl

def meaning {model : Model} {domain : Interval} (expr : LinearExpr domain) :
    Set (model.Assignment × ℤ) :=
  {pair | pair.2 = expr.eval pair.1}

def possibleValues {model : Model} {domain : Interval} (expr : LinearExpr domain) : Set ℤ :=
  {value | ∃ assignment : model.Assignment, (assignment, value) ∈ expr.meaning}

theorem meaning_eq_iff {model : Model} {α β : Interval}
    (a : LinearExpr α) (b : LinearExpr β) :
    @meaning model α a = @meaning model β b ↔ ∀ assignment : model.Assignment,
      a.eval assignment = b.eval assignment := by
  constructor
  · intro h assignment
    have := Set.ext_iff.mp h (assignment, a.eval assignment)
    simpa [meaning] using this.mp rfl
  · intro h
    ext pair
    simp [meaning, h]

theorem meaning_double_neg {model : Model} {α d₁ d₂ : Interval}
    (a : LinearExpr α)
    (h₁ : Int64.Nonoverflow (-α.right : ℤ) ∧ Int64.Nonoverflow (-α.left : ℤ))
    (e₁ : α.neg h₁ = d₁)
    (h₂ : Int64.Nonoverflow (-d₁.right : ℤ) ∧ Int64.Nonoverflow (-d₁.left : ℤ))
    (e₂ : d₁.neg h₂ = d₂) :
    @meaning model d₂ (LinearExpr.fromNeg (LinearExpr.fromNeg a d₁ h₁ e₁) d₂ h₂ e₂) =
      @meaning model α a := by
  apply (@meaning_eq_iff model d₂ α _ _).mpr
  intro assignment
  simp

theorem meaning_add_sub_cancel {model : Model} {α β γ δ : Interval}
    (a : LinearExpr α) (b : LinearExpr β)
    (hAdd : Int64.Nonoverflow ((α.left : ℤ) + β.left) ∧
      Int64.Nonoverflow ((α.right : ℤ) + β.right))
    (eAdd : α.add β hAdd = γ)
    (hSub : Int64.Nonoverflow ((γ.left : ℤ) - β.right) ∧
      Int64.Nonoverflow ((γ.right : ℤ) - β.left))
    (eSub : γ.sub β hSub = δ) :
    @meaning model δ (LinearExpr.fromSub (LinearExpr.fromAdd a b γ hAdd eAdd) b δ hSub eSub) =
      @meaning model α a := by
  apply (@meaning_eq_iff model δ α _ _).mpr
  intro assignment
  simp

theorem meaning_sub_self {model : Model} {α β : Interval}
    (a : LinearExpr α)
    (hSub : Int64.Nonoverflow ((α.left : ℤ) - α.right) ∧
      Int64.Nonoverflow ((α.right : ℤ) - α.left))
    (eSub : α.sub α hSub = β) :
    @meaning model β (LinearExpr.fromSub a a β hSub eSub) =
      @meaning model (Interval.fromValue { val := 0, nonoverflow := by decide })
        (LinearExpr.fromConst { val := 0, nonoverflow := by decide }) := by
  apply (@meaning_eq_iff model β
    (Interval.fromValue { val := 0, nonoverflow := by decide }) _ _).mpr
  intro assignment
  simp

theorem eval_mem_domain {model : Model} (assignment : model.Assignment)
    {domain : Interval} (expr : LinearExpr domain)
    (referencesDeclared : expr.intVars ⊆ model.declaredInts) :
    (domain.left : ℤ) ≤ expr.eval assignment ∧ expr.eval assignment ≤ domain.right := by
  induction expr with
  | fromVar value =>
    obtain ⟨left, right⟩ := assignment.inDomain value
      (referencesDeclared (by
        change value ∈ ({value} : Finset IntVar)
        simp))
    exact ⟨left, right⟩
  | fromConst value =>
    change (value.val : ℤ) ≤ value.val ∧ value.val ≤ value.val
    exact ⟨le_rfl, le_rfl⟩
  | fromNeg a domain negNonoverflow domainIsNeg ih =>
    have bounds := ih (by
      intro v hv
      exact referencesDeclared (by simp [LinearExpr.intVars, hv]))
    have hleft := congrArg (fun i : Interval => (i.left : ℤ)) domainIsNeg
    have hright := congrArg (fun i : Interval => (i.right : ℤ)) domainIsNeg
    simp [Interval.neg] at hleft hright
    simp [eval]
    constructor <;> linarith [bounds.1, bounds.2, hleft, hright]
  | fromMulConst a value domain mulNonoverflow domainIsMul ih =>
    have bounds := ih referencesDeclared
    have resultBounds := Interval.mul_const_mem _ value
      (eval assignment a) bounds
    have hleft := congrArg (fun i : Interval => (i.left : ℤ)) domainIsMul
    have hright := congrArg (fun i : Interval => (i.right : ℤ)) domainIsMul
    simp [Interval.mul, Interval.ofBounds] at hleft hright
    simp [eval]
    constructor <;> linarith [resultBounds.1, resultBounds.2, hleft, hright]
  | fromAdd a b domain addNonoverflow domainIsAdd ihA ihB =>
    have boundsA := ihA (by
      intro v hv
      exact referencesDeclared (by simp [LinearExpr.intVars, hv]))
    have boundsB := ihB (by
      intro v hv
      exact referencesDeclared (by simp [LinearExpr.intVars, hv]))
    have hleft := congrArg (fun i : Interval => (i.left : ℤ)) domainIsAdd
    have hright := congrArg (fun i : Interval => (i.right : ℤ)) domainIsAdd
    simp [Interval.add, Interval.ofBounds] at hleft hright
    simp [eval]
    constructor <;> linarith [boundsA.1, boundsA.2, boundsB.1, boundsB.2, hleft, hright]
  | fromSub a b domain subNonoverflow domainIsSub ihA ihB =>
    have boundsA := ihA (by
      intro v hv
      exact referencesDeclared (by simp [LinearExpr.intVars, hv]))
    have boundsB := ihB (by
      intro v hv
      exact referencesDeclared (by simp [LinearExpr.intVars, hv]))
    have hleft := congrArg (fun i : Interval => (i.left : ℤ)) domainIsSub
    have hright := congrArg (fun i : Interval => (i.right : ℤ)) domainIsSub
    simp [Interval.sub, Interval.ofBounds] at hleft hright
    simp [eval]
    constructor <;> linarith [boundsA.1, boundsA.2, boundsB.1, boundsB.2, hleft, hright]

end LinearExpr

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
        (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "new_bool_var" (by decide)))
      #[
        (Python.Expr.lit (Python.Literal.str var.name.val))
      ]
  ))

private def Model.Python.intVar (var : CpsatSolver.IntVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "new_int_var" (by decide)))
      #[
        (Python.Expr.lit (Python.Literal.int var.domain.left)),
        (Python.Expr.lit (Python.Literal.int var.domain.right)),
        (Python.Expr.lit (Python.Literal.str var.name.val)),
      ]
  ))

private def Model.Python.fixedSizeIntervalVar
  (var : CpsatSolver.FixedSizeIntervalVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "new_fixed_size_interval" (by decide)))
      #[
        (@LinearExpr.toPythonExpr var.startDomain var.start),
        (Python.Expr.lit (Python.Literal.int var.size)),
        (Python.Expr.lit (Python.Literal.str var.name.val)),
      ]
  ))

private def Model.Python.constraint (cnst : CpsatSolver.Constraint) : Python.Statement :=
  let sigmaExprToPython (e : LinearExpr.WithDomain) : Python.Expr :=
    @LinearExpr.toPythonExpr e.fst e.snd
  let modelDot (attr : Python.ValidName) : Python.Expr :=
    Python.Expr.dot (Python.Expr.id Model.Python.Name.model) attr
  let constraint : Python.Expr := match cnst.variant with
    | Constraint.Variant.bounded_linear expr =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add" (by decide)))
        #[ expr.toPythonExpr ]
    | Constraint.Variant.bool_and terms =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_bool_and" (by decide)))
        (terms.map (fun t => t.toPythonExpr))
    | Constraint.Variant.bool_or terms =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_bool_or" (by decide)))
        (terms.map (fun t => t.toPythonExpr))
    | Constraint.Variant.implication src dst =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_implication" (by decide)))
        #[ src.toPythonExpr, dst.toPythonExpr ]
    | Constraint.Variant.max_equality target exprs _ =>
      let args := Array.append
        #[ sigmaExprToPython target ]
        (exprs.map (fun e => sigmaExprToPython e))
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_max_equality" (by decide))) args
    | Constraint.Variant.cumulative intervals demands capacity =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_cumulative" (by decide)))
        #[
          (Python.Expr.lit (Python.Literal.array
            (intervals.map (fun e => e.toPythonExpr)))),
          (Python.Expr.lit (Python.Literal.array
            (demands.map (fun e => sigmaExprToPython e)))),
          sigmaExprToPython capacity,
        ]
    ;
  let labeled :=
    Python.Expr.call
      (Python.Expr.dot
        constraint
        (Python.ValidName.mk "with_name" (by decide)))
      #[ (Python.Expr.lit (Python.Literal.str cnst.name.val)) ]
  let enforced := match cnst.enforcement with
    | Constraint.Enforcement.always => Python.Statement.exprLine labeled
    | Constraint.Enforcement.onlyWhenAll literals =>
      Python.Statement.exprLine (Python.Expr.call
        (Python.Expr.dot
          labeled
          (Python.ValidName.mk "only_enforce_if" (by decide)))
        (literals.map (fun (l : BoolLit) => l.toPythonExpr)).toArray)
    ;
  enforced

structure SolveRequest (model : Model) where
  exprs : Array CpsatSolver.LinearExpr.WithDomain
  expressionsWellFormed : ∀ i : Fin exprs.size,
    (exprs[i]).snd.intVars ⊆ model.declaredInts

inductive SolveStatus where
  | unknown
  | infeasible
  | modelInvalid
  | feasible
  | optimal

structure SolveResponse (model : Model) (req : SolveRequest model) where
  objectiveValue : Float
  status : SolveStatus
  exprs : Vector CpsatSolver.Int64 req.exprs.size

def Model.Valid (model : Model) (req : SolveRequest model) : Prop :=
  model.ReferencesWellFormed

/- This is the explicit process boundary contract. Parsing JSON establishes
   only its shape; this predicate is the additional condition required before
   treating returned values as a CP-SAT result. -/
def SolveResponse.Valid {model : Model} {req : SolveRequest model}
    (response : SolveResponse model req) : Prop :=
  response.status = .feasible ∨ response.status = .optimal →
    ∃ assignment : model.Assignment,
      ∀ i : Fin req.exprs.size,
        response.exprs[i].val =
          LinearExpr.eval assignment (req.exprs[i]).snd

private def Model.Python.imports : Array Python.Statement := #[
  -- from ortools.sat.python import cp_model
  (Python.Statement.importLine
    (Python.Import.fromForm
      #[
        (Python.ValidName.mk "ortools" (by decide)),
        (Python.ValidName.mk "sat" (by decide)),
        (Python.ValidName.mk "python" (by decide)),
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
          (Python.ValidName.mk "CpModel" (by decide))
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
          (Python.ValidName.mk "CpSolver" (by decide)))
        #[]))),
    -- status = solver.solve(model)
    (Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.solveStatus)
      (Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id Model.Python.Name.cpsatSolver)
          (Python.ValidName.mk "solve" (by decide)))
        #[ (Python.Expr.id Model.Python.Name.model) ]))),
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
                  (Python.ValidName.mk "value" (by decide)))
                #[ (@LinearExpr.toPythonExpr linExpr.fst linExpr.snd) ]))))),
          (Prod.mk
            (Python.Expr.lit (Python.Literal.str Model.Python.Literals.status))
            (Python.Expr.call
              (Python.Expr.id (Python.ValidName.mk "str" (by decide)))
              #[ (Python.Expr.id Model.Python.Name.solveStatus) ])),
          (Prod.mk
            (Python.Expr.lit (Python.Literal.str Model.Python.Literals.objectiveValue))
            (Python.Expr.dot
              (Python.Expr.id Model.Python.Name.cpsatSolver)
              (Python.ValidName.mk "objective_value" (by decide))))
        ]
      ))
      )),
    -- print(json.dumps(output))
    (Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.id Model.Python.Name.print)
      #[ (Python.Expr.call
          (Python.Expr.dot
            (Python.Expr.id Model.Python.Name.json)
            (Python.ValidName.mk "dumps" (by decide)))
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

private def parseJsonFloat (json : Lean.Json) : Except String Float :=
  match json with
  | .num num =>
    Except.ok num.toFloat
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
          | "CpSolverStatus.INFEASIBLE" => SolveStatus.infeasible
          | "CpSolverStatus.MODEL_INVALID" => SolveStatus.modelInvalid
          | "CpSolverStatus.FEASIBLE" => SolveStatus.feasible
          | "CpSolverStatus.OPTIMAL" => SolveStatus.optimal
          | _ => SolveStatus.unknown)
      | _ => Except.error "Expected string.";
  let parseObjectiveValue (map : Std.TreeMap.Raw String Lean.Json compare)
    : Except String Float :=
    match map.get? Model.Python.Literals.objectiveValue with
    | .some objectiveValueJson => match parseJsonFloat objectiveValueJson with
      | .ok objectiveValue => Except.ok objectiveValue
      | .error err => Except.error s!"Parse float: {err}"
    | .none => Except.error "Missing value."
  let parseExprs (map : Std.TreeMap.Raw String Lean.Json compare)
    : Except String (Vector CpsatSolver.Int64 req.exprs.size) :=
    match map.get? Model.Python.Literals.exprs with
    | .some exprsJson => match exprsJson with
      | .arr array =>
        if h : array.size = req.exprs.size then
          Vector.mapM
            (fun el => match parseJsonInteger el with
              | .ok num =>
                if h : Int64.Nonoverflow num then
                  Except.ok { val := num, nonoverflow := h }
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

def Model.script (model : Model) (req : SolveRequest model) : Python.Script := {
  statements := Array.append
    (Array.append
      Model.Python.imports
      (Model.Python.modelDef model))
    (Model.Python.reportSolution model req)
}

def Model.solve
  (model : Model)
  (pythonRuntime : Python.Runtime)
  (req : SolveRequest model)
  (_valid : model.Valid req) : IO (Except String (SolveResponse model req)) := do
  let script : Python.Script := Model.script model req
  let out <- Python.Script.exec pythonRuntime script
  return Model.parseScriptOutput model req out.stdout

end CpsatSolver
