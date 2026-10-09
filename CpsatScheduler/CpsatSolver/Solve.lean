import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.CpsatSolver.LinearExpr
import CpsatScheduler.CpsatSolver.Python.Model
import CpsatScheduler.Python.Runtime

namespace CpsatSolver

structure Assignment where
  ints : List (EntityID × ℤ)
  bools : List (EntityID × Bool)

def Assignment.intVal (a : Assignment) (id : EntityID) : ℤ :=
  match a.ints.find? (fun p => p.1 == id) with
  | some p => p.2
  | none => 0

def Assignment.boolVal (a : Assignment) (id : EntityID) : Bool :=
  match a.bools.find? (fun p => p.1 == id) with
  | some p => p.2
  | none => false

def Assignment.valuation (a : Assignment) : EntityID → ℤ :=
  fun id => a.intVal id

/-- Look up the label of a declared variable (int, bool, or interval) by its id. -/
def Model.labelOf (model : Model) (id : EntityID) : Option String :=
  (model.spec.ints.find? (fun v => v.id == id)).bind (·.label)
  |>.orElse fun _ => (model.spec.bools.find? (fun v => v.id == id)).bind (·.label)
  |>.orElse fun _ => (model.spec.intervals.find? (fun v => v.id == id)).bind (·.label)

def BoolLit.eval (a : Assignment) : BoolLit → Bool
  | .var v => a.boolVal v.id
  | .neg v => !a.boolVal v.id

def Constraint.Enforcement.active (a : Assignment) : Constraint.Enforcement → Bool
  | .always => true
  | .onlyWhenAll literals => literals.toList.all (fun l => l.eval a)

def BoundedLinearExpr.holdsB (expr : BoundedLinearExpr) (a : Assignment) : Bool :=
  let l := expr.left.eval a.valuation
  let r := expr.right.eval a.valuation
  match expr.rel with
  | .eq => decide (l = r)
  | .neq => decide (l ≠ r)
  | .gt => decide (l > r)
  | .gte => decide (l ≥ r)
  | .lt => decide (l < r)
  | .lte => decide (l ≤ r)

def BoundedLinearExpr.holds (expr : BoundedLinearExpr) (a : Assignment) : Prop :=
  expr.holdsB a = true

def Constraint.Variant.holdsB (v : Constraint.Variant) (a : Assignment) : Bool :=
  match v with
  | .bounded_linear expr => expr.holdsB a
  | .max_equality target exprs _ =>
    let tv := target.snd.eval a.valuation
    exprs.all (fun e => decide (e.snd.eval a.valuation ≤ tv)) &&
      (decide (exprs.size = 0) ||
        exprs.any (fun e => decide (e.snd.eval a.valuation = tv)))
  | .div_eq target numerator divisor _ =>
    decide (target.snd.eval a.valuation =
      Int.tdiv (numerator.snd.eval a.valuation) divisor.val)
  | allowed_assignments vars rows _ _ =>
    rows.any fun row =>
      decide (∀ i : Fin vars.size, a.intVal vars[i].id = row[i].val)
  | .cumulative items capacity =>
    let cap := capacity.snd.eval a.valuation
    let starts := items.toList.map fun it => it.interval.start.eval a.valuation
    starts.all fun t =>
      decide ((items.toList.foldl (fun acc it =>
        let s := it.interval.start.eval a.valuation
        let sz := it.interval.size.val
        let d := it.demand.snd.eval a.valuation
        if s ≤ t ∧ t < s + sz then acc + d else acc) 0) ≤ cap)
  | .bool_and terms _ => terms.toList.all (fun l => l.eval a)
  | .bool_or terms _ => terms.toList.any (fun l => l.eval a)
  | .implication src dst => (!src.eval a || dst.eval a)

def Constraint.Variant.holds (v : Constraint.Variant) (a : Assignment) : Prop :=
  v.holdsB a = true

def Constraint.Holds (c : Constraint) (a : Assignment) : Prop :=
  c.enforcement.active a = true → c.variant.holds a

def Constraint.holdsB (c : Constraint) (a : Assignment) : Bool :=
  !(c.enforcement.active a) || c.variant.holdsB a

theorem Constraint.holdsB_iff (c : Constraint) (a : Assignment) :
    c.holdsB a = true ↔ c.Holds a := by
  cases hact : c.enforcement.active a <;> simp [Constraint.holdsB, Constraint.Holds, hact,
    Constraint.Variant.holds]

def Model.domainOkB (model : Model) (a : Assignment) : Bool :=
  model.spec.ints.all (fun v => v.domain.domain.contains (a.intVal v.id)) &&
    model.spec.bools.all (fun v => (a.bools.find? (fun p => p.1 == v.id)).isSome)

def Model.domainOk (model : Model) (a : Assignment) : Prop :=
  model.domainOkB a = true

