import CpsatScheduler.Scipy.Basic

namespace Scipy

open Scipy

def pert (probs : Array Float) (opt exp pes : Float)
  (h : ∀ p ∈ probs, p ≥ 0 ∧ p ≤ 1 := by decide) :
    Python.Expr :=
  let alpha := 1 + 4 * (exp - opt) / (pes - opt);
  let beta := 1 + 4 * (pes - exp) / (pes - opt);
  let texpr := ppf probs alpha beta h;
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

end Scipy

