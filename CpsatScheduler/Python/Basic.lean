import Mathlib.Data.Finset.Insert
import Mathlib.Algebra.Order.Group.Nat

namespace Python

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

abbrev ValidIdent (str : String) : Prop :=
  ∀ i : Fin str.toList.length, let c := str.toList[i];
    (c ≥ 'A' ∧ c ≤ 'Z') ∨
    (c ≥ 'a' ∧ c ≤ 'z') ∨
    c = '_' ∨
    (i.toNat > 0 → c ≥ '0' ∨ c ≤ '9')

def ValidName.Proof (name : String) : Prop :=
  ¬ (name ∈ ReservedKeywords) ∧ (ValidIdent name)

instance : Decidable (ValidName.Proof α) :=
  (inferInstance : Decidable (
    ¬ (α ∈ ReservedKeywords) ∧ (ValidIdent α)
  ))

structure ValidName where
  val : String
  proof : ValidName.Proof val
  deriving DecidableEq

set_option linter.style.nativeDecide false

def ValidName.of (val : String)
  (h : ValidName.Proof val := by native_decide) :
    ValidName :=
  ValidName.mk val h

namespace StdName

def stdin := ValidName.of "stdin"
def read := ValidName.of "read"
def len := ValidName.of "len"
def append := ValidName.of "append"
def eval := ValidName.of "eval"
def exec :=  ValidName.of "exec"
def join := ValidName.of "join"
def print := Python.ValidName.of "print"
def float := Python.ValidName.of "float"
def json := Python.ValidName.of "json"
def dumps := Python.ValidName.of "dumps"
def sys := ValidName.of "sys"
def list := ValidName.of "list"
def split := ValidName.of "split"
def flush := ValidName.of "flush"

end StdName

mutual

inductive Literal where
  | bool (val : Bool)
  | int (val : ℤ)
  | float (val : Float)
  | str (val : String)
  | array (elems : Array Expr)
  | dict (pairs : Array (Expr × Expr))
  | none

structure Kwarg where
  key : ValidName
  value : Expr

inductive Expr where
  | id (name : ValidName)
  | dot (expr : Expr) (field : ValidName)
  | lit (literal : Literal)
  | index (expr : Expr) (value : Expr)
  | slice (left right : Option Expr)
  | call (expr : Expr) (args : Array Expr) (kwargs : Array Kwarg)
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

end

mutual

def Kwarg.repr (kw : Kwarg) : String :=
  s!"{kw.key.val}={kw.value.repr}"
termination_by sizeOf kw
-- TODO: understand this later
decreasing_by
  obtain ⟨key, value⟩ := kw
  simp_wf

def Literal.repr (lit : Literal) : String :=
  match lit with
  | .bool b => match b with
    | Bool.true => "True"
    | Bool.false => "False"
  | .int i => toString i
  | .float f => toString f
  | .str s => s!"\"{s}\""
  | .array elems =>
    let elemStr := elems.map (fun e => e.repr)
    let joined := String.intercalate ", " elemStr.toList
    s!"[{joined}]"
  | .dict pairs =>
    let pairsStr := pairs.map (fun pair => s!"{pair.fst.repr}: {pair.snd.repr}");
    let joined := String.intercalate ", " pairsStr.toList;
    s!"\{{joined}}"
  | .none => "None"
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
  | .id name => name.val
  | .lit l => l.repr
  | .dot e attr => s!"{e.repr}.{attr.val}"
  | .slice l r => s!"{match l with
    | .some l => l.repr
    | .none => ""}:{match r with
    | .some r => r.repr
    | .none => ""}"
  | .index e idx => s!"{e.repr}[{idx.repr}]"
  | .call e args kwargs =>
    let args := args.map (fun (x : Expr) => x.repr)
    let kwargs := kwargs.map (fun (x : Kwarg) => x.repr)
    let joined := ", ".intercalate (args ++ kwargs).toList;
    s!"{e.repr}({joined})"
  | .add left right => s!"({left.repr} + {right.repr})"
  | .sub left right => s!"({left.repr} - {right.repr})"
  | .mul left right => s!"({left.repr} * {right.repr})"
  | .neg e => s!"-{e.repr}"
  | .bitwiseNot e => s!"~{e.repr}"
  | .eq left right => s!"{left.repr} == {right.repr}"
  | .neq left right => s!"{left.repr} != {right.repr}"
  | .gt left right => s!"{left.repr} > {right.repr}"
  | .gte left right => s!"{left.repr} >= {right.repr}"
  | .lt left right => s!"{left.repr} < {right.repr}"
  | .lte left right => s!"{left.repr} <= {right.repr}"
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

mutual

inductive IfContinuation where
  | elif (case : IfStatement)
  | «else» (body : Array Statement)

structure IfStatement where
  cond : Expr
  body : Array Statement
  next : Option IfContinuation

inductive Statement where
  | importLine (i : Import)
  | exprLine (e : Expr)
  | assignLine (lhs : Expr) (rhs : Expr)
  | whileLine (cond : Expr) (body : Array Statement)
  | forLine (it : Expr) (rng : Expr) (body : Array Statement)
  | ifLine (cases : IfStatement)
  | returnLine (e : Expr)
  | breakLine
  | delLine (e : Expr)

end

mutual

def indent (s : String) : String :=
  s.replace "\n" "\n\t"

def Block.repr (b : Array Statement) : String :=
  let lines := "\n".intercalate
    (b.map (fun x => x.repr)).toList
  indent s!"\t{lines}"
termination_by sizeOf b

