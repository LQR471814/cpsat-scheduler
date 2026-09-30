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

def LinearExpr.var (value : IntVar) :
    LinearExpr value.domain.hull :=
  .fromVar value

def LinearExpr.const (value : Int64) :
    LinearExpr (Interval.ofValue value) :=
  .fromConst value

def LinearExpr.neg {b : Bounds} (a : LinearExpr b)
  (h : LinearExpr.Nonoverflow.Neg b) :
    LinearExpr (b.neg h) :=
  .fromNeg a h

def LinearExpr.mul {b : Bounds} (a : LinearExpr b) (v : Int64)
  (h : LinearExpr.Nonoverflow.Mul b v) :
    LinearExpr (b.mul (Interval.ofValue v) h) :=
  .fromMulConst a v h

def LinearExpr.add {L R : Bounds}
  (l : LinearExpr L) (r : LinearExpr R)
  (h : LinearExpr.Nonoverflow.Add L R) :
    LinearExpr (L.add R h) :=
  .fromAdd l r h

def LinearExpr.sub {L R : Bounds}
  (l : LinearExpr L) (r : LinearExpr R)
  (h : LinearExpr.Nonoverflow.Sub L R) :
    LinearExpr (L.sub R h) :=
  .fromSub l r h

end CpsatSolver
