module

public import Lean.Elab.Deriving.Util
public import Mathlib.Logic.Encodable.Basic

/-!
# Module-system-compatible `Encodable` derivation

A fork of Mathlib's `Encodable` deriving handler (`Mathlib.Tactic.DeriveEncodable`)
that works under the Lean module system.

Mathlib's handler emits `private` helper functions and references a `private`
helper type `S`. Under the module system `private` means name-inaccessible
across the elaboration boundary, so the generated code refers to daggered
names (`Mathlib.Deriving.Encodable.S✝`, `instEncodable…_toS✝`, …) that fail to
resolve — the generated `cases`/instance break with `sorry`. This fork makes
`S`, its helpers, and the generated functions `@[expose]`/public, which
resolves both failures.

Exposed as the command `derive_encodable_plain Foo` (see below) rather than a
`deriving` handler, to avoid nondeterministic dispatch against Mathlib's
(transitively imported, broken) `Encodable` handler.
-/

@[expose] public section

namespace CpsatSolver.DeriveEncodablePlain
open Lean Parser.Term Elab Deriving Meta Command

inductive S : Type where
  | nat (n : ℕ)
  | cons (a b : S)

def S.encode : S → ℕ
  | nat n => Nat.pair 0 n
  | cons a b => Nat.pair (S.encode a + 1) (S.encode b)

lemma nat_unpair_lt_2 {n : ℕ} (h : (Nat.unpair n).1 ≠ 0) : (Nat.unpair n).2 < n := by
  obtain ⟨⟨a, b⟩, rfl⟩ := Nat.pairEquiv.surjective n
  simp only [Nat.pairEquiv_apply, Function.uncurry_apply_pair, Nat.unpair_pair] at *
  unfold Nat.pair
  have := Nat.le_mul_self a
  have := Nat.le_mul_self b
  split <;> lia

def S.decode (n : ℕ) : S :=
  let p := Nat.unpair n
  if h : p.1 = 0 then
    S.nat p.2
  else
    have : p.1 ≤ n := Nat.unpair_left_le n
    have := Nat.unpair_lt (by lia : 1 ≤ n)
    have := nat_unpair_lt_2 h
    S.cons (S.decode (p.1 - 1)) (S.decode p.2)

