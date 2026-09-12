import CpsatScheduler.CpsatSolver.Model

open CpsatSolver

def x : IntVar := {
  name := Python.ValidName.mk "x" (by decide)
  domain := {
    left := { val := 0, nonoverflow := by decide }
    right := { val := 10, nonoverflow := by decide }
    left_le_right := by decide
  }
}

def y : IntVar := {
  name := Python.ValidName.mk "y" (by decide)
  domain := {
    left := { val := 0, nonoverflow := by decide }
    right := { val := 5, nonoverflow := by decide }
    left_le_right := by decide
  }
}

def model : Model := {
  ints := #[x, y]
  intsUniqueNames := by decide
  bools := #[]
  boolsUniqueNames := by decide
  fixedSizeIntervals := #[]
  fixedSizeIntervalsUniqueNames := by decide
  constraints := #[]
}

def req : SolveRequest model := {
  exprs := #[⟨x.domain, LinearExpr.var x⟩, ⟨y.domain, LinearExpr.var y⟩]
}

def main : IO Unit := do
  IO.println (model.script req).repr
