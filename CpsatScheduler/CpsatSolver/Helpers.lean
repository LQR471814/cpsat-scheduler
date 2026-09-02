import CpsatScheduler.CpsatSolver.Defs

import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Algebra.Order.Group.Defs
import Mathlib.Algebra.Order.Group.Int

namespace CpsatSolver

open CpsatSolver

instance : Decidable (Int64.Proof α) :=
  (inferInstance : Decidable (α ≥ Int64.min ∧ α ≤ Int64.max))

instance : Decidable (Interval.Proof α) :=
  (inferInstance : Decidable (
    α.min ≤ α.max ∧
    Int64.Proof α.min ∧
    Int64.Proof α.max
  ))

instance : Decidable (IntVar.Proof α) :=
  (inferInstance : Decidable (Interval.Proof α.domain))

def BoolLit.toPythonExpr (b : BoolLit) : Python.Expr := match b with
  | BoolLit.var v => Python.Expr.id v.name
  | BoolLit.neg v => Python.Expr.bitwiseNot (
    Python.Expr.id v.name
  )

def IntVar.toPythonExpr (var : IntVar) : Python.Expr :=
  Python.Expr.id var.name

def FixedSizeIntervalVar.toPythonExpr (var : FixedSizeIntervalVar) : Python.Expr :=
  Python.Expr.id var.name

def LinearExpr.Proven.toPythonExpr (expr : LinearExpr.Proven) : Python.Expr :=
  match expr with
    | { op := LinearExpr.Op.var var _, proof := _ } => Python.Expr.id var.name
    | { op := LinearExpr.Op.const value _, proof := _ }  =>
      Python.Expr.lit (Python.Literal.int value)
    | { op := LinearExpr.Op.neg subexpr, proof := _ } =>
      Python.Expr.neg subexpr.toPythonExpr
    | { op := LinearExpr.Op.add left right, proof := _ } =>
      Python.Expr.add left.toPythonExpr right.toPythonExpr
    | { op := LinearExpr.Op.sub left right, proof := _ } =>
      Python.Expr.sub left.toPythonExpr right.toPythonExpr
    | { op := LinearExpr.Op.mul left right, proof := _ } =>
      Python.Expr.mul left.toPythonExpr right.toPythonExpr
termination_by structural expr

def BoundedLinearExpr.toPythonExpr (expr : BoundedLinearExpr) : Python.Expr :=
  match expr with
  | BoundedLinearExpr.eq a b =>
    Python.Expr.eq a.toPythonExpr b.toPythonExpr
  | BoundedLinearExpr.neq a b =>
    Python.Expr.neq a.toPythonExpr b.toPythonExpr
  | BoundedLinearExpr.gt a b =>
    Python.Expr.gt a.toPythonExpr b.toPythonExpr
  | BoundedLinearExpr.gte a b =>
    Python.Expr.gte a.toPythonExpr b.toPythonExpr
  | BoundedLinearExpr.lt a b =>
    Python.Expr.lt a.toPythonExpr b.toPythonExpr
  | BoundedLinearExpr.lte a b =>
    Python.Expr.lte a.toPythonExpr b.toPythonExpr

def LinearExpr.var
  (value : IntVar)
  (H : IntVar.Proof value) : LinearExpr.Proven :=
  {
    op := LinearExpr.Op.var value H,
    proof := {
      domain := value.domain,
      domainValid := H
    }
  }

def LinearExpr.const
  (value : ℤ)
  (H : Int64.Proof value) : LinearExpr.Proven :=
  {
    op := LinearExpr.Op.const value H,
    proof :=
      let domain : Interval := {
        min := value,
        max := value
      };
      {
        domain := domain,
        domainValid := And.intro (le_refl value) (And.intro H H)
      }
  }

def LinearExpr.neg
  (a : LinearExpr.Proven) :=
  let neg : Interval := {
    min := -a.proof.domain.max,
    max := -a.proof.domain.min
  };
  let curried
    (Hmin : Int64.Proof neg.min)
    (Hmax : Int64.Proof neg.max) : LinearExpr.Proven :=
    let min_le_max : neg.min ≤ neg.max :=
      neg_le_neg a.proof.domainValid.left;
    {
      op := LinearExpr.Op.neg a,
      proof := {
        domain := neg,
        domainValid := And.intro min_le_max (And.intro Hmin Hmax)
      }
    };
  curried

