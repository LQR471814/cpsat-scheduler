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

/-- PERT expression for a single quantile probability.

Precondition (not machine-checked here because it ranges over runtime `Float`s):
`0 ≤ prob ∧ prob ≤ 1`. Callers must supply a probability in range; `pertProbs`
does so by construction. Mirrors `pert`'s composition
`opt + ppf(prob) * (pes - opt)` using the scalar, JSON-clean `ppfScalarUnchecked`. -/
def pertPointExpr (opt exp pes prob : Float) : Python.Expr :=
  let alpha := 1 + 4 * (exp - opt) / (pes - opt);
  let beta := 1 + 4 * (pes - exp) / (pes - opt);
  let texpr := ppfScalarUnchecked prob alpha beta;
  Python.Expr.add
    (Python.Expr.lit (Python.Literal.float opt))
    (Python.Expr.mul
      texpr
      (Python.Expr.lit (Python.Literal.float (pes - opt))))

/-- Distribution of quantile sample points across the open interval `(0, 1)`. -/
inductive Spacing where
  /-- Quadratic, denser near `0` (the optimistic tail): `((i+1)/(steps+1))²`. -/
  | frontLoaded
  /-- Quadratic, denser near `1` (the pessimistic tail):
      `1 - ((steps-i)/(steps+1))²`. -/
  | backLoaded
  /-- Evenly spaced: `(i+1)/(steps+1)`. -/
  | linear
deriving DecidableEq, Repr, Inhabited

/-- The `i`-th of `steps` sample probabilities under a given `Spacing`, always
strictly inside `(0, 1)` and strictly increasing in `i`. -/
def Spacing.probAt (s : Spacing) (steps i : ℕ) : Float :=
  let denom : Float := (steps + 1).toFloat
  match s with
  | .frontLoaded =>
    let r : Float := (i + 1).toFloat / denom
    r * r
  | .backLoaded =>
    -- mirror of frontLoaded about 1/2: dense near 1
    let r : Float := (steps - i).toFloat / denom
    1.0 - r * r
  | .linear =>
    (i + 1).toFloat / denom

/-- `steps` probabilities distributed across `(0, 1)` according to `spacing`
(default `Spacing.backLoaded`, denser near the pessimistic tail `1`).

For every supported spacing the values are strictly increasing and lie strictly
inside `(0, 1)`. -/
def pertProbs (steps : ℕ) (spacing : Spacing := Spacing.backLoaded)
    (_h : steps > 0 := by decide) : Array Float :=
  (Array.range steps).map fun i => spacing.probAt steps i

end Scipy

