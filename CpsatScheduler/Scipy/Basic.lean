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

def ppf (prob alpha beta : Float)
  (_ : prob ≥ 0 ∧ prob ≤ 1 := by decide) :
    Python.Expr :=
  -- beta([prob], alpha, beta).item()
  Python.Expr.call
    (Python.Expr.dot
      (Python.Expr.call
        (Python.Expr.id Name.beta)
        #[
          (Python.Expr.lit
            (Python.Literal.array
              #[ (Python.Expr.lit
                  (Python.Literal.float prob)) ])),
          (Python.Expr.lit
            (Python.Literal.float alpha)),
          (Python.Expr.lit
            (Python.Literal.float beta)),
        ])
      Name.item)
    #[]

def pert (prob opt exp pes : Float)
  (h : prob ≥ 0 ∧ prob ≤ 1 := by decide) :
    Python.Expr :=
  let alpha := 1 + 4 * (exp - opt) / (pes - opt);
  let beta := 1 + 4 * (pes - exp) / (pes - opt);
  let texpr := ppf prob alpha beta h;
  -- opt + <PPF> * (pes - opt <- as a literal)
  Python.Expr.add
    (Python.Expr.lit
      (Python.Literal.float
        opt))
    (Python.Expr.mul
      texpr
      (Python.Expr.lit
        (Python.Literal.float
          (pes - opt))))

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

