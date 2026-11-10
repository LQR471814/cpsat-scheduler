-- perhaps what we actually want is a "derived identity", where the identity of
-- an object depends on the identity of other objects?
--
-- where such objects may be other derived identities or certain "primitive
-- values"
--
-- if two objects have the same "derived identity" then they are equal
--
-- this solves the problem where: I have an object and I create two objects
-- from that same reference point, if they have different internal properties,
-- then they are different, if they have the exact same internal properties,
-- then by definition, they are exactly the same
--
-- each object should probably also come with a theorem that states if their
-- "derived identity" is equal, then they are definitionally equal
--
-- well what I have described is literally definitional equality. it simply
-- doesn't "feel" like definitional equality because now certain objects may
-- refer to other objects it is completely unrelated to

import Mathlib.Data.Finset.Basic
import Mathlib.Data.Char
import Mathlib.Data.Nat.Pairing
import Mathlib.Logic.Equiv.Nat
import Mathlib.Logic.Equiv.List
import Mathlib.Logic.Equiv.Array
import Mathlib.Logic.Encodable.Basic
import Mathlib.Tactic.DeriveEncodable

import CpsatScheduler.Python.Basic
import CpsatSolver.Domain.NonemptyDomain
import CpsatSolver.Unit.Set
import CpsatSolver.DeriveEncodableWithProps

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

structure IntVar where
  label : Option String := none
  domain : NonemptyDomain
deriving DecidableEq
deriving instance Encodable for IntVar

structure BoolVar where
  id : Nat
  label : Option String := none
deriving DecidableEq
deriving instance Encodable for BoolVar

inductive BoolLit where
  | var (v : BoolVar)
  | neg (v : BoolVar)
deriving DecidableEq
deriving instance Encodable for BoolLit

structure UnitAwareIntVar (us : Unit.Set) where
  intVar : IntVar
  scale : us.elem
deriving DecidableEq
deriving instance Encodable for UnitAwareIntVar

def LinearExpr.Nonoverflow.Neg (b : Interval) : Prop :=
  Int64.Nonoverflow (-b.right : ℤ) ∧
  Int64.Nonoverflow (-b.left : ℤ)

def LinearExpr.Nonoverflow.Mul (b : Interval) (v : Int64) : Prop :=
  Int64.Nonoverflow (b.mulLower (Interval.ofValue v)) ∧
  Int64.Nonoverflow (b.mulUpper (Interval.ofValue v))

def LinearExpr.Nonoverflow.Add (a b : Interval) : Prop :=
  Int64.Nonoverflow ((a.left : ℤ) + b.left) ∧
  Int64.Nonoverflow ((a.right : ℤ) + b.right)

def LinearExpr.Nonoverflow.Sub (a b : Interval) : Prop :=
  Int64.Nonoverflow ((a.left : ℤ) - b.right) ∧
  Int64.Nonoverflow ((a.right : ℤ) - b.left)

def IntVar.domainHull (i : IntVar) : Interval :=
  i.domain.hull

instance (b : Interval) : Decidable (LinearExpr.Nonoverflow.Neg b) := by
  unfold LinearExpr.Nonoverflow.Neg; infer_instance

instance (b : Interval) (v : Int64) : Decidable (LinearExpr.Nonoverflow.Mul b v) := by
  unfold LinearExpr.Nonoverflow.Mul; infer_instance

instance (a b : Interval) : Decidable (LinearExpr.Nonoverflow.Add a b) := by
  unfold LinearExpr.Nonoverflow.Add; infer_instance

instance (a b : Interval) : Decidable (LinearExpr.Nonoverflow.Sub a b) := by
  unfold LinearExpr.Nonoverflow.Sub; infer_instance

inductive LinearExpr.Raw where
  | fromVar (value : IntVar)
  | fromConst (value : Int64)
  | fromNeg (a : LinearExpr.Raw)
  | fromMulConst (a : LinearExpr.Raw) (v : Int64)
  | fromAdd (a b : LinearExpr.Raw)
  | fromSub (a b : LinearExpr.Raw)
deriving DecidableEq
deriving instance Encodable for LinearExpr.Raw

