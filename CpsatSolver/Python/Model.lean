import CpsatSolver.Python.Basic
import CpsatSolver.Model
import CpsatSolver.LinearExpr

namespace CpsatSolver.Model.Python

namespace Name
def cpModelLib := Python.ValidName.of "cp_model"
def model := Python.ValidName.of "__cpsat_model"
def cpsatSolver := Python.ValidName.of "__cpsat_solver"
def solveStatus := Python.ValidName.of "__solve_status"
def output := Python.ValidName.of "__output"
end Name

namespace Literals
def ints := "ints"
def bools := "bools"
def status := "status"
def solverObjective := "solver_objective"
end Literals

/-! ### Name resolution

Every declarable object has a structural identity `Encodable.encode`. Those
raw ids can be large, so the code generator remaps the distinct ids used by a
model to dense ranks (`0, 1, 2, …`) by sorting them. The resulting
`NameResolver` turns any object's encoded id into `e_<rank>`. -/

/-- All distinct encoded `IntVar` ids used by the model: declared ints plus
    any int var referenced inside a constraint or the objective. -/
private def intIds (model : Model) : Array Nat :=
  let fromExpr (e : LinearExpr) : Array Nat :=
    e.raw.intVars.map Encodable.encode
  let fromRaw (r : LinearExpr.Raw) : Array Nat :=
    r.intVars.map Encodable.encode
  let declared :=
    (Finset.sortedByEncode model.spec.ints).toArray.map Encodable.encode
  let fromConstraint (c : Constraint) : Array Nat :=
    match c.variant with
    | .bounded_linear e => fromExpr e.left ++ fromExpr e.right
    | .max_equality target exprs _ =>
      fromExpr target ++ exprs.flatMap fromExpr
    | .div_eq target numerator _ _ => fromExpr target ++ fromExpr numerator
    | .allowed_assignments vars _ _ _ =>
      vars.toArray.map Encodable.encode
    | .cumulative items capacity =>
      items.flatMap (fun it => fromRaw it.demand) ++ fromExpr capacity
    | .bool_and _ _ | .bool_or _ _ | .implication _ _ => #[]
  let fromObjective : Array Nat :=
    match model.spec.objective with
    | .none => #[]
    | .minimize e | .maximize e => fromExpr e
  let all := declared
    ++ (Finset.sortedByEncode model.spec.constraints).toArray.flatMap fromConstraint
    ++ fromObjective
  all.toList.dedup.toArray

/-- All distinct encoded `BoolVar` ids used by the model. -/
private def boolIds (model : Model) : Array Nat :=
  let litId : BoolLit → Nat
    | .var v | .neg v => Encodable.encode v
  let declared :=
    (Finset.sortedByEncode model.spec.bools).toArray.map Encodable.encode
  let fromEnforcement : Constraint.Enforcement → Array Nat
    | .always => #[]
    | .onlyWhenAll lits _ => lits.map litId
  let fromConstraint (c : Constraint) : Array Nat :=
    fromEnforcement c.enforcement ++
    (match c.variant with
      | .bool_and terms _ | .bool_or terms _ => terms.map litId
      | .implication src dst => #[litId src, litId dst]
      | _ => #[])
  let all := declared
    ++ (Finset.sortedByEncode model.spec.constraints).toArray.flatMap fromConstraint
  all.toList.dedup.toArray

/-- Rank-based resolver over a sorted id table: an id maps to `e_<index>`,
    or `e_<id>` as a fallback if it is absent (should not happen for ids drawn
    from the model). -/
private def resolverOf (ids : Array Nat) : CpsatSolver.NameResolver :=
  let sorted := ids.qsort (· < ·)
  fun n =>
    match sorted.findIdx? (· = n) with
    | some i => CpsatSolver.pythonName i
    | none => CpsatSolver.pythonName n

/-- Combined resolver: int and bool id spaces are ranked independently but, to
    guarantee globally distinct names, bool ranks are offset past the int
    ranks. Intervals/constraints reuse the int resolver's raw fallback. -/
def nameResolver (model : Model) : CpsatSolver.NameResolver :=
  let ints := (intIds model).qsort (· < ·)
  let bools := (boolIds model).qsort (· < ·)
  fun n =>
    match ints.findIdx? (· = n) with
    | some i => CpsatSolver.pythonName i
    | none =>
      match bools.findIdx? (· = n) with
      | some i => CpsatSolver.pythonName (ints.size + i)
      | none => CpsatSolver.pythonName (ints.size + bools.size + n)

private def domainExpr (d : Domain) : Python.Expr :=
  .call
    (.dot
      (.dot
        (.id Name.cpModelLib)
        (Python.ValidName.of "Domain"))
      (Python.ValidName.of "from_intervals"))
    #[.lit (.array
      (d.intervals.toArray.map fun i =>
        .lit (.array #[
          .lit (.int i.left),
          .lit (.int i.right)])))]
    #[]

