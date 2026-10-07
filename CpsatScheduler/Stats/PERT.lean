import CpsatScheduler.Python

import Mathlib.Data.Rat.Defs
import Mathlib.Data.Rat.Star

namespace Stats.PERT

namespace Name

def scipy := Python.ValidName.of "scipy"
def stats := Python.ValidName.of "stats"
def beta := Python.ValidName.of "beta"
def ppf := Python.ValidName.of "ppf"

end Name

private def alpha (opt exp pes : Float) : Float :=
  1 + 4 * (exp - opt) / (pes - opt)

private def beta (opt exp pes : Float) : Float :=
  1 + 4 * (pes - exp) / (pes - opt)

private def demandExpr (opt exp pes : Float) (probs : Array Float) :
    Python.Expr :=
  let rng := pes - opt
  .call (.id Python.StdName.list) #[
    (.add
      (.lit (.float opt))
      (.mul
        (.lit (.float rng))
        (.call (.dot (.id Name.beta) Name.ppf)
          #[
            .lit (.array (probs.map (fun x => .lit (.float x)))),
            .lit (.float (alpha opt exp pes)),
            .lit (.float (beta opt exp pes))
          ] #[])))
  ] #[]

def init (py : Python.DaemonProcess) : IO Unit :=
  py.exec {
    statements := #[
      .importLine (.fromForm
        #[ Name.scipy, Name.stats ]
        #[ .unaliased Name.beta ])
    ]
  }

private def evalDemands (py : Python.DaemonProcess) (opt exp pes : Float)
  (probs : Array Float) :
    IO (Except String (Array Float)) := do
  let result ← py.execWithJson
    (Python.Script.serializeJson
      (demandExpr opt exp pes probs))
  pure do
    let json ← result |> .mapError (s!"py.execWithJson: {·}")
    let arr ← match json with
      | .arr arr => .ok arr
      | _ => .error "Expected JSON array."
    arr.mapM (fun el => match el with
      | .num n => Except.ok n.toFloat
      | _ => Except.error "Expected JSON float for array element.")

private def expCost (cost prob : Float) : Float :=
  -- probability of non completion * total cost
  cost * (1 - prob)

private def evalCosts (cost : Float) (probs : Array Float) : Array Float :=
  probs.map (fun p => expCost cost p)

structure CostDemandPair where
  demand : Float
  cost : Float
deriving DecidableEq

def costDemandPairs (py : Python.DaemonProcess)
  (opt exp pes cost : Float)
  (probs : Array Float) :
    IO (Except String (Array CostDemandPair)) := do
  let costs := evalCosts cost probs
  let demands ← evalDemands py opt exp pes probs
  pure do
    let demands ← demands |> .mapError (s!"evalDemands: {·}")
    if h : demands.size ≠ costs.size then
      Except.error "Demands array size ≠ cost array size"
    else
      Except.ok ((Array.finRange demands.size).map
        (fun i =>
          { demand := demands[i], cost := costs[i] }))

namespace Distribute

-- linear is the function p = x
-- where p is the probability requested and x is the step normalized to [0, 1]
def linear (steps : ℕ) : Array Float :=
  (Array.range steps).map (fun i =>
    i.toFloat / steps.toFloat)

-- cubic is the function p = x^(1/3)
-- where p is the probability requested and x is the step normalized to [0, 1]
def cubic (steps : ℕ) : Array Float :=
  (Array.range steps).map (fun i =>
    (i.toFloat / steps.toFloat)^(1.0 / 3.0))

-- logarithmic is the function p = (ln(x)+a)/a
-- where p is the probability requested, x is the step normalized to [0, 1],
-- and a is a growth scaling factor which makes the growth towards 1 faster the
-- larger it is
-- when x is 0, p = 0 to avoid infinity
def logarithmic (factor : Float) (steps : ℕ) : Array Float :=
  (Array.range steps).map (fun i =>
    if i = 0 then
      0
    else
      ((Float.log (i.toFloat / steps.toFloat)) + factor) / factor)

end Distribute

end Stats.PERT
