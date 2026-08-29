import Regex
import Mathlib.Data.Finset.Defs
import Mathlib.Data.Finset.Insert

namespace CpsatSolver.Python

def ReservedKeywords : Finset String := {
  "False",
  "await",
  "else",
  "import",
  "pass",
  "None",
  "break",
  "except",
  "in",
  "raise",
  "True",
  "class",
  "finally",
  "is",
  "return",
  "and",
  "continue",
  "for",
  "lambda",
  "try",
  "as",
  "def",
  "from",
  "nonlocal",
  "while",
  "assert",
  "del",
  "global",
  "not",
  "with",
  "async",
  "elif",
  "if",
  "or",
  "yield"
}

def IDRegex := re! r"^[A-Za-z_][0-9A-Za-z_]+$"

def ValidName.Proof (name : String) : Prop :=
  ¬ (name ∈ ReservedKeywords) ∧ (IDRegex.test name)

instance : Decidable (ValidName.Proof α) :=
  (inferInstance : Decidable (
    ¬ (α ∈ ReservedKeywords) ∧ (IDRegex.test α)
  ))

structure ValidName where
  val : String
  proof : ValidName.Proof val
  deriving DecidableEq

mutual

inductive Literal where
  | bool (val : Bool)
  | int (val : ℤ)
  | str (val : String)
  | array (elems : Array Expr)

inductive Expr where
  | id (name : ValidName)
  | dot (expr : Expr) (field : ValidName)
  | lit (literal : Literal)
  | index (expr : Expr) (value : Expr)
  | call (expr : Expr) (args : Array Expr)
  | add (left : Expr) (right : Expr)
  | sub (left : Expr) (right : Expr)
  | mul (left : Expr) (right : Expr)
  | neg (expr : Expr)
  | bitwiseNot (expr : Expr)
  | eq (left : Expr) (right : Expr)
  | neq (left : Expr) (right : Expr)
  | gt (left : Expr) (right : Expr)
  | gte (left : Expr) (right : Expr)
  | lt (left : Expr) (right : Expr)
  | lte (left : Expr) (right : Expr)
  | assign (left : Expr) (right : Expr)

end

mutual

def Literal.repr (lit : Literal) : String :=
  match lit with
  | Literal.bool b => match b with
    | Bool.true => "True"
    | Bool.false => "False"
  | Literal.int i => toString i
  | Literal.str s => Lean.Json.compress (Lean.Json.str s)
  | Literal.array elems =>
    let elemStr := elems.map (fun e => e.repr)
    let joined := String.intercalate ", " elemStr.toList
    s!"[{joined}]"

def Expr.repr (expr : Expr) : String :=
  match expr with
  | Expr.id name => name.val
  | Expr.lit l => l.repr
  | Expr.dot e attr => s!"{e.repr}.{attr.val}"
  | Expr.index e idx => s!"{e.repr}[{idx.repr}]"
  | Expr.call e args =>
    let argsJoined :=
      ", ".intercalate (args.map (fun (x : Expr) => x.repr)).toList;
    s!"{e.repr}({argsJoined})"
  | Expr.add left right => s!"({left.repr} + {right.repr})"
  | Expr.sub left right => s!"({left.repr} - {right.repr})"
  | Expr.mul left right => s!"({left.repr} * {right.repr})"
  | Expr.neg e => s!"-{e.repr}"
  | Expr.bitwiseNot e => s!"~{e.repr}"
  | Expr.eq left right => s!"{left.repr} == {right.repr}"
  | Expr.neq left right => s!"{left.repr} != {right.repr}"
  | Expr.gt left right => s!"{left.repr} > {right.repr}"
  | Expr.gte left right => s!"{left.repr} >= {right.repr}"
  | Expr.lt left right => s!"{left.repr} < {right.repr}"
  | Expr.lte left right => s!"{left.repr} <= {right.repr}"
  | Expr.assign left right => s!"{left.repr} = {right.repr}"

end

instance : ToString Expr where
  toString := Expr.repr

end CpsatSolver.Python
