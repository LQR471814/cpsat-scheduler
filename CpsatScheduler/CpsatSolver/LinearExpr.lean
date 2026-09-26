import CpsatScheduler.CpsatSolver.WellFormed

namespace CpsatSolver

def LinearExpr.eval (valuation : EntityId → ℤ)
    {bounds : Bounds} : LinearExpr bounds → ℤ
  | .fromVar value => valuation value.id
  | .fromConst value => value.val
  | .fromNeg a _ => -eval valuation a
  | .fromMulConst a value _ => value.val * eval valuation a
  | .fromAdd a b _ => eval valuation a + eval valuation b
  | .fromSub a b _ => eval valuation a - eval valuation b

/-- Expression bounds are a sound over-approximation under domain-respecting
assignments. -/
theorem LinearExpr.eval_mem_bounds (valuation : EntityId → ℤ)
    {bounds : Bounds} (expr : LinearExpr bounds)
    (inDomain : ∀ v ∈ expr.intVars,
      valuation v.id ∈ v.domain.domain) :
    expr.eval valuation ∈ bounds := by
  induction expr with
  | fromVar value =>
    exact NonemptyDomain.mem_hull value.domain
      (inDomain value (List.mem_singleton.mpr rfl))
  | fromConst value =>
    simp only [Interval.ofValue]
    apply (Interval.mem_ofValue value value.val).mpr
    rfl
  | fromNeg a h ih =>
    exact Interval.eval_neg _ h (ih (fun v hv => inDomain v hv))
  | fromMulConst a value h ih =>
    simpa [LinearExpr.eval] using
      Interval.mul_const_mem _ value _
        (ih (fun v hv => inDomain v hv)) h
  | fromAdd a b h iha ihb =>
    exact Interval.eval_add _ _ h
      (iha (fun v hv => inDomain v (List.mem_append.mpr (Or.inl hv))))
      (ihb (fun v hv => inDomain v (List.mem_append.mpr (Or.inr hv))))
  | fromSub a b h iha ihb =>
    exact Interval.eval_sub _ _ h
      (iha (fun v hv => inDomain v (List.mem_append.mpr (Or.inl hv))))
      (ihb (fun v hv => inDomain v (List.mem_append.mpr (Or.inr hv))))

def LinearExpr.var (value : IntVar) : LinearExpr value.domain.hull := .fromVar value

def LinearExpr.const (value : Int64) : LinearExpr (Interval.ofValue value) :=
  .fromConst value

def LinearExpr.neg {bounds : Bounds} (a : LinearExpr bounds)
    (nonoverflow : Int64.Nonoverflow (-bounds.right : ℤ) ∧
      Int64.Nonoverflow (-bounds.left : ℤ)) :
    LinearExpr (bounds.neg nonoverflow) :=
  .fromNeg a nonoverflow

def LinearExpr.mul {bounds : Bounds} (a : LinearExpr bounds) (value : Int64)
    (nonoverflow :
      Int64.Nonoverflow (bounds.mulLower (Interval.ofValue value)) ∧
      Int64.Nonoverflow (bounds.mulUpper (Interval.ofValue value))) :
    LinearExpr (bounds.mul (Interval.ofValue value) nonoverflow) :=
  .fromMulConst a value nonoverflow

def LinearExpr.add {leftBounds rightBounds : Bounds}
    (left : LinearExpr leftBounds) (right : LinearExpr rightBounds)
    (nonoverflow :
      Int64.Nonoverflow ((leftBounds.left : ℤ) + rightBounds.left) ∧
      Int64.Nonoverflow ((leftBounds.right : ℤ) + rightBounds.right)) :
    LinearExpr (leftBounds.add rightBounds nonoverflow) :=
  .fromAdd left right nonoverflow

def LinearExpr.sub {leftBounds rightBounds : Bounds}
    (left : LinearExpr leftBounds) (right : LinearExpr rightBounds)
    (nonoverflow :
      Int64.Nonoverflow ((leftBounds.left : ℤ) - rightBounds.right) ∧
      Int64.Nonoverflow ((leftBounds.right : ℤ) - rightBounds.left)) :
    LinearExpr (leftBounds.sub rightBounds nonoverflow) :=
  .fromSub left right nonoverflow

end CpsatSolver
