module

public import CpsatScheduler.Internal.CpsatSolver.Defs
public import CpsatScheduler.Internal.Python.Basic

public import CpsatScheduler.Internal.CpsatSolver.Encodability

public section

namespace CpsatSolver

private theorem char_ge_zero_or_le_nine (c : Char) : '0' ≤ c ∨ c ≤ '9' := by
  rcases Nat.le_total c.val.toNat '9'.val.toNat with h | h
  · exact Or.inr h
  · exact Or.inl (Nat.le_trans (by native_decide) h)

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

theorem Python.encodableName_proof (s : String) :
    Python.ValidName.Proof ("e_" ++ s) :=
  ⟨not_reserved_e_suffix s, validIdent_e_suffix s⟩

/-- Build a valid Python identifier from a value's `HasRepr` representation:
    the `List ℕ` repr is rendered as underscore-joined decimal digits behind an
    `"e_"` prefix. The suffix contains only digits and underscores, so the
    `ValidName.Proof` lemmas apply unchanged. -/
def Python.encodableName [HasRepr α] (enc : α) :
    Python.ValidName :=
  let s := String.intercalate "_" ((HasRepr.toRepr enc).map toString)
  ⟨"e_" ++ s, Python.encodableName_proof s⟩

class Python.ToExpr (α : Type) where
  toPythonExpr : α → Python.Expr

def BoolLit.toPythonExpr (b : BoolLit) : Python.Expr :=
  match b with
  | .var v => .id (Python.encodableName v)
  | .neg v => .bitwiseNot (.id (Python.encodableName v))

instance : Python.ToExpr BoolLit where
  toPythonExpr := BoolLit.toPythonExpr

def IntVar.toPythonExpr (var : IntVar) : Python.Expr :=
  .id (Python.encodableName var)

instance : Python.ToExpr IntVar where
  toPythonExpr := IntVar.toPythonExpr

def FixedSizeIntervalVar.toPythonExpr (var : FixedSizeIntervalVar) : Python.Expr :=
  .id (Python.encodableName var)

instance : Python.ToExpr FixedSizeIntervalVar where
  toPythonExpr := FixedSizeIntervalVar.toPythonExpr

def LinearExpr.Raw.toPythonExpr : LinearExpr.Raw → Python.Expr
  | .fromVar value => value.toPythonExpr
  | .fromConst value => .lit (.int value.val)
  | .fromNeg a => .neg a.toPythonExpr
  | .fromMulConst a value =>
    .mul (.lit (.int value.val)) a.toPythonExpr
  | .fromAdd a b => .add a.toPythonExpr b.toPythonExpr
  | .fromSub a b => .sub a.toPythonExpr b.toPythonExpr

def LinearExpr.toPythonExpr (e : LinearExpr) : Python.Expr :=
  e.raw.toPythonExpr

instance : Python.ToExpr LinearExpr where
  toPythonExpr := LinearExpr.toPythonExpr

def BoundedLinearExpr.toPythonExpr (expr : BoundedLinearExpr) : Python.Expr :=
  let left := expr.left.raw.toPythonExpr
  let right := expr.right.raw.toPythonExpr
  match expr.rel with
    | .eq => .eq left right
    | .neq => .neq left right
    | .gt => .gt left right
    | .gte => .gte left right
    | .lt => .lt left right
    | .lte => .lte left right

instance : Python.ToExpr BoundedLinearExpr where
  toPythonExpr := BoundedLinearExpr.toPythonExpr

end CpsatSolver
