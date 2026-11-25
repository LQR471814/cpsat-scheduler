module

import CpsatScheduler.Internal.CpsatSolver
meta import CpsatScheduler.Internal.CpsatSolver

open CpsatSolver

def x : Entity IntVar := .of
  {
    label := .some "x"
    domain := NonemptyDomain.of
      (Domain.ofInts #[1, 4, 7])
  }
  {}

def y : Entity IntVar := .of
  {
    label := .some "y"
    domain := NonemptyDomain.of
      (Domain.ofInts #[2, 4, 5, 7, 9])
  }
  { x.id }

def z : Entity IntVar := .of
  {
    label := .some "z"
    domain := NonemptyDomain.of
      (Domain.ofInts #[1, 2, 3, 6, 9])
  }
  { y.id }

def sum : LinearExpr :=
  (.add
    (.add (.var x) (.var y))
    (.var z))

def diff : LinearExpr :=
  (.sub
    (.add (.mul (.var x) (int 3)) (.var y))
    (.var z))

def model : Model := {
  spec := {
    ints := { x, y, z }
    bools := {}
    intervals := {}
    constraints := {}
    objective := .of (Objective.maximize sum) {}
  }
  refs_exist := by
    unfold AllRefsExist
    native_decide
}
