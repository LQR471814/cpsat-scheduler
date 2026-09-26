import CpsatScheduler.Scipy.Basic

namespace Scipy

open Scipy

private def betaAlpha (opt exp pes : Float) : Float := 1 + 4 * (exp - opt) / (pes - opt)
private def betaBeta (opt exp pes : Float) : Float := 1 + 4 * (pes - exp) / (pes - opt)

def pertPosition (opt pes δ : Float) : Float :=
  let x := (δ - opt) / (pes - opt)
  if x < 0.0 then 0.0 else if x > 1.0 then 1.0 else x

def pertCostExpr (opt exp pes cost δ : Float) : Python.Expr :=
  let survival :=
    .sub (.lit (.float 1.0))
      (cdfScalarUnchecked (pertPosition opt pes δ) (betaAlpha opt exp pes) (betaBeta opt exp pes))
  .mul (.lit (.float cost)) survival

end Scipy
