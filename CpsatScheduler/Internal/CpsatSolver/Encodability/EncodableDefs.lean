module

public import CpsatScheduler.Internal.CpsatSolver.Defs
public import CpsatScheduler.Internal.CpsatSolver.Encodability.DeriveEncodablePlain
public import Mathlib.Logic.Equiv.Array

import CpsatScheduler.Internal.CpsatSolver.Encodability.DeriveEncodableWithProps

public section

instance : Encodable Char where
  encode := Char.toNat
  decode n := if h : n.isValidChar then
    .some (Char.ofNat n)
  else
    .none
  encodek c := by
    split
    · apply congrArg Option.some
      exact Char.ofNat_toNat c
    · rename_i nh
      absurd nh
      exact c.valid

instance : Encodable String :=
  Encodable.ofLeftInverse
    String.toList String.ofList
    (fun _ => by exact String.ofList_toList)


namespace CpsatSolver

derive_encodable_plain IntVar
derive_encodable_plain BoolVar
derive_encodable_plain BoolLit
derive_encodable_plain UnitAwareIntVar
derive_encodable_plain LinearExpr.Raw

/-- compute the bounding interval of a raw expression,
    `none` on overflow. -/
def LinearExpr.Raw.interval? : LinearExpr.Raw → Option Interval
  | .fromVar v => some v.domainHull
  | .fromConst v => some (Interval.ofValue v)
  | .fromNeg a => do
    let B ← interval? a
    if h : Interval.Nonoverflow.Neg B then some (B.neg h) else none
  | .fromMulConst a v => do
    let B ← interval? a
    if h : Interval.Nonoverflow.MulConst B v then
      some (B.mul (Interval.ofValue v) h)
    else none
  | .fromAdd a b => do
    let A ← interval? a
    let B ← interval? b
    if h : Interval.Nonoverflow.Add A B then some (A.add B h) else none
  | .fromSub a b => do
    let A ← interval? a
    let B ← interval? b
    if h : Interval.Nonoverflow.Sub A B then some (A.sub B h) else none

/-- The checker and the relation agree: `interval? R = some I ↔ Proof R I`.
    Keystone lemma — gives decidability and uniqueness below. -/
theorem LinearExpr.Raw.interval?_eq_some_iff :
    ∀ (R : LinearExpr.Raw) (I : Interval),
      R.interval? = some I ↔ LinearExpr.Proof R I
  | .fromVar v, I => by
    simp only [interval?, Option.some.injEq]
    constructor
    · rintro rfl; exact .fromVar v
    · rintro h; cases h; rfl
  | .fromConst v, I => by
    simp only [interval?, Option.some.injEq]
    constructor
    · rintro rfl; exact .fromConst v
    · rintro h; cases h; rfl
  | .fromNeg a, I => by
    simp only [interval?, Option.bind_eq_bind]
    constructor
    · intro hR
      obtain ⟨B, hB, hrest⟩ := Option.bind_eq_some_iff.mp hR
      split_ifs at hrest with h
      cases Option.some.inj hrest
      exact .fromNeg ((interval?_eq_some_iff a B).mp hB) h
    · rintro hP
      cases hP with
      | fromNeg ha h =>
        rename_i B
        rw [(interval?_eq_some_iff a B).mpr ha, Option.bind_some]
        simp only [h, dite_true]
  | .fromMulConst a v, I => by
    simp only [interval?, Option.bind_eq_bind]
    constructor
    · intro hR
      obtain ⟨B, hB, hrest⟩ := Option.bind_eq_some_iff.mp hR
      split_ifs at hrest with h
      cases Option.some.inj hrest
      exact .fromMulConst v ((interval?_eq_some_iff a B).mp hB) h
    · rintro hP
      cases hP with
      | fromMulConst v ha h =>
        rename_i B
        rw [(interval?_eq_some_iff a B).mpr ha, Option.bind_some]
        simp only [h, dite_true]
  | .fromAdd a b, I => by
    simp only [interval?, Option.bind_eq_bind]
    constructor
    · intro hR
      obtain ⟨A, hA, hR⟩ := Option.bind_eq_some_iff.mp hR
      obtain ⟨B, hB, hrest⟩ := Option.bind_eq_some_iff.mp hR
      split_ifs at hrest with h
      cases Option.some.inj hrest
      exact .fromAdd ((interval?_eq_some_iff a A).mp hA)
        ((interval?_eq_some_iff b B).mp hB) h
    · rintro hP
      cases hP with
      | fromAdd ha hb h =>
        rename_i A B
        rw [(interval?_eq_some_iff a A).mpr ha, Option.bind_some,
          (interval?_eq_some_iff b B).mpr hb, Option.bind_some]
        simp only [h, dite_true]
  | .fromSub a b, I => by
    simp only [interval?, Option.bind_eq_bind]
    constructor
    · intro hR
      obtain ⟨A, hA, hR⟩ := Option.bind_eq_some_iff.mp hR
      obtain ⟨B, hB, hrest⟩ := Option.bind_eq_some_iff.mp hR
      split_ifs at hrest with h
      cases Option.some.inj hrest
      exact .fromSub ((interval?_eq_some_iff a A).mp hA)
        ((interval?_eq_some_iff b B).mp hB) h
    · rintro hP
      cases hP with
      | fromSub ha hb h =>
        rename_i A B
        rw [(interval?_eq_some_iff a A).mpr ha, Option.bind_some,
          (interval?_eq_some_iff b B).mpr hb, Option.bind_some]
        simp only [h, dite_true]

