import CpsatScheduler.CpsatSolver.Entity

namespace CpsatSolver

private theorem char_ge_zero_or_le_nine (c : Char) : '0' ≤ c ∨ c ≤ '9' := by
  by_cases h : '0' ≤ c
  · exact Or.inl h
  · exact Or.inr (le_of_lt (lt_of_lt_of_le (lt_of_not_ge h) (by decide)))

private theorem EntityID.validIdent_e_suffix (s : String) :
    Python.ValidIdent ("e_" ++ s) := by
  intro i
  exact Or.inr (Or.inr (Or.inr fun _ => char_ge_zero_or_le_nine _))

private theorem EntityID.not_reserved_e_suffix (s : String) :
    ¬ ("e_" ++ s) ∈ Python.ReservedKeywords := by
  have hkw : ∀ kw ∈ Python.ReservedKeywords, '_' ∉ kw.toList := by
    decide
  intro hmem
  have : '_' ∈ ("e_" ++ s).toList := by
    simp [String.toList_append]
  exact (hkw _ hmem) this

theorem EntityID.toPythonName_proof (n : Nat) :
    Python.ValidName.Proof ("e_" ++ toString n) :=
  ⟨EntityID.not_reserved_e_suffix (toString n),
    EntityID.validIdent_e_suffix (toString n)⟩

def EntityID.toPythonName (id : EntityID) : Python.ValidName :=
  ⟨"e_" ++ toString id, EntityID.toPythonName_proof id⟩

def BoolLit.toPythonExpr (b : BoolLit) : Python.Expr :=
  match b with
  | .var v => .id (EntityID.toPythonName v.id)
  | .neg v => .bitwiseNot (.id (EntityID.toPythonName v.id))

def IntVar.toPythonExpr (var : IntVar) : Python.Expr :=
  .id (EntityID.toPythonName var.id)

def FixedSizeIntervalVar.toPythonExpr (var : FixedSizeIntervalVar) : Python.Expr :=
  .id (EntityID.toPythonName var.id)

def LinearExpr.toPythonExpr {bounds : Bounds} (expr : LinearExpr bounds) : Python.Expr :=
  match expr with
  | .fromVar value => value.toPythonExpr
  | .fromConst value => .lit (.int value.val)
  | .fromNeg a _ => .neg a.toPythonExpr
  | .fromMulConst a value _ =>
    .mul (.lit (.int value.val)) a.toPythonExpr
  | .fromAdd a b _ => .add a.toPythonExpr b.toPythonExpr
  | .fromSub a b _ => .sub a.toPythonExpr b.toPythonExpr

def BoundedLinearExpr.toPythonExpr (expr : BoundedLinearExpr) : Python.Expr :=
  let left := @LinearExpr.toPythonExpr expr.leftBounds expr.left
  let right := @LinearExpr.toPythonExpr expr.rightBounds expr.right
  match expr.rel with
    | .eq => .eq left right
    | .neq => .neq left right
    | .gt => .gt left right
    | .gte => .gte left right
    | .lt => .lt left right
    | .lte => .lte left right

end CpsatSolver