inductive LinearExpr.Proof : LinearExpr.Raw → Interval → Prop where
  | fromVar (value : IntVar) :
      LinearExpr.Proof (.fromVar value) value.domainHull
  | fromConst (value : Int64) :
      LinearExpr.Proof (.fromConst value) (Interval.ofValue value)
  | fromNeg {a : LinearExpr.Raw} {B : Interval}
      (ha : LinearExpr.Proof a B) (h : LinearExpr.Nonoverflow.Neg B) :
        LinearExpr.Proof (.fromNeg a) (B.neg h)
  | fromMulConst {a : LinearExpr.Raw} {B : Interval} (v : Int64)
      (ha : LinearExpr.Proof a B) (h : LinearExpr.Nonoverflow.Mul B v) :
        LinearExpr.Proof
          (.fromMulConst a v)
          (B.mul (Interval.ofValue v) h)
  | fromAdd {a b : LinearExpr.Raw} {A B : Interval}
      (ha : LinearExpr.Proof a A)
      (hb : LinearExpr.Proof b B)
      (h : LinearExpr.Nonoverflow.Add A B) :
        LinearExpr.Proof (.fromAdd a b) (A.add B h)
  | fromSub {a b : LinearExpr.Raw} {A B : Interval}
      (ha : LinearExpr.Proof a A)
      (hb : LinearExpr.Proof b B)
      (h : LinearExpr.Nonoverflow.Sub A B) :
        LinearExpr.Proof (.fromSub a b) (A.sub B h)

/-- compute the bounding interval of a raw expression,
    `none` on overflow. -/
def LinearExpr.Raw.interval? : LinearExpr.Raw → Option Interval
  | .fromVar v => some v.domainHull
  | .fromConst v => some (Interval.ofValue v)
  | .fromNeg a => do
    let B ← interval? a
    if h : LinearExpr.Nonoverflow.Neg B then some (B.neg h) else none
  | .fromMulConst a v => do
    let B ← interval? a
    if h : LinearExpr.Nonoverflow.Mul B v then
      some (B.mul (Interval.ofValue v) h)
    else none
  | .fromAdd a b => do
    let A ← interval? a
    let B ← interval? b
    if h : LinearExpr.Nonoverflow.Add A B then some (A.add B h) else none
  | .fromSub a b => do
    let A ← interval? a
    let B ← interval? b
    if h : LinearExpr.Nonoverflow.Sub A B then some (A.sub B h) else none

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

structure LinearExpr where
  raw : LinearExpr.Raw
  interval : Interval
  proof : LinearExpr.Proof raw interval
deriving DecidableEq
derive_encodable_with_props LinearExpr

/-- Half-open interval `[start, start + size)`. -/
structure FixedSizeIntervalVar where
  id : Nat
  start : LinearExpr
  size : Int64
  size_nonneg : (0 : ℤ) ≤ size
  label : Option String := none
deriving DecidableEq
derive_encodable_with_props FixedSizeIntervalVar

inductive BoundedLinearExpr.Rel where
  | eq | neq | gt | gte | lt | lte
deriving DecidableEq
deriving instance Encodable for BoundedLinearExpr.Rel

structure BoundedLinearExpr where
  rel : BoundedLinearExpr.Rel
  leftInterval : Interval
  rightInterval : Interval
  left : LinearExpr
  right : LinearExpr
deriving DecidableEq
deriving instance Encodable for BoundedLinearExpr.Rel

structure Constraint.CumulativeItem where
  interval : FixedSizeIntervalVar
  demand : LinearExpr.Raw
  demandInterval : Interval
  demand_proof : LinearExpr.Proof demand demandInterval
deriving DecidableEq
derive_encodable_with_props Constraint.CumulativeItem

inductive Constraint.Enforcement where
  | always
  | onlyWhenAll (literals : Array BoolLit) (h : literals ≠ #[])
deriving DecidableEq

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

inductive Constraint.Variant where
  | bounded_linear (expr : BoundedLinearExpr)
  | max_equality
    (target : LinearExpr)
    (exprs : Array LinearExpr)
    (nonempty : exprs.size > 0 := by native_decide)
  | div_eq
    (target : LinearExpr)
    (numerator : LinearExpr)
    (divisor : Int64)
    (divisor_pos : (0 : ℤ) < divisor := by native_decide)
  | allowed_assignments {n : Nat}
    (vars : Vector IntVar n)
    (rows : Array (Vector Int64 n))
    (nonempty : rows.size > 0 := by native_decide)
    (within_domain :
      ∀ row ∈ rows,
      ∀ i : Fin vars.size,
        (row[i].val : ℤ) ∈ vars[i].domain.domain
      := by native_decide)
  | cumulative
    (items : Array Constraint.CumulativeItem)
    (capacity : LinearExpr)
  | bool_and (terms : Array BoolLit)
    (nonempty : terms.size > 0)
  | bool_or (terms : Array BoolLit)
    (nonempty : terms.size > 0)
  | implication (src : BoolLit) (dst : BoolLit)
deriving DecidableEq

structure Constraint where
  id : Nat
  label : Option String := none
  enforcement : Constraint.Enforcement
  variant : Constraint.Variant
deriving DecidableEq
derive_encodable_with_props Constraint.CumulativeItem

inductive Objective where
  | none
  | minimize (expr : LinearExpr)
  | maximize (expr : LinearExpr)
deriving DecidableEq
deriving instance Encodable for Objective

end CpsatSolver

