import CpsatScheduler.Defs

namespace CpsatScheduler

def UnitValue.add {u : UnitScale} (a b : UnitValue u)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val + b.coeff.val)) :
    UnitValue u :=
  ⟨⟨a.coeff.val + b.coeff.val, nonoverflow⟩⟩

def UnitValue.sub {u : UnitScale} (a b : UnitValue u)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val - b.coeff.val)) :
    UnitValue u :=
  ⟨⟨a.coeff.val - b.coeff.val, nonoverflow⟩⟩

def UnitValue.nsmul {u : UnitScale} (k : ℤ) (a : UnitValue u)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (k * a.coeff.val)) :
    UnitValue u :=
  ⟨⟨k * a.coeff.val, nonoverflow⟩⟩

/-- Exact division by a positive constant that divides the coefficient. -/
def UnitValue.edivConst {u : UnitScale} (a : UnitValue u) (d : ℕ)
    (_hd : 0 < d)
    (_divides : (d : ℤ) ∣ a.coeff.val)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (a.coeff.val / d)) :
    UnitValue u :=
  ⟨⟨a.coeff.val / d, nonoverflow⟩⟩

/-- Truncating division toward zero by a positive constant. -/
def UnitValue.tdivConst {u : UnitScale} (a : UnitValue u) (d : ℕ)
    (_hd : 0 < d)
    (nonoverflow : CpsatSolver.Int64.Nonoverflow (Int.tdiv a.coeff.val d)) :
    UnitValue u :=
  ⟨⟨Int.tdiv a.coeff.val d, nonoverflow⟩⟩

end CpsatScheduler
