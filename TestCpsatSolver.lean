import CpsatScheduler.CpsatSolver.Model

open CpsatSolver

def x : IntVar := {
  name := Python.ValidName.mk "x" (by native_decide),
  domain := {
    min := 0,
    max := 10
  }
}

def y : IntVar := {
  name := Python.ValidName.mk "y" (by native_decide),
  domain := {
    min := 0,
    max := 5
  }
}

def model : Model := {
  ints := #[ x, y ],
  bools := #[],
  fixedSizeIntervals := #[],
  intsUniqueNames := by decide,
  boolsUniqueNames := by decide,
  fixedSizeIntervalsUniqueNames := by decide,
  constraints := #[
    (Constraint.mk
      (Python.ValidName.mk "default" (by native_decide))
      Constraint.Enforcement.always
      (Constraint.Variant.bounded_linear
        (BoundedLinearExpr.eq
          (LinearExpr.mul
            (LinearExpr.const 3 (by decide))
            (LinearExpr.var x (by decide))
            (by decide)
            (by decide))
          (LinearExpr.sub
            (LinearExpr.mul
              (LinearExpr.const 5 (by decide))
              (LinearExpr.var y (by decide))
              (by decide)
              (by decide))
            (LinearExpr.const 4 (by decide))
            (by decide)
            (by decide))
        ))
    )
  ]
}

def runtime : Python.Runtime := {
  path := ".venv/bin/python3"
}

def main : IO Unit := do
  sorry