/-- The bounding interval is unique: `I` is a function of `R`. -/
theorem LinearExpr.Proof.unique {R : LinearExpr.Raw} {I₁ I₂ : Interval}
    (h₁ : LinearExpr.Proof R I₁) (h₂ : LinearExpr.Proof R I₂) : I₁ = I₂ := by
  rw [← LinearExpr.Raw.interval?_eq_some_iff] at h₁ h₂
  exact Option.some.inj (h₁ ▸ h₂)

/-- `LinearExpr.Proof` is decidable: run the checker and compare. -/
instance (R : LinearExpr.Raw) (I : Interval) :
    Decidable (LinearExpr.Proof R I) :=
  decidable_of_iff (R.interval? = some I) (R.interval?_eq_some_iff I)

derive_encodable_with_props LinearExpr
derive_encodable_with_props FixedSizeIntervalVar
derive_encodable_plain BoundedLinearExpr.Rel
derive_encodable_plain BoundedLinearExpr
derive_encodable_plain Constraint.CumulativeItem

instance : Encodable Constraint.Enforcement where
  encode e := match e with
    | .always => 0
    | .onlyWhenAll lit _ => 1 + Encodable.encode lit
  decode n := match n with
    | 0 => .some .always
    | k + 1 =>
      let decoded : Option (Array BoolLit) := Encodable.decode k
      if ok : decoded.isSome then
        let literals := decoded.get ok
        if h : literals ≠ #[] then
          .some (.onlyWhenAll literals h)
        else .none
      else .none
  encodek e := by
    split
    · rename_i heq
      cases e
      · rfl
      · dsimp at heq
        absurd heq
        simp
    · rename_i heq
      cases e
      · simp at heq
      · simp only [Nat.succ_eq_add_one] at heq
        rename_i n k lits lit_nonempty
        rw [Nat.add_comm] at heq
        apply Nat.add_right_cancel at heq
        rw [heq.symm]
        rw [Encodable.encodek (a := lits)]
        simp only [Option.isSome_some, ↓reduceDIte, Option.get_some, ne_eq, dite_not,
          Option.dite_none_left_eq_some, exists_prop, and_true]
        exact lit_nonempty

/-- `Vector α n` is `{ toArray : Array α // toArray.size = n }`; the size
    predicate is decidable, so we can encode via the underlying array and
    re-check the length on decode. -/