private def boolVar (r : CpsatSolver.NameResolver) (var : BoolVar) : Python.Statement :=
  .assignLine (.id (r.of var)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_bool_var"))
      #[.lit (.str (var.label.getD (r.of var).val))]
      #[]
  )

private def intVar (r : CpsatSolver.NameResolver) (var : IntVar) : Python.Statement :=
  .assignLine (.id (r.of var)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_int_var_from_domain"))
      #[
        domainExpr var.domain.domain,
        .lit (.str (var.label.getD (r.of var).val))
      ]
      #[]
  )

private def fixedSizeIntervalVar
    (r : CpsatSolver.NameResolver) (var : FixedSizeIntervalVar) : Python.Statement :=
  .assignLine (.id (r.of var)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_fixed_size_interval_var"))
      #[
        var.start.toPythonExpr r,
        .lit (.int var.size),
        .lit (.str (var.label.getD (r.of var).val))
      ]
      #[]
  )

private def constraint (r : CpsatSolver.NameResolver) (cnst : Constraint) : Python.Statement :=
  let modelDot (attr : Python.ValidName) : Python.Expr :=
    .dot (.id Name.model) attr
  let constraint : Python.Expr := match cnst.variant with
    | .bounded_linear expr =>
      .call (modelDot (Python.ValidName.of "add"))
        #[expr.toPythonExpr r]
        #[]
    | .bool_and terms _ =>
      .call (modelDot (Python.ValidName.of "add_bool_and"))
        (terms.map (fun t => t.toPythonExpr r))
        #[]
    | .bool_or terms _ =>
      .call (modelDot (Python.ValidName.of "add_bool_or"))
        (terms.map (fun t => t.toPythonExpr r))
        #[]
    | .implication src dst =>
      .call (modelDot (Python.ValidName.of "add_implication"))
        #[src.toPythonExpr r, dst.toPythonExpr r]
        #[]
    | .max_equality target exprs _ =>
      .call (modelDot (Python.ValidName.of "add_max_equality"))
        (#[target.toPythonExpr r] ++ exprs.map (fun e => e.toPythonExpr r))
        #[]
    | .div_eq target numerator divisor _ =>
      .call
        (modelDot (Python.ValidName.of "add_division_equality"))
        #[ target.toPythonExpr r, numerator.toPythonExpr r,
          .lit (.int divisor) ]
        #[]
    | .allowed_assignments vars rows _ _ =>
      .call
        (modelDot (Python.ValidName.of "add_allowed_assignments"))
        #[
          .lit (.array
            (vars.toArray.map (fun v => v.toPythonExpr r))),
          .lit (.array
            (rows.map fun row =>
              .lit (.array
                (row.toArray.map fun n =>
                  .lit (.int n.val)))))
        ] #[]
    | .cumulative items capacity =>
      .call (modelDot (Python.ValidName.of "add_cumulative"))
        #[
          .lit (.array
            (items.map fun it => it.interval.toPythonExpr r)),
          .lit (.array
            (items.map fun it => it.demand.toPythonExpr r)),
          capacity.toPythonExpr r
        ] #[]
  let labeled :=
    match cnst.label with
    | some lab =>
      .call
        (.dot constraint (Python.ValidName.of "with_name"))
        #[.lit (.str lab)] #[]
    | none =>
      .call
        (.dot constraint (Python.ValidName.of "with_name"))
        #[.lit (.str (r.of cnst).val)] #[]
  match cnst.enforcement with
  | Constraint.Enforcement.always => .exprLine labeled
  | Constraint.Enforcement.onlyWhenAll literals _ =>
    .exprLine (.call
      (.dot labeled (Python.ValidName.of "only_enforce_if"))
      (literals.map (fun l : BoolLit => l.toPythonExpr r)) #[])

private def objective (r : CpsatSolver.NameResolver) (obj : Objective) : Array Python.Statement :=
  match obj with
  | .none => #[]
  | .minimize e =>
    #[.exprLine (.call
      (.dot (.id Name.model)
        (Python.ValidName.of "minimize"))
      #[e.toPythonExpr r] #[])]
  | .maximize e =>
    #[.exprLine (.call
      (.dot (.id Name.model)
        (Python.ValidName.of "maximize"))
      #[e.toPythonExpr r] #[])]

private def imports : Array Python.Statement := #[
  .importLine
    (.fromForm
      #[Python.ValidName.of "ortools",
        Python.ValidName.of "sat",
        Python.ValidName.of "python"]
      #[Python.NameAs.unaliased Name.cpModelLib]),
  .importLine
    (.fromForm
      #[Python.StdName.json]
      #[Python.NameAs.unaliased Python.StdName.dumps])
]

private def modelDef (model : Model) (r : CpsatSolver.NameResolver) : Array Python.Statement :=
  let frontmatter : Array Python.Statement := #[
    .assignLine (.id Name.model)
      (.call
        (.dot (.id Name.cpModelLib)
          (Python.ValidName.of "CpModel")) #[] #[])
  ]
  frontmatter ++
    ((Finset.sortedByEncode model.spec.ints).map (intVar r)).toArray ++
    ((Finset.sortedByEncode model.spec.bools).map (boolVar r)).toArray ++
    ((Finset.sortedByEncode model.spec.intervals).map (fixedSizeIntervalVar r)).toArray ++
    ((Finset.sortedByEncode model.spec.constraints).map (constraint r)).toArray ++
    objective r model.spec.objective

private def reportSolution (model : Model) (r : CpsatSolver.NameResolver) : Array Python.Statement :=
  let intPairs : Array (Python.Expr × Python.Expr) :=
    ((Finset.sortedByEncode model.spec.ints).map fun v =>
      (Python.Expr.lit (.str (r.of v).val),
        Python.Expr.call
          (.dot (.id Name.cpsatSolver) (Python.ValidName.of "value"))
          #[v.toPythonExpr r] #[])).toArray
  let boolPairs : Array (Python.Expr × Python.Expr) :=
    ((Finset.sortedByEncode model.spec.bools).map fun v =>
      (Python.Expr.lit (.str (r.of v).val),
        Python.Expr.call
          (.dot (.id Name.cpsatSolver) (Python.ValidName.of "value"))
          #[.id (r.of v)] #[])).toArray
  #[
    .assignLine (.id Name.cpsatSolver)
      (.call
        (.dot (.id Name.cpModelLib)
          (Python.ValidName.of "CpSolver")) #[] #[]),
    .assignLine (.id Name.solveStatus)
      (.call
        (.dot (.id Name.cpsatSolver)
          (Python.ValidName.of "solve"))
        #[.id Name.model] #[]),
    .assignLine (.id Name.output)
      (.lit (.dict #[
        (Prod.mk
          (.lit (.str Literals.ints))
          (.lit (.dict intPairs))),
        (Prod.mk
          (.lit (.str Literals.bools))
          (.lit (.dict boolPairs))),
        (Prod.mk
          (.lit (.str Literals.status))
          (.call (.id (Python.ValidName.of "str"))
            #[.id Name.solveStatus] #[])),
        (Prod.mk
          (.lit (.str Literals.solverObjective))
          (.dot (.id Name.cpsatSolver)
            (Python.ValidName.of "objective_value")))
      ])),
    .exprLine (Python.print
      (.call
        (.id (Python.ValidName.of "dumps"))
        #[.id Name.output] #[]))
  ]

def script (model : Model) : Python.Script :=
  let r := nameResolver model
  {
    statements := imports ++ modelDef model r ++
      reportSolution model r
  }

end CpsatSolver.Model.Python
