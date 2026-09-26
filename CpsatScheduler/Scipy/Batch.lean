import CpsatScheduler.Scipy.Basic

namespace Scipy

open Scipy

structure PertState where
  requests : Array Python.Expr := #[]

structure PertHandle where
  idx : Nat
deriving DecidableEq, Repr, Inhabited

abbrev PertM := StateT PertState IO

def PertM.request (e : Python.Expr) : PertM PertHandle := do
  let idx := (← get).requests.size
  modify fun s => { s with requests := s.requests.push e }
  pure ⟨idx⟩

def mkBatchScript (exprs : Array Python.Expr) : Python.Script where
  statements := #[
    .importLine (.fromForm #[Name.scipy, Name.stats] #[.unaliased Name.beta]),
    .importLine (.fromForm #[Name.json] #[.unaliased Name.dumps]),
    .exprLine (.call (.id Name.print) #[.call (.id Name.dumps) #[.lit (.array exprs)]])
  ]

def parseFloatArray (stdout : String) : Except String (Array Float) := do
  let json ← Lean.Json.parse stdout
  let elems ← json.getArr?
  elems.mapM fun el => match el with
    | .num n => pure n.toFloat
    | _ => throw "expected float array element"

def PertM.run (runtime : Python.Runtime) (x : PertM α) : IO (α × Array Float) := do
  let (a, s) ← StateT.run x {}
  if s.requests.isEmpty then
    return (a, #[])
  let out ← (mkBatchScript s.requests).exec runtime
  match parseFloatArray out.stdout with
  | .ok results => pure (a, results)
  | .error err => throw (IO.userError s!"PertM.run: {err}\n{out.stdout}\n{out.stderr}")

end Scipy
