module

public import CpsatScheduler.Internal.CpsatSolver.Encodability.Defs
public import Lean.Elab.Command

/-!
# `derive_has_repr_with_props`

Generates `instance : HasRepr S` for a single-constructor structure `S` whose
fields split into:
  * DATA fields  — non-`Prop` typed; the identity-bearing payload.
  * PROOF fields — `Prop` typed; decidable predicates over the data fields.

Only the data fields are serialized (`encodeChunks` of their reprs).  Proof
fields are *not* serialized: once the data fields are known equal, the proof
fields are equal by proof irrelevance (they inhabit the same `Prop`).  So
identity rides on the data fields only — matching `derive_encodable_with_props`.
-/

@[expose] public section

namespace CpsatSolver.DeriveHasReprWithProps
open Lean Elab Command Meta Term

private meta structure FieldKind where
  name : Name
  isProof : Bool
deriving Inhabited

private meta def classifyFields (structName : Name) : MetaM (Array FieldKind) := do
  let env ← getEnv
  let some _ := getStructureInfo? env structName
    | throwError "`{structName}` is not a structure"
  let ctorVal := getStructureCtor env structName
  let fieldNames := getStructureFields env structName
  forallTelescopeReducing ctorVal.type fun params _ => do
    let numParams := ctorVal.numParams
    let numFields := fieldNames.size
    unless params.size == numParams + numFields do
      throwError "unexpected constructor arity for `{structName}`"
    let mut out := #[]
    for i in [0:numFields] do
      let fvar := params[numParams + i]!
      let fty ← inferType fvar
      let isProof ← Meta.isProp fty
      out := out.push { name := fieldNames[i]!, isProof }
    return out

private meta def mkInstance (structName : Name) : CommandElabM (Array (TSyntax `command)) := do
  let fields ← liftTermElabM <| classifyFields structName
  let dataFields := fields.filter (!·.isProof)
  if dataFields.isEmpty then
    throwError "`{structName}` has no data fields; nothing to encode"
  let structId := mkIdent structName
  let x := mkIdent `x
  -- encode: `encodeChunks [toRepr x.d₁, …, toRepr x.dₙ]`
  let encodeProjs ← dataFields.mapM fun f =>
    `($(mkCIdent ``HasRepr.toRepr) $x.$(mkIdent f.name):ident)
  let chunks ← `([$encodeProjs,*])
  -- fresh names for the per-data-field equality hypotheses
  let p := mkIdent `p
  let q := mkIdent `q
  let h := mkIdent `h
  let mut eqNames : Array (TSyntax `ident) := #[]
  for _ in [0:dataFields.size] do
    eqNames := eqNames.push (mkIdent (← liftTermElabM <| mkFreshUserName `e))
  -- declared names, rooted so they are not re-prefixed by an enclosing
  -- `namespace`.
  let fnNameId := mkIdent (`_root_ ++ structName ++ `hasReprWithProps_toRepr)
  let injNameId := mkIdent (`_root_ ++ structName ++ `hasReprWithProps_toRepr_inj)
  -- destructuring pattern for the chunk equalities
  let injTac : TSyntax `tactic ←
    if dataFields.size == 1 then
      let e0 := eqNames[0]!
      `(tactic| (
        intro $p:ident $q:ident $h:ident
        simp only [$fnNameId:ident] at $h:ident
        replace $h:ident := $(mkCIdent ``encodeChunks_inj) $h:ident
        simp only [List.cons.injEq, and_true] at $h:ident
        have $e0:ident := $(mkCIdent ``HasRepr.toRepr_inj) $h:ident
        cases $p:ident
        cases $q:ident
        simp only at $e0:ident
        subst $e0:ident
        rfl))
    else
      let patt ← `(rcasesPat| ⟨$[$eqNames],*⟩)
      -- after exposing fields, turn each repr equality into a field equality
      -- via `HasRepr.toRepr_inj`, then substitute.
      let mut steps : Array (TSyntax `tactic) := #[]
      for e in eqNames do
        steps := steps.push (← `(tactic| simp only at $e:ident))
      for e in eqNames do
        steps := steps.push (←
          `(tactic| replace $e:ident := $(mkCIdent ``HasRepr.toRepr_inj) $e:ident))
      for e in eqNames do
        steps := steps.push (← `(tactic| subst $e:ident))
      `(tactic| (
        intro $p:ident $q:ident $h:ident
        simp only [$fnNameId:ident] at $h:ident
        replace $h:ident := $(mkCIdent ``encodeChunks_inj) $h:ident
        simp only [List.cons.injEq, and_true] at $h:ident
        obtain $patt := $h:ident
        cases $p:ident
        cases $q:ident
        $[$steps:tactic]*
        rfl))
  let funCmd ← `(command|
    @[expose] def $fnNameId:ident ($x : $structId) : $(mkCIdent ``ReprType) :=
      $(mkCIdent ``encodeChunks) $chunks)
  let injCmd ← `(command|
    theorem $injNameId:ident : $(mkCIdent ``Function.Injective) $fnNameId:ident := by
      $injTac:tactic)
  let instCmd ← `(command|
    instance : $(mkCIdent ``HasRepr) $structId := ⟨$fnNameId, $injNameId⟩)
  return #[funCmd, injCmd, instCmd]

syntax (name := deriveHasReprWithProps)
  "derive_has_repr_with_props " ident : command

@[command_elab deriveHasReprWithProps]
meta def elabDeriveHasReprWithProps : CommandElab := fun stx => do
  match stx with
  | `(derive_has_repr_with_props $id:ident) => do
    let structName ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
    let cmds ← mkInstance structName
    for cmd in cmds do
      elabCommand cmd
  | _ => throwUnsupportedSyntax

end CpsatSolver.DeriveHasReprWithProps
