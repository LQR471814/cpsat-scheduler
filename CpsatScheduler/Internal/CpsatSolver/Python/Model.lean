module

public import CpsatScheduler.Internal.CpsatSolver.Python.Basic
public import CpsatScheduler.Internal.CpsatSolver.Model

import CpsatScheduler.Internal.CpsatSolver.Encodability
import CpsatScheduler.Internal.Util.Finset
import Mathlib.Data.List.Lex

namespace CpsatSolver.Model.Python

def Array.ofHasReprFinset [HasRepr α] [DecidableEq α]
  (set : Finset α) : Array α :=
  set.sortByKey (HasRepr.toRepr ·) HasRepr.toRepr_inj
  |> List.toArray

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

private def initBoolVar (var : BoolVar) : Python.Statement :=
  .assignLine (.id (Python.encodableName var)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_bool_var"))
      #[.lit (.str (var.label.getD (Python.encodableName var).val))]
      #[]
  )

private def initIntVar (var : IntVar) : Python.Statement :=
  .assignLine (.id (Python.encodableName var)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_int_var_from_domain"))
      #[
        domainExpr var.domain.domain,
        .lit (.str (var.label.getD (Python.encodableName var).val))
      ]
      #[]
  )

private def initFixedSizeIntervalVar
    (var : FixedSizeIntervalVar) : Python.Statement :=
  .assignLine (.id (Python.encodableName var)) (
    .call
      (.dot
        (.id Name.model)
        (Python.ValidName.of "new_fixed_size_interval_var"))
      #[
        var.start.toPythonExpr,
        .lit (.int var.size),
        .lit (.str (var.label.getD (Python.encodableName var).val))
      ]
      #[]
  )

private def initConstraint (cnst : Constraint) : Python.Statement :=
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
        (#[target.toPythonExpr] ++ exprs.map (·.toPythonExpr))
        #[]
    | .div_eq target numerator divisor _ =>
      .call
        (modelDot (Python.ValidName.of "add_division_equality"))
        #[ target.toPythonExpr, numerator.toPythonExpr,
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
            (items.map fun it => it.demand.toPythonExpr)),
          capacity.toPythonExpr
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
        #[.lit (.str (Python.encodableName cnst).val)] #[]
  match cnst.enforcement with
  | Constraint.Enforcement.always => .exprLine labeled
  | Constraint.Enforcement.onlyWhenAll literals _ =>
    .exprLine (.call
      (.dot labeled (Python.ValidName.of "only_enforce_if"))
      (literals.map (fun l : BoolLit => l.toPythonExpr)) #[])

private def initObjective (obj : Objective) : Array Python.Statement :=
  match obj with
  | .none => #[]
  | .minimize e =>
    #[.exprLine (.call
      (.dot (.id Name.model)
        (Python.ValidName.of "minimize"))
      #[e.toPythonExpr] #[])]
  | .maximize e =>
    #[.exprLine (.call
      (.dot (.id Name.model)
        (Python.ValidName.of "maximize"))
      #[e.toPythonExpr] #[])]

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
  let initStatements {α : Type} [HasRepr α] [DecidableEq α]
    (v : Finset α) (init : α → Python.Statement) := v
      |> Array.ofHasReprFinset
      |> Array.map init
  frontmatter ++
    (initStatements model.ints initIntVar) ++
    (initStatements model.bools initBoolVar) ++
    (initStatements model.intervals initFixedSizeIntervalVar) ++
    (initStatements model.constraints initConstraint) ++
    initObjective model.objective

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
            ((Array.ofHasReprFinset model.ints).map fun v =>
              (.lit (.str (Python.encodableName v).val),
                .call
                  (.dot (.id Name.cpsatSolver)
                    (Python.ValidName.of "value"))
                  #[v.toPythonExpr] #[]))))),
        (Prod.mk
          (.lit (.str Literals.bools))
          (.lit (.dict
            ((Array.ofHasReprFinset model.bools).map fun v =>
              (.lit (.str (Python.encodableName v).val),
                .call
                  (.dot (.id Name.cpsatSolver)
                    (Python.ValidName.of "value"))
                  #[.id (Python.encodableName v)] #[]))))),
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

public def script (model : Model) : Python.Script := {
  statements := imports ++ modelDef model ++
    reportSolution model
}

end CpsatSolver.Model.Python
