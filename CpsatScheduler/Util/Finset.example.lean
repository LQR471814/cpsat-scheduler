import Mathlib

import CpsatScheduler.CpsatSolver.Python

def exSet : Finset CpsatSolver.Python.ValidName := {
  (CpsatSolver.Python.ValidName.mk "hello" (by native_decide)),
  (CpsatSolver.Python.ValidName.mk "world" (by native_decide))
}

def nameOf (ofSet : exSet) := ofSet.val.val

lemma nameOf_injective : Function.Injective nameOf :=
  by decide

private abbrev nameLE (a b : exSet) : Prop :=
  nameOf a ≤ nameOf b

instance : LE exSet where
  le := nameLE

instance : DecidableLE exSet :=
  fun a b => if h : nameOf a ≤ nameOf b then
    Decidable.isTrue h
  else
    Decidable.isFalse h

instance : Std.Antisymm nameLE where
  antisymm (a b : exSet) (rab : nameLE a b) (rba : nameLE b a) : a = b :=
    let splitRab := lt_or_eq_of_le rab;
    let splitRba := lt_or_eq_of_le rba;
    Or.elim splitRab
      (fun aLtB => Or.elim splitRba
        (fun bLtA => False.elim
          ((and_not_self_iff (nameOf b < nameOf a)).mp
            (And.intro bLtA (lt_asymm aLtB))))
        (fun bEqA => nameOf_injective bEqA.symm))
      (fun aEqB => nameOf_injective aEqB)

def ranking := exSet.attach.sort (fun a b => nameLE a b)

