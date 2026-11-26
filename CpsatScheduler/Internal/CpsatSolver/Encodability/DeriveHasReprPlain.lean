module

public import CpsatScheduler.Internal.CpsatSolver.Encodability.Defs
public import Lean.Elab.Deriving.Util

/-!
# `derive_has_repr_plain`

Generates `instance : HasRepr T` for a *plain* type `T` — a structure or
inductive whose every field is itself `HasRepr` (no `Prop`/proof fields),
possibly self-recursive, with type parameters allowed.

The generated encoding tags each constructor with its index and flattens the
field reprs with `encodeChunks`:

    toRepr (Cᵢ a₁ … aₖ) = i :: encodeChunks [toRepr a₁, …, toRepr aₖ]

This keeps the representation a flat `List ℕ` (no `Nat.pair` blowup).  The
injectivity proof is by structural induction: the leading tag separates
distinct constructors, `encodeChunks_inj` splits the field reprs apart, and
each field is closed by `HasRepr.toRepr_inj` (non-recursive fields) or the
induction hypothesis (self-recursive fields).

For *structures with proof fields* use `derive_has_repr_with_props`.
-/

@[expose] public section

namespace CpsatSolver.DeriveHasReprPlain
open Lean Parser.Term Elab Deriving Meta Command

public meta section

/-- Build the `toRepr` matcher body for `indVal`. -/
def mkToReprAlts (indVal : InductiveVal) (selfFun : Name) :
    TermElabM (Array (TSyntax ``matchAlt)) := do
    let mut alts := #[]
    for ctorName in indVal.ctors do
      let ctorInfo ← getConstInfoCtor ctorName
      alts := alts.push <| ← forallTelescopeReducing ctorInfo.type fun xs _ => do
        let mut ctorArgs : Array Term := #[]
        let mut rhsArgs : Array Term := #[]
        for _ in [:ctorInfo.numParams] do
          ctorArgs := ctorArgs.push (← `(_))
        for i in [:ctorInfo.numFields] do
          let a := mkIdent (← mkFreshUserName `a)
          ctorArgs := ctorArgs.push a
          let x := xs[ctorInfo.numParams + i]!
          let xTy ← inferType x
          rhsArgs := rhsArgs.push <| ←
            if xTy.isAppOf indVal.name then
              `($(mkIdent selfFun) $a)
            else
              `($(mkCIdent ``HasRepr.toRepr) $a)
        let pattern ← `(@$(mkIdent ctorName):ident $ctorArgs:term*)
        let chunks ← `([$rhsArgs,*])
        let rhs ← `($(quote ctorInfo.cidx) :: $(mkCIdent ``encodeChunks) $chunks)
        `(matchAltExpr| | $pattern:term => $rhs)
    return alts

