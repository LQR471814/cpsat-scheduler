import CpsatSolver.Defs

namespace CpsatSolver

private theorem char_ge_zero_or_le_nine (c : Char) : '0' ≤ c ∨ c ≤ '9' := by
  by_cases h : '0' ≤ c
  · exact Or.inl h
  · exact Or.inr (le_of_lt (lt_of_lt_of_le (lt_of_not_ge h) (by native_decide)))

private theorem validIdent_e_suffix (s : String) :
    Python.ValidIdent ("e_" ++ s) := by
  intro i
  exact Or.inr (Or.inr (Or.inr fun _ => char_ge_zero_or_le_nine _))

private theorem not_reserved_e_suffix (s : String) :
    ¬ ("e_" ++ s) ∈ Python.ReservedKeywords := by
  have hkw : ∀ kw ∈ Python.ReservedKeywords, '_' ∉ kw.toList := by
    decide
  intro hmem
  have : '_' ∈ ("e_" ++ s).toList := by
    simp [String.toList_append]
  exact (hkw _ hmem) this

/-- `"e_" ++ toString n` is always a valid, non-reserved Python identifier. -/
theorem pythonName_proof (n : Nat) :
    Python.ValidName.Proof ("e_" ++ toString n) :=
  ⟨not_reserved_e_suffix (toString n), validIdent_e_suffix (toString n)⟩

/-- Build a Python variable name from a `Nat` identity (or rank).

    Identity throughout the solver is `Encodable.encode`; the model's code
    generator typically passes a *rank* here (the position of the encoded id
    within the sorted set of ids in the model) so that generated names stay
    short and dense. -/
def pythonName (n : Nat) : Python.ValidName :=
  ⟨"e_" ++ toString n, pythonName_proof n⟩

/-- A name resolver maps a structural identity (`Encodable.encode` value) to a
    concrete Python name. The default resolver uses the raw encoded id. -/
abbrev NameResolver := Nat → Python.ValidName

/-- Default resolver: name directly from the encoded id (no remapping). -/
def NameResolver.raw : NameResolver := pythonName

/-- Resolve the Python name of any encodable object under a resolver. -/
def NameResolver.of {α : Type*} [Encodable α]
    (r : NameResolver) (x : α) : Python.ValidName :=
  r (Encodable.encode x)

def BoolLit.toPythonExpr (r : NameResolver) (b : BoolLit) : Python.Expr :=
  match b with
  | .var v => .id (r.of v)
  | .neg v => .bitwiseNot (.id (r.of v))

def IntVar.toPythonExpr (r : NameResolver) (var : IntVar) : Python.Expr :=
  .id (r.of var)

def FixedSizeIntervalVar.toPythonExpr
    (r : NameResolver) (var : FixedSizeIntervalVar) : Python.Expr :=
  .id (r.of var)

/-- Lower a raw linear expression to a Python expression. Variables are named
    via the resolver applied to the (structural) identity of each `IntVar`. -/
def LinearExpr.Raw.toPythonExpr (r : NameResolver) :
    LinearExpr.Raw → Python.Expr
  | .fromVar value => .id (r.of value)
  | .fromConst value => .lit (.int value.val)
  | .fromNeg a => .neg (a.toPythonExpr r)
  | .fromMulConst a value =>
    .mul (.lit (.int value.val)) (a.toPythonExpr r)
  | .fromAdd a b => .add (a.toPythonExpr r) (b.toPythonExpr r)
  | .fromSub a b => .sub (a.toPythonExpr r) (b.toPythonExpr r)

def LinearExpr.toPythonExpr (r : NameResolver) (expr : LinearExpr) : Python.Expr :=
  expr.raw.toPythonExpr r

def BoundedLinearExpr.toPythonExpr
    (r : NameResolver) (expr : BoundedLinearExpr) : Python.Expr :=
  let left := expr.left.toPythonExpr r
  let right := expr.right.toPythonExpr r
  match expr.rel with
    | .eq => .eq left right
    | .neq => .neq left right
    | .gt => .gt left right
    | .gte => .gte left right
    | .lt => .lt left right
    | .lte => .lte left right

end CpsatSolver
