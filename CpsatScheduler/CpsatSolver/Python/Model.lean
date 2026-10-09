import CpsatScheduler.CpsatSolver.Python.Basic
import CpsatScheduler.CpsatSolver.Model

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

private def boolVar (var : BoolVar) : Python.Statement :=
  .assignLine (.id (EntityID.toPythonName var.id)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_bool_var"))
      #[.lit (.str (var.label.getD (EntityID.toPythonName var.id).val))]
      #[]
  )

private def intVar (var : IntVar) : Python.Statement :=
  .assignLine (.id (EntityID.toPythonName var.id)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_int_var_from_domain"))
      #[
        domainExpr var.domain.domain,
        .lit (.str (var.label.getD (EntityID.toPythonName var.id).val))
      ]
      #[]
  )

private def fixedSizeIntervalVar
    (var : FixedSizeIntervalVar) : Python.Statement :=
  .assignLine (.id (EntityID.toPythonName var.id)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_fixed_size_interval_var"))
      #[
        (@LinearExpr.toPythonExpr var.startBounds var.start),
        .lit (.int var.size),
        .lit (.str (var.label.getD (EntityID.toPythonName var.id).val))
      ]
      #[]
  )

private def constraint (cnst : Constraint) : Python.Statement :=
  let sigmaExprToPython (e : LinearExpr.WithBounds) : Python.Expr :=
    @LinearExpr.toPythonExpr e.fst e.snd
  let modelDot (attr : Python.ValidName) : Python.Expr :=
    .dot (.id Name.model) attr
  let constraint : Python.Expr := match cnst.variant with
    | .bounded_linear expr =>
      .call (modelDot (Python.ValidName.of "add"))
        #[expr.toPythonExpr]
        #[]
    | .bool_and terms _ =>
      .call (modelDot (Python.ValidName.of "add_bool_and"))
        (terms.map (fun t => t.toPythonExpr))
        #[]
    | .bool_or terms _ =>
      .call (modelDot (Python.ValidName.of "add_bool_or"))
        (terms.map (fun t => t.toPythonExpr))
        #[]
    | .implication src dst =>
      .call (modelDot (Python.ValidName.of "add_implication"))
        #[src.toPythonExpr, dst.toPythonExpr]
        #[]
    | .max_equality target exprs _ =>
      .call (modelDot (Python.ValidName.of "add_max_equality"))
        (#[sigmaExprToPython target] ++ exprs.map sigmaExprToPython)
        #[]
    | .div_eq target numerator divisor _ =>
      .call
        (modelDot (Python.ValidName.of "add_division_equality"))
        #[ sigmaExprToPython target, sigmaExprToPython numerator,
          .lit (.int divisor) ]
        #[]
    | .allowed_assignments vars rows _ _ =>
      .call
        (modelDot (Python.ValidName.of "add_allowed_assignments"))
        #[
          .lit (.array
            (vars.toArray.map (fun v => v.toPythonExpr))),
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
            (items.map fun it => it.interval.toPythonExpr)),
          .lit (.array
            (items.map fun it => sigmaExprToPython it.demand)),
          sigmaExprToPython capacity
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
        #[.lit (.str (EntityID.toPythonName cnst.id).val)] #[]
  match cnst.enforcement with
  | Constraint.Enforcement.always => .exprLine labeled
  | Constraint.Enforcement.onlyWhenAll literals =>
    .exprLine (.call
      (.dot labeled (Python.ValidName.of "only_enforce_if"))
      (literals.map (fun l : BoolLit => l.toPythonExpr)).toArray #[])

private def objective (obj : Objective) : Array Python.Statement :=
  match obj with
  | .none => #[]
  | .minimize e =>
    #[.exprLine (.call
      (.dot (.id Name.model)
        (Python.ValidName.of "minimize"))
      #[@LinearExpr.toPythonExpr e.fst e.snd] #[])]
  | .maximize e =>
    #[.exprLine (.call
      (.dot (.id Name.model)
        (Python.ValidName.of "maximize"))
      #[@LinearExpr.toPythonExpr e.fst e.snd] #[])]

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

private def modelDef (model : Model) : Array Python.Statement :=
  let frontmatter : Array Python.Statement := #[
    .assignLine (.id Name.model)
      (.call
        (.dot (.id Name.cpModelLib)
          (Python.ValidName.of "CpModel")) #[] #[])
  ]
  frontmatter ++
    (model.spec.ints.map intVar) ++
    (model.spec.bools.map boolVar) ++
    (model.spec.intervals.map fixedSizeIntervalVar) ++
    (model.spec.constraints.map constraint) ++
    objective model.spec.objective

private def reportSolution (model : Model) : Array Python.Statement :=
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
          (.lit (.dict
            (model.spec.ints.map fun v =>
              (.lit (.str (EntityID.toPythonName v.id).val),
                .call
                  (.dot (.id Name.cpsatSolver)
                    (Python.ValidName.of "value"))
                  #[v.toPythonExpr] #[]))))),
        (Prod.mk
          (.lit (.str Literals.bools))
          (.lit (.dict
            (model.spec.bools.map fun v =>
              (.lit (.str (EntityID.toPythonName v.id).val),
                .call
                  (.dot (.id Name.cpsatSolver)
                    (Python.ValidName.of "value"))
                  #[.id (EntityID.toPythonName v.id)] #[]))))),
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

def script (model : Model) : Python.Script := {
  statements := imports ++ modelDef model ++
    reportSolution model
}

end CpsatSolver.Model.Python
