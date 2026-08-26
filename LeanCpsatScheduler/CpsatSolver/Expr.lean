import LeanCpsatScheduler.CpsatSolver.Var
import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Algebra.Order.Group.Defs
import Mathlib.Algebra.Order.Group.Int

namespace CpsatSolver

structure LinearExpr.Proof where
  domain : CpsatSolver.Interval
  domainValid : CpsatSolver.Interval.Proof domain

mutual
-- LinearExpr is a linear expr that evaluates to an ℤ
inductive LinearExpr.Op where
  | var (value : CpsatSolver.IntVar) (H : CpsatSolver.IntVar.Proof value)
  | const (value : ℤ) (H : CpsatSolver.Int64.Proof value)
  | neg (a : LinearExpr.Proven)
  | add (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | mul (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | sub (a : LinearExpr.Proven) (b : LinearExpr.Proven)

structure LinearExpr.Proven where
  op : LinearExpr.Op
  proof : LinearExpr.Proof
end

def LinearExpr.id
  (value : CpsatSolver.IntVar)
  (H : CpsatSolver.IntVar.Proof value) : LinearExpr.Proven :=
  {
    op := LinearExpr.Op.var value H,
    proof := {
      domain := value.domain,
      domainValid := H
    }
  }

def LinearExpr.const
  (value : ℤ)
  (H : CpsatSolver.Int64.Proof value) : LinearExpr.Proven :=
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
    (Hmin : CpsatSolver.Int64.Proof neg.min)
    (Hmax : CpsatSolver.Int64.Proof neg.max) : LinearExpr.Proven :=
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
    (Hmin : CpsatSolver.Int64.Proof added.min)
    (Hmax : CpsatSolver.Int64.Proof added.max) : LinearExpr.Proven :=
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
    (Hmin : CpsatSolver.Int64.Proof subtracted.min)
    (Hmax : CpsatSolver.Int64.Proof subtracted.max) : LinearExpr.Proven :=
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
    (Hmin : CpsatSolver.Int64.Proof domain.min)
    (Hmax : CpsatSolver.Int64.Proof domain.max) : LinearExpr.Proven :=
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

def LinearExpr.Proven.repr (expr : LinearExpr.Proven) : String :=
  match expr with
    | { op := LinearExpr.Op.var var _, proof := _ } => var.name
    | { op := LinearExpr.Op.const value _, proof := _ }  => value.repr
    | { op := LinearExpr.Op.neg e, proof := _ } => s!"- ({e.repr})"
    | { op := LinearExpr.Op.add left right, proof := _ } =>
      s!"({left.repr}) + ({right.repr})"
    | { op := LinearExpr.Op.sub left right, proof := _ } =>
      s!"({left.repr}) - ({right.repr})"
    | { op := LinearExpr.Op.mul left right, proof := _ } =>
      s!"({left.repr}) * ({right.repr})"
termination_by structural expr

instance : ToString LinearExpr.Proven where
  toString := LinearExpr.Proven.repr

-- BoolLit is a CpsatSolver.BoolVar or its negation
inductive BoolLit where
  | id (v : CpsatSolver.BoolVar)
  | neg (v : CpsatSolver.BoolVar)

-- BoundedLinearExpr is LinearExpr with some bounding operators applied on it
-- (e.g. >, <, ==)
inductive BoundedLinearExpr where
  | eq (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | neq (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | gt (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | gte (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | lt (a : LinearExpr.Proven) (b : LinearExpr.Proven)
  | lte (a : LinearExpr.Proven) (b : LinearExpr.Proven)

def BoundedLinearExpr.repr (expr : BoundedLinearExpr) : String :=
  match expr with
  | BoundedLinearExpr.eq a b => s!"({a.repr}) == ({b.repr})"
  | BoundedLinearExpr.neq a b => s!"({a.repr}) != ({b.repr})"
  | BoundedLinearExpr.gt a b => s!"({a.repr}) > ({b.repr})"
  | BoundedLinearExpr.gte a b => s!"({a.repr}) >= ({b.repr})"
  | BoundedLinearExpr.lt a b => s!"({a.repr}) < ({b.repr})"
  | BoundedLinearExpr.lte a b => s!"({a.repr}) <= ({b.repr})"

instance : ToString BoundedLinearExpr where
  toString := BoundedLinearExpr.repr

inductive ConstraintEnforcement where
  | always
  | onlyWhenAll {n : Nat} (literals : Vector BoolLit (n + 1))

structure Constraint where
  name : String
  expr : BoundedLinearExpr
  enforce : ConstraintEnforcement

#eval
  let intVarLeft := CpsatSolver.IntVar.mk "hello" { min := -1, max := 3 }
  let intVarRight := CpsatSolver.IntVar.mk "hello2" { min := -5, max := -2 }
  let left := LinearExpr.id intVarLeft (of_decide_eq_true rfl);
  let right := LinearExpr.id intVarRight (of_decide_eq_true rfl);
  let multiplied := LinearExpr.mul left right (of_decide_eq_true rfl) (of_decide_eq_true rfl);
  multiplied.proof.domain

end CpsatSolver
