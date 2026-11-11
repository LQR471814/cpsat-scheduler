import CpsatSolver.Defs

namespace CpsatSolver.LinearExpr

/-- A valuation assigns an integer to every `IntVar`. Identity is structural
    (`DecidableEq`/`Encodable`), so variables with the same label and domain
    receive the same value by construction. -/
abbrev Valuation := IntVar → ℤ

/-- Evaluate a raw linear expression under a valuation. -/
def Raw.eval (valuation : Valuation) : LinearExpr.Raw → ℤ
  | .fromVar value => valuation value
  | .fromConst value => value.val
  | .fromNeg a => -a.eval valuation
  | .fromMulConst a value => value.val * a.eval valuation
  | .fromAdd a b => a.eval valuation + b.eval valuation
  | .fromSub a b => a.eval valuation - b.eval valuation

/-- The variables appearing in a raw expression (leaves), in traversal order. -/
def Raw.intVars : LinearExpr.Raw → Array IntVar
  | .fromVar value => #[value]
  | .fromConst _ => #[]
  | .fromNeg a => a.intVars
  | .fromMulConst a _ => a.intVars
  | .fromAdd a b => a.intVars ++ b.intVars
  | .fromSub a b => a.intVars ++ b.intVars

/-- Evaluate a linear expression (via its raw representation). -/
def eval (valuation : Valuation) (expr : LinearExpr) : ℤ :=
  expr.raw.eval valuation

/-- The variables appearing in a linear expression. -/
def intVars (expr : LinearExpr) : Array IntVar :=
  expr.raw.intVars

/-- Soundness of the bounding interval: if every variable is assigned a value
    within its domain, the expression evaluates inside its certified interval.

    Proved by induction on the `Proof` relation, which ties each raw node to
    the interval it produces. -/
theorem Raw.eval_mem_of_proof
    (valuation : Valuation) :
    ∀ {R : LinearExpr.Raw} {I : Interval},
      LinearExpr.Proof R I →
      (∀ v ∈ R.intVars, valuation v ∈ v.domain.domain) →
      R.eval valuation ∈ I :=
  by
    intro R I hP
    induction hP with
    | fromVar value =>
      intro inDomain
      exact NonemptyDomain.mem_hull value.domain
        (inDomain value (by simp [Raw.intVars]))
    | fromConst value =>
      intro _
      simp only [Raw.eval]
      exact (Interval.mem_ofValue value value.val).mpr rfl
    | fromNeg ha h ih =>
      intro inDomain
      exact Interval.eval_neg _ h (ih (fun v hv => inDomain v hv))
    | fromMulConst value ha h ih =>
      intro inDomain
      simpa [Raw.eval] using
        Interval.mul_const_mem _ value _ (ih (fun v hv => inDomain v hv)) h
    | fromAdd ha hb h iha ihb =>
      intro inDomain
      exact Interval.eval_add _ _ h
        (iha fun v hv => inDomain v (by
          simp only [intVars, Array.mem_append]
          exact Or.inl hv))
        (ihb fun v hv => inDomain v (by
          simp only [intVars, Array.mem_append]
          exact Or.inr hv))
    | fromSub ha hb h iha ihb =>
      intro inDomain
      exact Interval.eval_sub _ _ h
        (iha fun v hv => inDomain v (by
          simp only [intVars, Array.mem_append]
          exact Or.inl hv))
        (ihb fun v hv => inDomain v (by
          simp only [intVars, Array.mem_append]
          exact Or.inr hv))

/-- Expression bounds are a sound over-approximation under domain-respecting
    assignments. -/
theorem eval_mem_bounds (valuation : Valuation) (expr : LinearExpr)
    (inDomain : ∀ v ∈ expr.intVars, valuation v ∈ v.domain.domain) :
    expr.eval valuation ∈ expr.interval :=
  Raw.eval_mem_of_proof valuation expr.proof inDomain

/-! ### Smart constructors

Each builds a `LinearExpr` (raw payload + certified interval + proof). The
arithmetic constructors require the corresponding non-overflow witness. -/

def var (value : IntVar) : LinearExpr :=
  ⟨.fromVar value, value.domainHull, .fromVar value⟩

def const (value : Int64) : LinearExpr :=
  ⟨.fromConst value, Interval.ofValue value, .fromConst value⟩

def neg (a : LinearExpr) (h : LinearExpr.Nonoverflow.Neg a.interval) :
    LinearExpr :=
  ⟨.fromNeg a.raw, a.interval.neg h, .fromNeg a.proof h⟩

def mul (a : LinearExpr) (v : Int64)
    (h : LinearExpr.Nonoverflow.Mul a.interval v) : LinearExpr :=
  ⟨.fromMulConst a.raw v, a.interval.mul (Interval.ofValue v) h,
    .fromMulConst v a.proof h⟩

def add (l r : LinearExpr)
    (h : LinearExpr.Nonoverflow.Add l.interval r.interval) : LinearExpr :=
  ⟨.fromAdd l.raw r.raw, l.interval.add r.interval h,
    .fromAdd l.proof r.proof h⟩

def sub (l r : LinearExpr)
    (h : LinearExpr.Nonoverflow.Sub l.interval r.interval) : LinearExpr :=
  ⟨.fromSub l.raw r.raw, l.interval.sub r.interval h,
    .fromSub l.proof r.proof h⟩

end CpsatSolver.LinearExpr
