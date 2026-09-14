import CpsatScheduler.CpsatSolver.Model

open CpsatSolver

def xDomain : NonemptyDomain :=
  NonemptyDomain.interval (Interval.ofBounds 0 10 ⟨by decide, by decide⟩ (by decide))

def yDomain : NonemptyDomain :=
  NonemptyDomain.interval (Interval.ofBounds 0 5 ⟨by decide, by decide⟩ (by decide))

def demo : RawModel × (IntVar × IntVar) :=
  Builder.run do
    let x ← Builder.newIntVar xDomain (some "x (not a python ident!)")
    let y ← Builder.newIntVar yDomain (some "y")
    pure (x, y)

def demoRaw : RawModel := demo.1
def x : IntVar := demo.2.1
def y : IntVar := demo.2.2

def main : IO Unit := do
  IO.println s!"allocated ids x={x.id.val} y={y.id.val} next={demoRaw.nextId}"
  IO.println s!"python names {x.id.toPythonName.val} {y.id.toPythonName.val}"