def S_equiv : S ≃ ℕ where
  toFun := S.encode
  invFun := S.decode
  left_inv s := by
    induction s with
    | nat n => unfold S.encode S.decode; simp
    | cons a b iha ihb => unfold S.encode S.decode; simp [iha, ihb]
  right_inv n := by
    induction n using Nat.strongRecOn with | _ n ih =>
    unfold S.decode
    dsimp only
    split
    next h => unfold S.encode; rw [← h, Nat.pair_unpair]
    next h =>
      unfold S.encode
      rw [ih, ih, Nat.sub_add_cancel, Nat.pair_unpair]
      · rwa [Nat.one_le_iff_ne_zero]
      · exact nat_unpair_lt_2 h
      · obtain _ | n' := n
        · exact False.elim (h (by simp))
        · have := Nat.unpair_lt (by lia : 1 ≤ n' + 1); lia

instance : Encodable S := Encodable.ofEquiv ℕ S_equiv

public meta section

def mkToSMatch (ctx : Deriving.Context) (header : Header) (indVal : InductiveVal)
    (toSNames : Array Name) : TermElabM Term := do
  let discrs ← mkDiscrs header indVal
  let alts ← mkAlts
  `(match $[$discrs],* with $alts:matchAlt*)
where
  mkAlts : TermElabM (Array (TSyntax ``matchAlt)) := do
    let mut alts := #[]
    for ctorName in indVal.ctors do
      let ctorInfo ← getConstInfoCtor ctorName
      alts := alts.push <| ← forallTelescopeReducing ctorInfo.type fun xs _ => do
        let mut patterns := #[]
        let mut ctorArgs := #[]
        let mut rhsArgs : Array Term := #[]
        for _ in [:indVal.numIndices] do
          patterns := patterns.push (← `(_))
        for _ in [:ctorInfo.numParams] do
          ctorArgs := ctorArgs.push (← `(_))
        for i in [:ctorInfo.numFields] do
          let a := mkIdent (← mkFreshUserName `a)
          ctorArgs := ctorArgs.push a
          let x := xs[ctorInfo.numParams + i]!
          let xTy ← inferType x
          let recName? := ctx.typeInfos.findIdx? (xTy.isAppOf ·.name) |>.map (toSNames[·]!)
          rhsArgs := rhsArgs.push <| ←
            if let some recName := recName? then
              `($(mkIdent recName) $a)
            else
              ``(S.nat (Encodable.encode $a))
        patterns := patterns.push (← `(@$(mkIdent ctorName):ident $ctorArgs:term*))
        let rhs' : Term ← rhsArgs.foldrM (init := ← ``(S.nat 0)) fun arg acc => ``(S.cons $arg $acc)
        let rhs : Term ← ``(S.cons (S.nat $(quote ctorInfo.cidx)) $rhs')
        `(matchAltExpr| | $[$patterns:term],* => $rhs)
    return alts

def mkToSFuns (ctx : Deriving.Context) (toSFunNames : Array Name) :
    TermElabM (TSyntax `command) := do
  let mut res : Array (TSyntax `command) := #[]
  for i in [:toSFunNames.size] do
    let toNatFnName := toSFunNames[i]!
    let indVal := ctx.typeInfos[i]!
    let header ← mkHeader ``Encodable 1 indVal
    let body ← mkToSMatch ctx header indVal toSFunNames
    res := res.push <| ← `(
      @[expose] def $(mkIdent toNatFnName):ident $header.binders:bracketedBinder* :
        $(mkCIdent ``S) := $body:term
      )
  `(command| mutual $[$res:command]* end)

def mkFromSMatch (ctx : Deriving.Context) (indVal : InductiveVal)
    (fromSNames : Array Name) : TermElabM Term := do
  let alts ← mkAlts
  `(fun $alts:matchAlt*)
where
  mkAlts : TermElabM (Array (TSyntax ``matchAlt)) := do
    let mut alts := #[]
    for ctorName in indVal.ctors do
      let ctorInfo ← getConstInfoCtor ctorName
      alts := alts.push <| ← forallTelescopeReducing ctorInfo.type fun xs _ => do
        let mut patternArgs : Array Term := #[]
        let mut discrs : Array (TSyntax ``Lean.Parser.Term.matchDiscr) := #[]
        let mut ctorArgs : Array Term := #[]
        let mut patternArgs2 : Array Term := #[]
        let mut patternArgs3 : Array Term := #[]
        for _ in [:indVal.numParams] do
          ctorArgs := ctorArgs.push (← `(_))
        for i in [:ctorInfo.numFields] do
          let a := mkIdent (← mkFreshUserName `a)
          let x := xs[ctorInfo.numParams + i]!
          let xTy ← inferType x
          let recName? := ctx.typeInfos.findIdx? (xTy.isAppOf ·.name) |>.map (fromSNames[·]!)
          if let some recName := recName? then
            patternArgs := patternArgs.push a
            discrs := discrs.push <| ← `(matchDiscr| $(mkIdent recName) $a)
          else
            patternArgs := patternArgs.push <| ← ``(S.nat $a)
            discrs := discrs.push <| ← `(matchDiscr| $(mkCIdent ``Encodable.decode) $a)
          ctorArgs := ctorArgs.push a
          patternArgs2 := patternArgs2.push <| ← ``(some $a)
          patternArgs3 := patternArgs3.push <| ← `(_)
        let pattern ← patternArgs.foldrM (init := ← ``(S.nat 0)) fun arg acc => ``(S.cons $arg $acc)
        let pattern ← ``(S.cons (S.nat $(quote ctorInfo.cidx)) $pattern)
        let res ← ``(some <| @$(mkIdent ctorName):ident $ctorArgs:term*)
        if discrs.isEmpty then
          `(matchAltExpr| | $pattern:term => $res)
        else
          let rhs : Term ← `(
              match $[$discrs],* with
              | $[$patternArgs2],* => $res
              | $[$patternArgs3],* => none
            )
          `(matchAltExpr| | $pattern:term => $rhs)
    alts := alts.push <| ← `(matchAltExpr| | _ => none)
    return alts

def mkFromSFuns (ctx : Deriving.Context) (fromSFunNames : Array Name) :
    TermElabM (TSyntax `command) := do
  let mut res : Array (TSyntax `command) := #[]
  for i in [:fromSFunNames.size] do
    let fromNatFnName := fromSFunNames[i]!
    let indVal := ctx.typeInfos[i]!
    let header ← mkHeader ``Encodable 1 indVal
    let body ← mkFromSMatch ctx indVal fromSFunNames
    let binders := header.binders[0:header.binders.size - 1]
    res := res.push <| ← `(
      @[expose] def $(mkIdent fromNatFnName):ident $binders:bracketedBinder* :
        $(mkCIdent ``S) → Option $header.targetType := $body:term
      )
  `(command| mutual $[$res:command]* end)

def mkInjThms (ctx : Deriving.Context) (toSFunNames fromSFunNames : Array Name) :
    TermElabM (TSyntax `command) := do
  let mut res : Array (TSyntax `command) := #[]
  for i in [:toSFunNames.size] do
    let toSFunName := toSFunNames[i]!
    let fromSFunName := fromSFunNames[i]!
    let injThmName := ctx.auxFunNames[i]!
    let indVal := ctx.typeInfos[i]!
    let header ← mkHeader ``Encodable 1 indVal
    let enc := mkIdent toSFunName
    let dec := mkIdent fromSFunName
    let t := mkIdent header.targetNames[0]!
    let lemmas : TSyntaxArray ``Parser.Tactic.simpLemma ← ctx.auxFunNames.mapM fun i =>
      `(Parser.Tactic.simpLemma| $(mkIdent i):term)
    let tactic : Term ← `(by
        cases $t:ident
        <;> (unfold $(mkIdent toSFunName):ident $(mkIdent fromSFunName):ident;
              simp only [Encodable.encodek, $lemmas,*]; try rfl)
      )
    res := res.push <| ← `(
      theorem $(mkIdent injThmName):ident $header.binders:bracketedBinder* :
        $dec ($enc $t) = some $t := $tactic
      )
  `(command| mutual $[$res:command]* end)

open TSyntax.Compat in
def mkEncodableInstanceCmds (ctx : Deriving.Context) (typeNames : Array Name)
    (toSFunNames fromSFunNames : Array Name) : TermElabM (Array Command) := do
  let mut instances := #[]
  for i in [:ctx.typeInfos.size] do
    let indVal := ctx.typeInfos[i]!
    if typeNames.contains indVal.name then
      let auxFunName   := ctx.auxFunNames[i]!
      let argNames     ← mkInductArgNames indVal
      let binders      ← mkImplicitBinders argNames
      let binders      := binders ++ (← mkInstImplicitBinders ``Encodable indVal argNames)
      let indType      ← mkInductiveApp indVal argNames
      let type         ← `($(mkCIdent ``Encodable) $indType)
      let encode       := mkIdent toSFunNames[i]!
      let decode       := mkIdent fromSFunNames[i]!
      let kencode      := mkIdent auxFunName
      let instCmd ← `(
        instance $binders:implicitBinder* : $type :=
          $(mkCIdent ``Encodable.ofLeftInjection) $encode $decode $kencode
        )
      instances := instances.push instCmd
  return instances

def mkEncodableCmds (indVal : InductiveVal) (declNames : Array Name) :
    TermElabM (Array Syntax) := do
  let ctx ← mkContext ``Encodable "myencodable" indVal.name
  let toSFunNames : Array Name ← ctx.auxFunNames.mapM fun name => do
    let .str n' s := name.eraseMacroScopes | unreachable!
    mkFreshUserName <| .str n' (s ++ "_toS")
  let fromSFunNames : Array Name ← ctx.auxFunNames.mapM fun name => do
    let .str n' s := name.eraseMacroScopes | unreachable!
    mkFreshUserName <| .str n' (s ++ "_fromS")
  let cmds :=
    #[← mkToSFuns ctx toSFunNames,
      ← mkFromSFuns ctx fromSFunNames,
      ← mkInjThms ctx toSFunNames fromSFunNames]
    ++ (← mkEncodableInstanceCmds ctx declNames toSFunNames fromSFunNames)
  return cmds

open Command

def mkEncodableInstance (declNames : Array Name) : CommandElabM Bool := do
  let mut seen : NameSet := {}
  let mut toVisit : Array InductiveVal := #[]
  for declName in declNames do
    if seen.contains declName then continue
    let indVal ← getConstInfoInduct declName
    if indVal.isNested || indVal.isReflexive || indVal.numIndices != 0 then
      return false
    seen := seen.append (NameSet.ofList indVal.all)
    toVisit := toVisit.push indVal
  for indVal in toVisit do
    let cmds ← liftTermElabM <| mkEncodableCmds indVal (declNames.filter indVal.all.contains)
    withEnableInfoTree false do
      elabCommand <| mkNullNode cmds
  return true

/-- `derive_encodable_plain Foo` generates `instance : Encodable Foo` for a
    *plain* type — a structure or inductive whose every field is itself
    `Encodable` (no `Prop`/proof fields). Works for recursive inductives.

    Module-system-compatible replacement for Mathlib's `deriving Encodable`.
    Mathlib's deriving handler emits `private` helpers and references a
    `private` type `S`; under the Lean module system those become
    name-inaccessible (`✝`), breaking the generated `cases`/instance. This
    version emits `@[expose]`/public helpers and an accessible `S`, so it
    works inside `module` + `public section`.

    We expose this as a command rather than a `deriving` handler on purpose:
    `Mathlib.Tactic` (transitively) registers its own broken `Encodable`
    handler, and handler dispatch order is not guaranteed, so the native
    `deriving Encodable` clause may pick Mathlib's. A dedicated command is
    deterministic.

    Handles non-nested, non-reflexive, non-indexed types. For *structures with
    proof fields* (a `Prop` field regenerated on decode via `Decidable`) use
    `derive_encodable_with_props` instead. -/
syntax (name := deriveEncodablePlainCmd) "derive_encodable_plain " ident,+ : command

@[command_elab deriveEncodablePlainCmd]
def elabDeriveEncodablePlain : CommandElab := fun stx => do
  match stx with
  | `(derive_encodable_plain $ids:ident,*) => do
    let names ← ids.getElems.mapM fun id =>
      liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
    let ok ← mkEncodableInstance names
    unless ok do
      throwError "`derive_encodable_plain` does not support one of {names} \
        (nested, reflexive, or indexed inductive)"
  | _ => throwUnsupportedSyntax

end

end CpsatSolver.DeriveEncodablePlain