def LinearExpr.add
  (left : LinearExpr.Proven)
  (right : LinearExpr.Proven) :=
  let leftDomain := left.proof.domain;
  let rightDomain := right.proof.domain;
  let added : Interval := {
    min := leftDomain.min + rightDomain.min,
    max := leftDomain.max + rightDomain.max
  };
  let curried
    (Hmin : Int64.Proof added.min)
    (Hmax : Int64.Proof added.max) : LinearExpr.Proven :=
    let min_le_max : added.min ≤ added.max :=
      -- a <= a'
      -- b <= b'
      --
      -- 1. a + b <= a' + b
      -- 2. b + a' <= b' + a'
      -- 3. b + a' = a' + b
      -- 4. a' + b <= b' + a'
      -- 5. a + b <= a' + b'
      let a := leftDomain.min;
      let a' := leftDomain.max;
      let b := rightDomain.min;
      let b' := rightDomain.max;
      let a_lt_a' : a ≤ a' := left.proof.domainValid.left;
      let b_lt_b' : b ≤ b' := right.proof.domainValid.left;
      -- let st1 : a + b ≤ a' + b := add_le_add_left a_lt_a' b;
      -- let st2 : b + a' ≤ b' + a' := add_le_add_left b_lt_b' a';
      -- let st3 : b + a' = a' + b := add_comm b a';
      -- let st4 : a' + b ≤ b' + a' :=
      --   Eq.subst (motive := fun n => n ≤ b' + a') st3 st2
      -- let st5 : a + b ≤ b' + a' :=
      --   le_trans st1 st4
      -- let st6 : b' + a' = a' + b' := add_comm b' a';
      -- let st7 : a + b ≤ a' + b' :=
      --   Eq.subst (motive := fun n => a + b ≤ n) st6 st5
      -- st7
      --
      -- NOTE: the above is equivalent to the following
      add_le_add a_lt_a' b_lt_b'
    {
      op := LinearExpr.Op.add left right,
      proof := {
        domain := added,
        domainValid := And.intro min_le_max (And.intro Hmin Hmax)
      }
    }
  curried

def LinearExpr.sub
  (left : LinearExpr.Proven)
  (right : LinearExpr.Proven) :=
  let leftDomain := left.proof.domain;
  let rightDomain := right.proof.domain;
  let subtracted : Interval := {
    min := leftDomain.min - rightDomain.max,
    max := leftDomain.max - rightDomain.min
  };
  let curried
    (Hmin : Int64.Proof subtracted.min)
    (Hmax : Int64.Proof subtracted.max) : LinearExpr.Proven :=
    let min_le_max : subtracted.min ≤ subtracted.max :=
      let a := leftDomain.min;
      let a' := leftDomain.max;
      let b := rightDomain.min;
      let b' := rightDomain.max;
      let a_lt_a' : a ≤ a' := left.proof.domainValid.left;
      let b_lt_b' : b ≤ b' := right.proof.domainValid.left;
      sub_le_sub a_lt_a' b_lt_b'
    {
      op := LinearExpr.Op.sub left right,
      proof := {
        domain := subtracted,
        domainValid := And.intro min_le_max (And.intro Hmin Hmax)
      }
    };
  curried

def LinearExpr.mul
  (left : LinearExpr.Proven)
  (right : LinearExpr.Proven) :=
  let c1 := left.proof.domain.min * right.proof.domain.min;
  let c2 := left.proof.domain.min * right.proof.domain.max;
  let c3 := left.proof.domain.max * right.proof.domain.min;
  let c4 := left.proof.domain.max * right.proof.domain.max;
  let domain : Interval := {
    min := min (min (min c1 c2) c3) c4,
    max := max (max (max c1 c2) c3) c4
  };
  let curried
    (Hmin : Int64.Proof domain.min)
    (Hmax : Int64.Proof domain.max) : LinearExpr.Proven :=
      let domainValid : domain.Proof :=
        And.intro (
          (min_le_left _ _).trans (
            (min_le_left _ _).trans (
              (min_le_left _ _).trans (
                (le_max_left _ _).trans (
                  (le_max_left _ _).trans (
                    le_max_left _ _
                  )
                )
              )
            )
          )
        ) (And.intro Hmin Hmax)
      {
        op := LinearExpr.Op.mul left right,
        proof := {
          domain := domain,
          domainValid := domainValid
        }
      };
  curried

#eval
  let intVarLeft := IntVar.mk
    (Python.ValidName.mk "hello" (by native_decide))
    { min := -1, max := 3 }
  let intVarRight := IntVar.mk
    (Python.ValidName.mk "hello2" (by native_decide))
    { min := -5, max := -2 }
  let left := LinearExpr.var intVarLeft (of_decide_eq_true rfl);
  let right := LinearExpr.var intVarRight (of_decide_eq_true rfl);
  let multiplied := LinearExpr.mul left right (of_decide_eq_true rfl) (of_decide_eq_true rfl);
  multiplied.proof.domain

abbrev Var.uniqueNames {α : Type} [Var α] (arr : Array α) :=
  ∀ a b : Fin arr.size, a ≠ b → (Var.name (arr[a])) ≠ (Var.name (arr[b]))

end CpsatSolver
