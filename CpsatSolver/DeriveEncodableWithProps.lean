/-
`derive_encodable_with_props S`

Generates `instance : Encodable S` for a single-constructor structure `S`
whose fields split into:
  * DATA fields  — non-`Prop` typed; these are the identity-bearing payload.
  * PROOF fields — `Prop` typed; these are decidable predicates over the
    data fields (an `instance Decidable _` must be available for each).

The generated instance follows the hand-written pattern:
  encode  : tuple the data fields and `Encodable.encode` them
  decode  : decode the tuple, then re-`dite` each proof field back into
            existence (using its `Decidable` instance); rebuild the struct
  linv    : `simp only [Encodable.encodek, <each proof proj>, dite_true]`

So PROOFS ARE NOT SERIALIZED — they are regenerated on decode. Identity
therefore rides on the data fields only, exactly as in the manual instances.
-/

import Mathlib.Logic.Encodable.Basic
import Lean

set_option linter.style.emptyLine false

open Lean Elab Command Meta Term

namespace CpsatSolver

/-- Classification of a structure field. -/
private structure FieldKind where
  name : Name
  /-- `true` if the field's type is a `Prop` (a proof field). -/
  isProof : Bool
deriving Inhabited

/-- Inspect `structName`'s constructor telescope and classify each explicit
    field as data or proof, in declaration order. -/