/-- Build the induction-based injectivity proof tactic. -/
def mkInjTactic (indVal : InductiveVal) (selfFun : Name) :
    TermElabM (TSyntax `tactic) := do
  -- one `induction` alternative per constructor
  let mut indAlts : Array (TSyntax ``Lean.Parser.Tactic.inductionAlt) := #[]
  for ctorName in indVal.ctors do
    let ctorInfo ← getConstInfoCtor ctorName
    -- Classify fields and allocate idents.  Induction-alternative binders are
    -- all constructor fields first, then one IH per self-recursive field.
    let (fieldIdents, recFlags) ←
      forallTelescopeReducing ctorInfo.type fun xs _ => do
        let mut fis : Array (TSyntax `ident) := #[]
        let mut flags : Array Bool := #[]
        for i in [:ctorInfo.numFields] do
          let x := xs[ctorInfo.numParams + i]!
          let xTy ← inferType x
          fis := fis.push (mkIdent (← mkFreshUserName `a))
          flags := flags.push (xTy.isAppOf indVal.name)
        return (fis, flags)
    -- IH idents, one per recursive field, aligned by field index (`none` for
    -- non-recursive fields).
    let mut ihIdents : Array (Option (TSyntax `ident)) := #[]
    let mut ihBinders : Array (TSyntax `ident) := #[]
    for i in [:ctorInfo.numFields] do
      if recFlags[i]! then
        let ih := mkIdent (← mkFreshUserName `ih)
        ihIdents := ihIdents.push (some ih)
        ihBinders := ihBinders.push ih
      else
        ihIdents := ihIdents.push none
    let fieldVars := fieldIdents ++ ihBinders
    -- body of this alternative
    let b := mkIdent (← mkFreshUserName `b)
    let hb := mkIdent (← mkFreshUserName `hb)
    let hh := mkIdent (← mkFreshUserName `hh)
    -- per-field resolution: build equalities from `hh`, then reconstruct the
    -- constructor equality.
    let mut fieldEqNames : Array (TSyntax `ident) := #[]
    for _ in [:ctorInfo.numFields] do
      fieldEqNames := fieldEqNames.push (mkIdent (← mkFreshUserName `he))
    -- rewrite steps: for each field, `rw` using toRepr_inj or the IH.
    let mut rwTerms : Array Term := #[]
    for i in [:ctorInfo.numFields] do
      let eqn := fieldEqNames[i]!
      match ihIdents[i]! with
      | some ih => rwTerms := rwTerms.push (← `($ih $eqn))
      | none => rwTerms := rwTerms.push (← `($(mkCIdent ``HasRepr.toRepr_inj) $eqn))
    -- destructuring pattern for `hh` into the per-field equalities.  `hh` is
    -- an iterated `∧` of `ctorInfo.numFields` equalities (or `True` when 0).
    let altBody : TSyntax `tactic ←
      if ctorInfo.numFields == 0 then
        `(tactic| (
          intro $b:ident $hb:ident
          cases $b:ident
          all_goals
            (simp only [$(mkIdent selfFun):ident, List.cons.injEq] at $hb:ident
             try (exact absurd ($hb:ident).1 (by decide)))
          rfl))
      else if ctorInfo.numFields == 1 then
        -- single field: after `and_true`, `hh` is the bare equality
        let eqn := fieldEqNames[0]!
        `(tactic| (
          intro $b:ident $hb:ident
          cases $b:ident
          all_goals
            (simp only [$(mkIdent selfFun):ident, List.cons.injEq] at $hb:ident
             try (exact absurd ($hb:ident).1 (by decide)))
          obtain ⟨_, $hh:ident⟩ := $hb:ident
          replace $hh:ident := $(mkCIdent ``encodeChunks_inj) $hh:ident
          simp only [List.cons.injEq, and_true] at $hh:ident
          have $eqn:ident := $hh:ident
          rw [$[$rwTerms:term],*]))
      else
        -- pattern `⟨he0, he1, …⟩`
        let patt ← `(rcasesPat| ⟨$[$fieldEqNames],*⟩)
        `(tactic| (
          intro $b:ident $hb:ident
          cases $b:ident
          all_goals
            (simp only [$(mkIdent selfFun):ident, List.cons.injEq] at $hb:ident
             try (exact absurd ($hb:ident).1 (by decide)))
          obtain ⟨_, $hh:ident⟩ := $hb:ident
          replace $hh:ident := $(mkCIdent ``encodeChunks_inj) $hh:ident
          simp only [List.cons.injEq, and_true] at $hh:ident
          obtain $patt := $hh:ident
          rw [$[$rwTerms:term],*]))
    -- the induction alternative with field + ih binders
    let altName := mkIdent ctorName.componentsRev.head!
    indAlts := indAlts.push <| ←
      `(Lean.Parser.Tactic.inductionAlt|
        | $altName:ident $fieldVars* => $altBody:tactic)
  let x := mkIdent (← mkFreshUserName `x)
  `(tactic| (
    intro $x:ident
    induction $x:ident with
    $indAlts:inductionAlt*))

/-- Emit the full command set for `declName`. -/
def mkCmds (declName : Name) : TermElabM (Array (TSyntax `command)) := do
  let indVal ← getConstInfoInduct declName
  if indVal.isNested || indVal.numIndices != 0 || indVal.all.length != 1 then
    throwError "`derive_has_repr_plain` only supports non-nested, non-indexed, \
      single (possibly self-recursive) inductives/structures; `{declName}` is not"
  let header ← mkHeader ``HasRepr 1 indVal
  -- function name
  let selfFun ← mkFreshUserName (declName ++ `hasRepr_toRepr)
  let injName ← mkFreshUserName (declName ++ `hasRepr_toRepr_inj)
  let alts ← mkToReprAlts indVal selfFun
  -- binders without the final target binder (which belongs to the function)
  let binders := header.binders[0:header.binders.size - 1]
  let funCmd ← `(
    @[expose] def $(mkIdent selfFun):ident $binders:bracketedBinder* :
      $header.targetType → $(mkCIdent ``ReprType)
      $alts:matchAlt*)
  let injTac ← mkInjTactic indVal selfFun
  -- argument idents for applying the aux function under the shared binders
  let argTerms : Array Term := header.argNames.map (fun n => ⟨(mkIdent n).raw⟩)
  let injCmd ← `(
    theorem $(mkIdent injName):ident $binders:bracketedBinder* :
      $(mkCIdent ``Function.Injective)
        (@$(mkIdent selfFun):ident $argTerms*) := by
      $injTac:tactic)
  -- instance
  let argNames ← mkInductArgNames indVal
  let instBinders ← mkImplicitBinders argNames
  let instBinders2 ← mkInstImplicitBinders ``HasRepr indVal argNames
  let allInstBinders := instBinders.map (⟨·.raw⟩) ++ instBinders2.map (⟨·⟩)
  let indType ← mkInductiveApp indVal argNames
  let instArgTerms : Array Term := argNames.map (fun n => ⟨(mkIdent n).raw⟩)
  let instCmd ← `(
    instance $allInstBinders:bracketedBinder* : $(mkCIdent ``HasRepr) $indType :=
      ⟨@$(mkIdent selfFun):ident $instArgTerms*,
       @$(mkIdent injName):ident $instArgTerms*⟩)
  return #[funCmd, injCmd, instCmd]

syntax (name := deriveHasReprPlainCmd) "derive_has_repr_plain " ident,+ : command

@[command_elab deriveHasReprPlainCmd]
def elabDeriveHasReprPlain : CommandElab := fun stx => do
  match stx with
  | `(derive_has_repr_plain $ids:ident,*) => do
    for id in ids.getElems do
      let declName ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
      let cmds ← liftTermElabM <| mkCmds declName
      for cmd in cmds do
        elabCommand cmd
  | _ => throwUnsupportedSyntax

end

end CpsatSolver.DeriveHasReprPlain