instance {α : Type*} [Encodable α] (n : Nat) : Encodable (Vector α n) :=
  Encodable.ofLeftInjection
    (fun v => v.toArray)
    (fun a =>
      if h : a.size = n then some ⟨a, h⟩ else none)
    (fun v => by simp)

instance : Encodable Constraint.Variant where
  encode v := match v with
    | .bounded_linear expr =>
      Nat.pair 0 (Encodable.encode expr)
    | .max_equality target exprs _ =>
      Nat.pair 1 (Encodable.encode (target, exprs))
    | .div_eq target numerator divisor _ =>
      Nat.pair 2 (Encodable.encode (target, numerator, divisor))
    | .allowed_assignments (n := n) vars rows _ _ =>
      Nat.pair 3 (Encodable.encode
        (⟨n, vars, rows⟩ : Σ n : Nat, Vector IntVar n × Array (Vector Int64 n)))
    | .cumulative items capacity =>
      Nat.pair 4 (Encodable.encode (items, capacity))
    | .bool_and terms _ =>
      Nat.pair 5 (Encodable.encode terms)
    | .bool_or terms _ =>
      Nat.pair 6 (Encodable.encode terms)
    | .implication src dst =>
      Nat.pair 7 (Encodable.encode (src, dst))
  decode n :=
    match Nat.unpair n with
    | (tag, payload) =>
    match tag with
    | 0 =>
      (Encodable.decode payload : Option BoundedLinearExpr).map
        Constraint.Variant.bounded_linear
    | 1 =>
      (Encodable.decode payload : Option (LinearExpr × Array LinearExpr)).bind
        fun (target, exprs) =>
          if h : exprs.size > 0 then
            some (.max_equality target exprs h)
          else none
    | 2 =>
      (Encodable.decode payload : Option (LinearExpr × LinearExpr × Int64)).bind
        fun (target, numerator, divisor) =>
          if h : (0 : ℤ) < divisor then
            some (.div_eq target numerator divisor h)
          else none
    | 3 =>
      (Encodable.decode payload :
          Option (Σ n : Nat, Vector IntVar n × Array (Vector Int64 n))).bind
        fun ⟨_, vars, rows⟩ =>
          if hne : rows.size > 0 then
            if hwd :
                (∀ row ∈ rows, ∀ i : Fin vars.size,
                  (row[i].val : ℤ) ∈ vars[i].domain.domain) then
              some (.allowed_assignments vars rows hne hwd)
            else none
          else none
    | 4 =>
      (Encodable.decode payload :
          Option (Array Constraint.CumulativeItem × LinearExpr)).map
        fun (items, capacity) => .cumulative items capacity
    | 5 =>
      (Encodable.decode payload : Option (Array BoolLit)).bind
        fun terms =>
          if h : terms.size > 0 then some (.bool_and terms h) else none
    | 6 =>
      (Encodable.decode payload : Option (Array BoolLit)).bind
        fun terms =>
          if h : terms.size > 0 then some (.bool_or terms h) else none
    | 7 =>
      (Encodable.decode payload : Option (BoolLit × BoolLit)).map
        fun (src, dst) => .implication src dst
    | _ => none
  encodek v := by
    cases v with
    | bounded_linear expr =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.map_some]
    | max_equality target exprs nonempty =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.bind_some,
        nonempty, dite_true]
    | div_eq target numerator divisor divisor_pos =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.bind_some,
        divisor_pos, dite_true]
    | allowed_assignments vars rows nonempty within_domain =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.bind_some]
      rw [dite_eq_left_of_eq_true (eq_true nonempty),
        dite_eq_left_of_eq_true (eq_true within_domain)]
    | cumulative items capacity =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.map_some]
    | bool_and terms nonempty =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.bind_some,
        nonempty, dite_true]
    | bool_or terms nonempty =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.bind_some,
        nonempty, dite_true]
    | implication src dst =>
      simp only [Nat.unpair_pair, Encodable.encodek, Option.map_some]

derive_encodable_plain Constraint
derive_encodable_plain Objective

end CpsatSolver