def IfStatement.repr (case : IfStatement) : String :=
  let following := match _h1 : case.next with
    | .some cont => match _h2 : cont with
      | .elif nextCase => IfStatement.repr nextCase
      | .«else» elseBody => s!"else:\n{Block.repr elseBody}"
    | .none => ""
  s!"if {case.cond.repr}:\n{Block.repr case.body}\n{following}"
termination_by sizeOf case
decreasing_by
  all_goals
    first
    | -- body goal: sizeOf case.body < sizeOf case
      (obtain ⟨cond, body, next⟩ := case
       simp_wf
       omega)
    | -- elif / else goals: sizeOf nextCase|elseBody < sizeOf case
      (obtain ⟨cond, body, next⟩ := case
       subst _h2
       subst _h1
       simp_wf
       omega)

def Statement.repr (s : Statement) : String := match s with
  | .importLine i => i.repr
  | .exprLine e => e.repr
  | .assignLine l r => s!"{l.repr} = {r.repr}"
  | .whileLine c b => s!"while {c.repr}:\n{Block.repr b}"
  | .forLine i r b => s!"for {i.repr} in {r.repr}:\n{Block.repr b}"
  | .ifLine case => case.repr
  | .returnLine e => s!"return {e.repr}"
  | .breakLine => "break"
  | .delLine e => s!"del {e.repr}"
termination_by sizeOf s

end

instance : LE Python.Statement where
  le a b := a.repr ≤ b.repr

instance : DecidableLE Python.Statement :=
  fun a b => if h : a.repr ≤ b.repr then
    Decidable.isTrue h
  else
    Decidable.isFalse h

def print (expr : Expr) : Expr :=
  .call (.id StdName.print) #[ expr ]
    #[ ⟨StdName.flush, .lit (.bool true)⟩ ]

structure Script where
  statements : Array Statement

def Script.repr (s : Script) : String :=
  String.intercalate "\n"
    (s.statements.map (fun stmt => stmt.repr)).toList

def Script.serializeJson (expr : Expr) : Script :=
  ⟨#[
    -- import json
    .importLine (Import.fromForm
      #[StdName.json]
      #[ .unaliased StdName.dumps ]),
    -- print(dumps(...))
    .exprLine (print
      (.call (.id StdName.dumps) #[ expr ] #[]))
  ]⟩

structure Runtime where
  path : String

private def daemonFrontmatter : Array Statement := #[
  -- import sys
  .importLine (Import.basicForm #[StdName.sys] none),
]

private def daemonRuntime : Array Statement :=
  let chars := ValidName.of "__chars"
  let c := ValidName.of "__c"
  let code := ValidName.of "__code"
  #[
    .exprLine (print (.lit (.str "init"))),
    -- chars = []
    .assignLine (.id chars) (.lit (.array #[])),
    -- while True:
    .whileLine (.lit (.bool true))
      #[
        -- del chars[:]
        .delLine (.index (.id chars) (.slice .none .none)),
        -- c = None
        .assignLine (.id c) (.lit .none),
        .whileLine (.lit (.bool true))
          #[
            -- c = sys.stdin.read(1)
            .assignLine (.id c) (.call
              (.dot (.dot (.id StdName.sys) StdName.stdin) StdName.read)
              #[ .lit (.int 1) ]
              #[]),
            -- if c == '\0':
            --   break
            .ifLine {
              cond := .eq (.id c) (.lit (.str "\\0"))
              body := #[ .breakLine ]
              next := .none
            },
            -- chars.append(c)
            (.exprLine (.call
              (.dot (.id chars) StdName.append)
              #[ .id c ] #[]))
          ],
        -- exec("".join(chars))
        .exprLine
          (.call (.id StdName.exec)
            #[ .call (.dot (.lit (.str "")) StdName.join)
              #[ .id chars ] #[] ] #[])
      ]
  ]

def DaemonProcess.stdioConfig : IO.Process.StdioConfig :=
  {
    stdin := .piped
    stdout := .piped
    stderr := .inherit
  }

structure DaemonProcess where
  child : IO.Process.Child DaemonProcess.stdioConfig

def DaemonProcess.spawn (r : Runtime) (init : Array Statement) :
    IO DaemonProcess := do
  let script : Script := {
    statements := daemonFrontmatter ++ init ++ daemonRuntime
  }
  let child : IO.Process.Child DaemonProcess.stdioConfig ←
    IO.FS.withTempFile fun tempFile tempPath => do
      tempFile.write script.repr.toByteArray
      tempFile.flush
      let child ← IO.Process.spawn {
        cmd := r.path
        args := #[ tempPath.toString ]
        stdin := DaemonProcess.stdioConfig.stdin
        stdout := DaemonProcess.stdioConfig.stdout
        stderr := DaemonProcess.stdioConfig.stderr
      };
      -- wait for child to finish reading file & initializing
      -- before we can delete tmp init script
      let _ ← child.stdout.getLine
      pure child
  pure ⟨child⟩

def DaemonProcess.exec (proc : DaemonProcess)
  (script : Python.Script) :
    IO Unit := do
  proc.child.stdin.putStr s!"{script.repr}\x00"
  proc.child.stdin.flush
  pure ()

def DaemonProcess.execWithOutput (proc : DaemonProcess)
  (script : Python.Script) :
    IO String := do
  proc.exec script
  proc.child.stdout.getLine

def DaemonProcess.execWithJson (proc : DaemonProcess)
  (script : Python.Script) :
    IO (Except String Lean.Json) := do
  let output <- proc.execWithOutput script
  pure (match output with
    | "" => Except.error "got EOF"
    | _ => Lean.Json.parse output
      |> .mapError (s!"Lean.Json.parse ('{output}'): {·}"))

end Python