def Model.satisfiesB (model : Model) (a : Assignment) : Bool :=
  model.domainOkB a && model.spec.constraints.all (fun c => c.holdsB a)

def Model.Satisfies (model : Model) (a : Assignment) : Prop :=
  model.satisfiesB a = true

theorem Model.satisfiesB_iff (model : Model) (a : Assignment) :
    model.satisfiesB a = true ↔ model.Satisfies a := Iff.rfl

def Objective.eval (obj : Objective) (a : Assignment) : Option ℤ :=
  match obj with
  | Objective.none => Option.none
  | Objective.minimize e => Option.some (e.snd.eval a.valuation)
  | Objective.maximize e => Option.some (e.snd.eval a.valuation)

def Model.evalObjective (model : Model) (a : Assignment) : Option ℤ :=
  model.spec.objective.eval a

inductive SolveStatus where
  | unknown
  | infeasible
  | modelInvalid
  | feasible
  | optimal

inductive SolveResult (model : Model) where
  | infeasible
  | modelInvalid
  | unknown
  | feasible (asgn : Assignment) (sat : model.Satisfies asgn)
  | optimal (asgn : Assignment) (sat : model.Satisfies asgn)

private def parseJsonInteger (json : Lean.Json) : Except String ℤ :=
  match json with
  | .num num =>
    if num.exponent = 0 then Except.ok num.mantissa
    else Except.error "Expected no decimal numbers."
  | _ => Except.error "Expected number type."

private def parseStatus (map : Std.TreeMap.Raw String Lean.Json compare) :
    Except String SolveStatus :=
  match map.get? Model.Python.Literals.status with
  | none => Except.error "Missing status."
  | some (.str statusStr) =>
    Except.ok (match statusStr with
      | "CpSolverStatus.INFEASIBLE" => SolveStatus.infeasible
      | "CpSolverStatus.MODEL_INVALID" => SolveStatus.modelInvalid
      | "CpSolverStatus.FEASIBLE" => SolveStatus.feasible
      | "CpSolverStatus.OPTIMAL" => SolveStatus.optimal
      | _ => SolveStatus.unknown)
  | some _ => Except.error "Expected string status."

private def parseNamedInts (model : Model)
    (map : Std.TreeMap.Raw String Lean.Json compare) :
    Except String (List (EntityID × ℤ)) :=
  match map.get? Model.Python.Literals.ints with
  | some (.obj obj) =>
    model.spec.ints.toList.mapM fun v =>
      match obj.get? (EntityID.toPythonName v.id).val with
      | some j => parseJsonInteger j |>.map fun n => (v.id, n)
      | none => Except.error s!"Missing int {(EntityID.toPythonName v.id).val}"
  | _ => Except.error "Missing ints object."

private def parseNamedBools (model : Model)
    (map : Std.TreeMap.Raw String Lean.Json compare) :
    Except String (List (EntityID × Bool)) :=
  match map.get? Model.Python.Literals.bools with
  | some (.obj obj) =>
    model.spec.bools.toList.mapM fun v =>
      match obj.get? (EntityID.toPythonName v.id).val with
      | some j => parseJsonInteger j |>.map fun n => (v.id, n ≠ 0)
      | none => Except.error s!"Missing bool {(EntityID.toPythonName v.id).val}"
  | _ => Except.error "Missing bools object."

private def Model.interpret (model : Model) (status : SolveStatus)
  (asgn : Assignment) :
    Except String (SolveResult model) :=
  match status with
  | .infeasible => .ok .infeasible
  | .modelInvalid => .ok .modelInvalid
  | .unknown => .ok .unknown
  | .feasible =>
    if h : model.satisfiesB asgn = true then
      .ok (.feasible asgn ((Model.satisfiesB_iff model asgn).mp h))
    else
      .error "Returned assignment does not satisfy the model."
  | .optimal =>
    if h : model.satisfiesB asgn = true then
      .ok (.optimal asgn ((Model.satisfiesB_iff model asgn).mp h))
    else
      .error "Returned assignment does not satisfy the model."

def Model.solve (model : Model) (py : Python.DaemonProcess) :
    IO (Except String (SolveResult model)) := do
  let result ← py.execWithJson (Model.Python.script model)
  pure do
    let outJson ← result
    let map ← match outJson with
      | .obj map => .ok map
      | _ => .error "Expected JSON object"
    let (status, asgn) ← match
      parseStatus map,
      parseNamedInts model map,
      parseNamedBools model map
    with
      | .ok status, .ok ints, .ok bools =>
        Except.ok (status, ⟨ints, bools⟩)
      | .error err, _, _ => Except.error s!"status: {err}"
      | _, .error err, _ => Except.error s!"ints: {err}"
      | _, _, .error err => Except.error s!"bools: {err}"
    Model.interpret model status asgn

end CpsatSolver

