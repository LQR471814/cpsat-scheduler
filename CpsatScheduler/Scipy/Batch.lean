import CpsatScheduler.Scipy.Basic

/-!
# `PertM`: batched Python evaluation monad

To avoid spawning one Python subprocess per PERT evaluation, `PertM` accumulates
requested `Python.Expr` computations in state and flushes **all** of them in a
single script execution.

Usage:
```
PertM.run runtime do
  let h₁ ← PertM.request expr₁
  let h₂ ← PertM.request expr₂
  pure (h₁, h₂)
```
`PertM.run` returns the monad's result alongside the resolved `Array Float`
(indexed by the handles). Exactly one Python process is spawned regardless of the
number of requests.
-/

namespace Scipy

open Scipy

/-- Accumulator state: the list of requested expressions, in request order. -/
structure PertState where
  requests : Array Python.Expr := #[]

/-- Opaque handle to a deferred evaluation result: an index into the resolved
`Array Float` produced by `PertM.run`. -/
structure PertHandle where
  idx : Nat
deriving DecidableEq, Repr, Inhabited

/-- Batched-evaluation monad: state threading over `IO`. -/
abbrev PertM := StateT PertState IO

/-- Register an expression for batched evaluation; returns its handle. -/
def PertM.request (e : Python.Expr) : PertM PertHandle := do
  let s ← get
  let idx := s.requests.size
  set { s with requests := s.requests.push e }
  pure ⟨idx⟩

/-- Build the single batched script:
```
from scipy.stats import beta
from json import dumps
print(dumps([expr0, expr1, ...]))
```
`json.dumps` guarantees the output is valid JSON (a plain array of floats), which
`parseFloatArray` consumes. Exactly one `print` is emitted regardless of the
request count. -/
def mkBatchScript (exprs : Array Python.Expr) : Python.Script :=
  {
    statements := #[
      (Python.Statement.importLine
        (Python.Import.fromForm
          #[ Name.scipy, Name.stats ]
          #[ (Python.NameAs.unaliased Name.beta) ])),
      (Python.Statement.importLine
        (Python.Import.fromForm
          #[ Name.json ]
          #[ (Python.NameAs.unaliased Name.dumps) ])),
      (Python.Statement.exprLine
        (Python.Expr.call
          (Python.Expr.id Name.print)
          #[
            Python.Expr.call
              (Python.Expr.id Name.dumps)
              #[ Python.Expr.lit (Python.Literal.array exprs) ]
          ]))
    ]
  }

/-- Parse the JSON array printed by `mkBatchScript` into an `Array Float`. -/
def parseFloatArray (stdout : String) : Except String (Array Float) :=
  match Lean.Json.parse stdout with
  | Except.error err => Except.error s!"parse json: {err}"
  | Except.ok json =>
    match json.getArr? with
    | Except.error err => Except.error s!"expected json array: {err}"
    | Except.ok elems =>
      elems.foldlM
        (fun acc el =>
          match el with
          | Lean.Json.num n => Except.ok (acc.push n.toFloat)
          | _ => Except.error "expected float element in array")
        #[]

/-- Resolve a handle against a resolved results array. -/
def PertHandle.resolve (h : PertHandle) (results : Array Float) : Option Float :=
  results[h.idx]?

/-- Run a `PertM` computation: accumulate all requests, execute exactly **one**
Python script, and return the computed value together with the resolved results.
An empty request set short-circuits without spawning a process. -/
def PertM.run (runtime : Python.Runtime) (x : PertM α) :
    IO (α × Array Float) := do
  let (a, s) ← StateT.run x {}
  if s.requests.isEmpty then
    pure (a, #[])
  else
    let script := mkBatchScript s.requests
    let out ← script.exec runtime
    match parseFloatArray out.stdout with
    | Except.ok results => pure (a, results)
    | Except.error err =>
      throw (IO.userError s!"PertM.run: {err}\nstdout: {out.stdout}\nstderr: {out.stderr}")

end Scipy
