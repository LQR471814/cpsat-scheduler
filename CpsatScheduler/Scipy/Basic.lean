import Lean.Data.Json
import CpsatScheduler.Python

namespace Scipy

namespace Name
def scipy := Python.ValidName.of "scipy"
def stats := Python.ValidName.of "stats"
def beta := Python.ValidName.of "beta"
def item := Python.ValidName.of "item"
def print := Python.ValidName.of "print"
end Name

def ppf (probs : Array Float) (alpha beta : Float)
  (_ : ∀ p ∈ probs, p ≥ 0 ∧ p ≤ 1 := by decide) :
    Python.Expr :=
  -- beta([prob], alpha, beta).item()
  Python.Expr.call
    (Python.Expr.dot
      (Python.Expr.call
        (Python.Expr.id Name.beta)
        #[
          (Python.Expr.lit
            (Python.Literal.array
              (probs.map
                (fun p => Python.Expr.lit
                  (Python.Literal.float p))))),
          (Python.Expr.lit
            (Python.Literal.float alpha)),
          (Python.Expr.lit
            (Python.Literal.float beta)),
        ])
      Name.item)
    #[]

private def mkEvalScript (expr : Python.Expr) : Python.Script :=
  {
    statements := #[
      (Python.Statement.importLine
        (Python.Import.fromForm
          #[ Name.scipy, Name.stats ]
          #[ (Python.NameAs.unaliased Name.beta) ])),
      (Python.Statement.exprLine
        (Python.Expr.call
          (Python.Expr.id Name.print)
          #[ expr ]))
    ]
  }

def evalFloat (runtime : Python.Runtime) (expr : Python.Expr) := do
  let script := mkEvalScript expr;
  let result <- script.exec runtime;
  let json := Lean.Json.parse result.stdout
  let result := match json with
    | Except.ok value => match value with
      | Lean.Json.num n => Except.ok n.toFloat
      | _ => Except.error "expected float value output"
    | Except.error err => Except.error s!"parse json: ${err}"
  pure result

end Scipy

