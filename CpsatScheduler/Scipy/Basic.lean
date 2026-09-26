import Lean.Data.Json
import CpsatScheduler.Python

namespace Scipy

namespace Name
def scipy := Python.ValidName.of "scipy"
def stats := Python.ValidName.of "stats"
def beta := Python.ValidName.of "beta"
def item := Python.ValidName.of "item"
def print := Python.ValidName.of "print"
def ppf := Python.ValidName.of "ppf"
def float := Python.ValidName.of "float"
def json := Python.ValidName.of "json"
def dumps := Python.ValidName.of "dumps"
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

/-- Scalar PPF evaluation for a single probability, emitting a JSON-clean float:
`float(beta.ppf(prob, alpha, beta))`.

`scipy.stats.beta.ppf` is the inverse CDF; wrapping in `float(...)` collapses the
returned numpy scalar to a Python `float` so it serializes cleanly inside a JSON
array (see `Scipy.mkBatchScript`).

The `[0,1]` range precondition on `prob` is a caller obligation; it is not
machine-checked because it ranges over runtime `Float`s. `Scipy.pertProbs`
satisfies it by construction. -/
def ppfScalarUnchecked (prob alpha beta : Float) : Python.Expr :=
  -- float(beta.ppf(prob, alpha, beta))
  Python.Expr.call
    (Python.Expr.id Name.float)
    #[
      Python.Expr.call
        (Python.Expr.dot (Python.Expr.id Name.beta) Name.ppf)
        #[
          Python.Expr.lit (Python.Literal.float prob),
          Python.Expr.lit (Python.Literal.float alpha),
          Python.Expr.lit (Python.Literal.float beta)
        ]
    ]

end Scipy