private def classifyFields (structName : Name) : MetaM (Array FieldKind) := do
  let env ← getEnv
  let some _ := getStructureInfo? env structName
    | throwError "`{structName}` is not a structure"
  let ctorVal := getStructureCtor env structName
  let fieldNames := getStructureFields env structName
  forallTelescopeReducing ctorVal.type fun params _ => do
    -- The last `fieldNames.size` params are the fields (first `numParams`
    -- are the structure's own parameters, which this derivation disallows).
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

/-- Build the full instance command syntax for `structName`. -/
private def mkInstance (structName : Name) : CommandElabM (TSyntax `command) := do
  let fields ← liftTermElabM <| classifyFields structName
  let dataFields  := fields.filter (!·.isProof)
  let proofFields := fields.filter (·.isProof)

  if dataFields.isEmpty then
    throwError "`{structName}` has no data fields; nothing to encode"

  let structId := mkIdent structName

  -- Fresh binder `x` for the encode function.
  let x := mkIdent `x

  -- encode: `Encodable.encode (x.d₁, x.d₂, ..., x.dₙ)` built as right-nested
  -- pairs `(d₁, (d₂, ... dₙ))` to avoid tuple-splice pitfalls.
  let encodeProjs ← dataFields.mapM fun f => do
    `($x.$(mkIdent f.name):ident)
  let mut encodeTuple := encodeProjs.back!
  for i in [1:encodeProjs.size] do
    let idx := encodeProjs.size - 1 - i
    encodeTuple ← `(term| ($(encodeProjs[idx]!), $encodeTuple))

  -- Build the decode body. Decoded local `t` is the data tuple; bind each
  -- data field by name from it, then nest `dite` over the proof fields.
  let tv := mkIdent `t

  -- record fields for the final `{ ... }`:
  --   data fields  := <local of same name>
  --   proof fields := <the dite-bound hypothesis of same name>
  -- reconstruct via positional constructor application `S.mk f₁ f₂ ... fₖ`
  -- (fields in declaration order: data locals + proof hyps, all named after
  -- their fields). Avoids struct-instance-field splicing entirely.
  let ctorId ← liftTermElabM do
    let env ← getEnv
    pure (mkIdent (getStructureCtor env structName).name)
  let allFieldArgs ← fields.mapM fun f => `(term| $(mkIdent f.name):ident)
  let recordTerm ← `(term| $ctorId:ident $allFieldArgs*)

  -- innermost: `some { ... }`
  -- wrap in nested `if h : <Prop> then ... else none`, one per proof field.
  -- We let Lean INFER each proof-field type from the expected argument type
  -- of the structure constructor by writing the condition as the field's
  -- type.  To get that type as syntax we delaborate it under the data locals.
  let innermost ← `(term| some $recordTerm)

  -- Delaborate each proof field's type (as a `dite` condition) and each data
  -- field's type (to annotate the decode target tuple so `⟨..⟩` typechecks).
  -- Delaborate with `pp.explicit`/coercions on so the surface syntax
  -- re-elaborates to EXACTLY the original type (preserving coercions like
  -- `(↑size : ℤ)` and numeric-literal types).
  let (proofConds, dataTys) ← liftTermElabM <| withOptions (fun o =>
      (((o.setBool `pp.explicit true).setBool `pp.coercions true).setBool
        `pp.numericTypes true).setBool `pp.coercions.types true) <| do
    let env ← getEnv
    let ctorVal := getStructureCtor env structName
    let fieldNames := getStructureFields env structName
    forallTelescopeReducing ctorVal.type fun params _ => do
      let numParams := ctorVal.numParams
      let mut nameToFvar : Std.HashMap Name Expr := {}
      for i in [0:fieldNames.size] do
        nameToFvar := nameToFvar.insert fieldNames[i]! params[numParams + i]!
      let mut conds : Array (TSyntax `term) := #[]
      for pf in proofFields do
        let some fv := nameToFvar.get? pf.name | throwError "missing field {pf.name}"
        let ty ← inferType fv
        let stx ← PrettyPrinter.delab ty
        conds := conds.push ⟨stx⟩
      let mut dtys : Array (TSyntax `term) := #[]
      for df in dataFields do
        let some fv := nameToFvar.get? df.name | throwError "missing field {df.name}"
        let ty ← inferType fv
        let stx ← PrettyPrinter.delab ty
        dtys := dtys.push ⟨stx⟩
      return (conds, dtys)

  -- Build the nested dite.  Bind proof hyp names = proof field names.
  let mut body := innermost
  for i in [0:proofFields.size] do
    let idx := proofFields.size - 1 - i
    let pf := proofFields[idx]!
    let cond := proofConds[idx]!
    body ← `(term|
      if $(mkIdent pf.name):ident : $cond then $body else none)

  -- Bind data locals from the tuple `t` via pattern match on the anonymous
  -- constructor `⟨d₁, d₂, ..., dₙ⟩`.
  let decodeFun ←
    if h : dataFields.size = 1 then
      -- single data field: decoded value IS the field, no tuple to match.
      let d0 := mkIdent dataFields[0].name
      `(term|
        fun n =>
          (Encodable.decode n).bind (fun $d0:ident => $body))
    else
      let dataBinders ← dataFields.mapM fun f => `(term| $(mkIdent f.name):ident)
      -- right-nested tuple TYPE `(T₁ × T₂ × ... × Tₙ)` to annotate decode.
      let mut tupleTy := dataTys.back!
      for i in [1:dataTys.size] do
        let idx := dataTys.size - 1 - i
        tupleTy ← `(term| $(dataTys[idx]!) × $tupleTy)
      `(term|
        fun n =>
          ((Encodable.decode n : Option $tupleTy)).bind (fun $tv:ident =>
            match $tv:ident with
            | ⟨$dataBinders,*⟩ => $body))

  -- linv proof: simp with encodek + each proof projection + dite_true.
  let proofProjs ← proofFields.mapM fun f => `(term| $x.$(mkIdent f.name):ident)
  let linv ← `(term|
    fun $x:ident => by
      simp only [Encodable.encodek, $[$proofProjs:term],*,
        Option.bind_some, dite_true])

  `(command|
    instance : Encodable $structId:ident :=
      Encodable.ofLeftInjection
        (fun $x:ident => Encodable.encode $encodeTuple:term)
        $decodeFun:term
        $linv:term)

/-- Command: `derive_encodable_with_props StructName`. -/
syntax (name := deriveEncWithProps)
  "derive_encodable_with_props " ident : command

@[command_elab deriveEncWithProps]
def elabDeriveEncWithProps : CommandElab := fun stx => do
  match stx with
  | `(derive_encodable_with_props $id:ident) => do
    let structName ← liftCoreM <| realizeGlobalConstNoOverloadWithInfo id
    let cmd ← mkInstance structName
    elabCommand cmd
  | _ => throwUnsupportedSyntax

end CpsatSolver
