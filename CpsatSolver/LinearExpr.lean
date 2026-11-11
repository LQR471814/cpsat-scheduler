import CpsatSolver.Defs

namespace CpsatSolver.LinearExpr

def var (value : IntVar) : LinearExpr :=
  {
    raw := .fromVar value
    interval := value.domainHull
    proof := LinearExpr.Proof.fromVar value
  }

def const (value : Int64) : LinearExpr :=
  {
    raw := .fromConst value
    interval := Interval.ofValue value
    proof := LinearExpr.Proof.fromConst value
  }

def neg (a : LinearExpr)
  (h : Interval.Nonoverflow.Neg a.interval) :
    LinearExpr :=
  {
    raw := .fromNeg a.raw
    interval := a.interval.neg h
    proof := LinearExpr.Proof.fromNeg a.proof h
  }

def mul (a : LinearExpr) (v : Int64)
  (h : Interval.Nonoverflow.MulConst a.interval v) :
    LinearExpr :=
  {
    raw := .fromMulConst a.raw v
    interval := a.interval.mul (Interval.ofValue v) h
    proof := LinearExpr.Proof.fromMulConst v a.proof h
  }

def add (l r : LinearExpr)
  (h : Interval.Nonoverflow.Add l.interval r.interval) :
    LinearExpr :=
  {
    raw := .fromAdd l.raw r.raw
    interval := l.interval.add r.interval h
    proof := LinearExpr.Proof.fromAdd l.proof r.proof h
  }

def sub (l r : LinearExpr)
  (h : Interval.Nonoverflow.Sub l.interval r.interval) :
    LinearExpr :=
  {
    raw := .fromSub l.raw r.raw
    interval := l.interval.sub r.interval h
    proof := LinearExpr.Proof.fromSub l.proof r.proof h
  }

-- def eval [Encodable α] (valuation : α → ℤ)
--     {bounds : Interval} : LinearExpr.Raw → ℤ
--   | .fromVar value => valuation value
--   | .fromConst value => value.val
--   | .fromNeg a => -eval valuation a
--   | .fromMulConst a value => value.val * eval valuation a
--   | .fromAdd a b => eval valuation a + eval valuation b
--   | .fromSub a b => eval valuation a - eval valuation b
--
-- /-- Expression bounds are a sound over-approximation under domain-respecting
-- assignments. -/
-- theorem eval_mem_bounds (valuation : EntityID → ℤ)
--     {bounds : Interval} (expr : LinearExpr bounds)
--     (inDomain : ∀ v ∈ expr.intVars,
--       valuation v.id ∈ v.domain.domain) :
--     expr.eval valuation ∈ bounds := by
--   induction expr with
--   | fromVar value =>
--     exact NonemptyDomain.mem_hull value.domain
--       (inDomain value (Array.mem_singleton.mpr rfl))
--   | fromConst value =>
--     simp only [Interval.ofValue]
--     apply (Interval.mem_ofValue value value.val).mpr
--     rfl
--   | fromNeg a h ih =>
--     exact Interval.eval_neg _ h (ih (fun v hv => inDomain v hv))
--   | fromMulConst a value h ih =>
--     simpa [LinearExpr.eval] using
--       Interval.mul_const_mem _ value _
--         (ih (fun v hv => inDomain v hv)) h
--   | fromAdd a b h iha ihb =>
--     exact Interval.eval_add _ _ h
--       (iha (fun v hv => inDomain v (Array.mem_append.mpr (Or.inl hv))))
--       (ihb (fun v hv => inDomain v (Array.mem_append.mpr (Or.inr hv))))
--   | fromSub a b h iha ihb =>
--     exact Interval.eval_sub _ _ h
--       (iha (fun v hv => inDomain v (Array.mem_append.mpr (Or.inl hv))))
--       (ihb (fun v hv => inDomain v (Array.mem_append.mpr (Or.inr hv))))
--
-- def meaning {bounds : Interval} (expr : LinearExpr bounds) :
--     Set ((EntityID → ℤ) × ℤ) :=
--   {pair | pair.2 = expr.eval pair.1}
--
-- def possibleValues {bounds : Interval} (expr : LinearExpr bounds) : Set ℤ :=
--   {value | ∃ valuation : EntityID → ℤ, (valuation, value) ∈ expr.meaning}
--
-- theorem meaning_eq_iff {α β : Interval}
--     (a : LinearExpr α) (b : LinearExpr β) :
--     @meaning α a = @meaning β b ↔ ∀ valuation : EntityID → ℤ,
--       a.eval valuation = b.eval valuation := by
--   constructor
--   · intro h valuation
--     have := Set.ext_iff.mp h (valuation, a.eval valuation)
--     simpa [meaning] using this.mp rfl
--   · intro h
--     ext pair
--     simp [meaning, h]
--
-- theorem meaning_double_neg {α : Interval}
--     (a : LinearExpr α)
--     (h₁ : Int64.Nonoverflow (-α.right : ℤ) ∧ Int64.Nonoverflow (-α.left : ℤ))
--     (h₂ : Int64.Nonoverflow (-(α.neg h₁).right : ℤ) ∧
--       Int64.Nonoverflow (-(α.neg h₁).left : ℤ)) :
--     meaning (LinearExpr.fromNeg (LinearExpr.fromNeg a h₁) h₂) = meaning a := by
--   apply (meaning_eq_iff _ _).mpr
--   intro valuation
--   simp [LinearExpr.eval]
--
-- theorem meaning_add_sub_cancel {α β : Interval}
--     (a : LinearExpr α) (b : LinearExpr β)
--     (hAdd : Int64.Nonoverflow ((α.left : ℤ) + β.left) ∧
--       Int64.Nonoverflow ((α.right : ℤ) + β.right))
--     (hSub : Int64.Nonoverflow (((α.add β hAdd).left : ℤ) - β.right) ∧
--       Int64.Nonoverflow (((α.add β hAdd).right : ℤ) - β.left)) :
--     meaning (LinearExpr.fromSub (LinearExpr.fromAdd a b hAdd) b hSub) =
--       meaning a := by
--   apply (meaning_eq_iff _ _).mpr
--   intro valuation
--   simp [LinearExpr.eval]
--
-- theorem meaning_sub_self {α : Interval} (a : LinearExpr α)
--     (hSub : Int64.Nonoverflow ((α.left : ℤ) - α.right) ∧
--       Int64.Nonoverflow ((α.right : ℤ) - α.left)) :
--     meaning (LinearExpr.fromSub a a hSub) =
--       meaning (LinearExpr.fromConst (Subtype.mk 0 (by native_decide))) := by
--   apply (meaning_eq_iff _ _).mpr
--   intro
--   simp [LinearExpr.eval]

end CpsatSolver.LinearExpr
