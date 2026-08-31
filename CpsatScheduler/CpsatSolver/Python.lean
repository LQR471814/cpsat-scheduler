import Regex
import Mathlib.Data.Finset.Defs
import Mathlib.Data.Finset.Insert
import Mathlib.Data.String.Basic
import Mathlib.Order.Defs.PartialOrder

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
  | dict (pairs : Array (Expr × Expr))

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
  | Literal.dict pairs =>
    let pairsStr := pairs.map (fun pair => s!"{pair.fst.repr}: {pair.snd.repr}");
    let joined := String.intercalate ", " pairsStr.toList;
    s!"\{{joined}}"
termination_by sizeOf lit
-- TODO: understand this later
decreasing_by
  all_goals
    first
    | decreasing_trivial
    | have hpair := Array.sizeOf_lt_of_mem ‹_›
      cases pair
      simp_all
      omega

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
termination_by sizeOf expr

end

instance : ToString Expr where
  toString := Expr.repr

structure NameAs where
  name : ValidName
  as : Option ValidName

def NameAs.unaliased (n : ValidName) : NameAs :=
  { name := n, as := Option.none }

def NameAs.aliased (n : ValidName) (as : ValidName) : NameAs :=
  { name := n, as := Option.some as }

def NameAs.repr (a : NameAs) : String :=
  match a.as with
  | Option.some as => s!"{a.name.val} as {as.val}"
  | Option.none => a.name.val

inductive Import where
  | basicForm (pkg : Array ValidName) (as : Option ValidName)
  | fromForm (pkg : Array ValidName) (names : Array NameAs)

def Import.repr (i : Import) := match i with
  | basicForm pkg as =>
    let path := String.intercalate "."
      (pkg.map (fun (x : ValidName) => x.val)).toList
    match as with
    | Option.some asName =>
      s!"import {path} as {asName.val}"
    | Option.none =>
      s!"import {path}"
  | fromForm pkg importedNames =>
    let path := String.intercalate "."
      (pkg.map (fun (x : ValidName) => x.val)).toList
    let importedNames := String.intercalate ", "
      (importedNames.map (fun (x : NameAs) => x.repr)).toList
    s!"from {path} import {importedNames}"

inductive Statement where
  | importLine (i : Import)
  | exprLine (e : Expr)

def Statement.repr (s : Statement) := match s with
  | importLine i => i.repr
  | exprLine e => e.repr

instance : LE Python.Statement where
  le a b := a.repr ≤ b.repr

instance : DecidableLE Python.Statement :=
  fun a b => if h : a.repr ≤ b.repr then
    Decidable.isTrue h
  else
    Decidable.isFalse h

structure Script where
  statements : Array Statement

def Script.repr (s : Script) : String :=
  String.intercalate "\n"
    (s.statements.map (fun stmt => stmt.repr)).toList

end CpsatSolver.Python
