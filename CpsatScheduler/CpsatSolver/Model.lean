import CpsatScheduler.CpsatSolver.Helpers
import Mathlib.Data.Finset.Lattice.Basic
import Mathlib.Data.Finset.Fold
import Mathlib.Data.Finset.Sort
import Mathlib.Data.Nat.SuccPred
import Mathlib.Data.List.Sort
import Mathlib.Algebra.Order.Ring.Nat

namespace CpsatSolver

namespace ScriptIDs
private def model := Python.ValidName.mk "model" (by native_decide)
private def solution := Python.ValidName.mk "solution" (by native_decide)
end ScriptIDs

def Var.uniqueNames {α : Type} [Var α] (ls : List α) :=
  ∀ a b : Fin ls.length, a ≠ b → (Var.name (ls.get a)) ≠ (Var.name (ls.get b))

structure Model where
  bools : List CpsatSolver.BoolVar
  boolsUniqueNames : Var.uniqueNames bools
  ints : List CpsatSolver.IntVar
  intsUniqueNames : Var.uniqueNames ints
  fixedSizeIntervals : List CpsatSolver.FixedSizeIntervalVar
  fixedSizeIntervalsUniqueNames : Var.uniqueNames fixedSizeIntervals
  constraints : List CpsatSolver.Constraint

def Model.union (left : Model) (right : Model)
  (boolsUniqueNames : Var.uniqueNames (left.bools ++ right.bools))
  (intsUniqueNames : Var.uniqueNames (left.ints ++ right.ints))
  (fixedSizeIntervalsUniqueNames :
    Var.uniqueNames (left.fixedSizeIntervals ++ right.fixedSizeIntervals))
  : Model :=
  {
    bools := left.bools ++ right.bools,
    boolsUniqueNames := boolsUniqueNames,
    ints := left.ints ++ right.ints,
    intsUniqueNames := intsUniqueNames,
    fixedSizeIntervals := left.fixedSizeIntervals ++ right.fixedSizeIntervals,
    fixedSizeIntervalsUniqueNames := fixedSizeIntervalsUniqueNames,
    constraints := left.constraints ++ right.constraints
  }

def Model.repr.boolVar (var : CpsatSolver.BoolVar) : Python.Statement :=
    Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
      Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id ScriptIDs.model)
          (Python.ValidName.mk "new_bool_var" (by native_decide)))
        #[
          (Python.Expr.lit (Python.Literal.str var.name.val))
        ]
    ))

def Model.repr.intVar (var : CpsatSolver.IntVar) : Python.Statement :=
    Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
      Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id ScriptIDs.model)
          (Python.ValidName.mk "new_int_var" (by native_decide)))
        #[
          (Python.Expr.lit (Python.Literal.int var.domain.min)),
          (Python.Expr.lit (Python.Literal.int var.domain.max)),
          (Python.Expr.lit (Python.Literal.str var.name.val)),
        ]
    ))

def Model.repr.fixedSizeIntervalVar (var : CpsatSolver.FixedSizeIntervalVar) : Python.Statement :=
    Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.name) (
      Python.Expr.call
        (Python.Expr.dot
          (Python.Expr.id ScriptIDs.model)
          (Python.ValidName.mk "new_fixed_size_interval" (by native_decide)))
        #[
          var.start.toPythonExpr,
          (Python.Expr.lit (Python.Literal.int var.size)),
          (Python.Expr.lit (Python.Literal.str var.name.val)),
        ]
    ))

def Model.repr.constraint (cnst : CpsatSolver.Constraint) : Python.Statement :=
    let modelDot (attr : Python.ValidName) : Python.Expr :=
      Python.Expr.dot (Python.Expr.id ScriptIDs.model) attr
    let constraint : Python.Expr := match cnst.variant with
      | Constraint.Variant.bounded_linear expr =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add" (by native_decide)))
          #[ expr.toPythonExpr ]
      | Constraint.Variant.bool_and terms =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_bool_and" (by native_decide)))
          (terms.map (fun t => t.toPythonExpr))
      | Constraint.Variant.bool_or terms =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_bool_or" (by native_decide)))
          (terms.map (fun t => t.toPythonExpr))
      | Constraint.Variant.implication src dst =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_implication" (by native_decide)))
          #[ src.toPythonExpr, dst.toPythonExpr ]
      | Constraint.Variant.max_equality target exprs =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_max_equality" (by native_decide)))
          (Array.append
            #[ target.toPythonExpr ]
            (exprs.map (fun e => e.toPythonExpr)))
      | Constraint.Variant.cumulative intervals demands capacity =>
        Python.Expr.call
          (modelDot (Python.ValidName.mk "add_cumulative" (by native_decide)))
          #[
            (Python.Expr.lit (Python.Literal.array
              (intervals.map (fun e => e.toPythonExpr)))),
            (Python.Expr.lit (Python.Literal.array
              (demands.map (fun e => e.toPythonExpr)))),
            capacity.toPythonExpr,
          ]
      ;
    let labeled :=
      Python.Expr.call
        (Python.Expr.dot
          constraint
          (Python.ValidName.mk "with_label" (by native_decide)))
        #[ (Python.Expr.lit (Python.Literal.str cnst.name.val)) ]
    let enforced := match cnst.enforcement with
      | Constraint.Enforcement.always => Python.Statement.exprLine labeled
      | Constraint.Enforcement.onlyWhenAll literals =>
        Python.Statement.exprLine (Python.Expr.call
          (Python.Expr.dot
            labeled
            (Python.ValidName.mk "only_enforce_if" (by native_decide)))
          (literals.toArray.map (fun (l : BoolLit) => l.toPythonExpr)))
      ;
    enforced

structure SolveRequest (m : Model) where
  ints : List CpsatSolver.IntVar
  intsValid : List.Subset ints m.ints
  -- TODO: implement these later
  -- bools : List CpsatSolver.BoolVar
  -- boolsValid : List.Subset bools m.bools
  -- fixedSizeIntervals : List CpsatSolver.FixedSizeIntervalVar
  -- fixedSizeIntervalsValid : List.Subset fixedSizeIntervals m.fixedSizeIntervals

structure SolveResponse (m : Model) (r : SolveRequest m) where
  ints : Std.HashMap
    { key // ∃ var ∈ m.ints, var.name.val = key }
    { val // CpsatSolver.Int64.Proof val }
  -- TODO: implement these later
  -- bools : Std.HashMap
  --   { key // ∃ var ∈ m.bools, var.name.val = key }
  --   Bool
  -- fixedSizeIntervals : Std.HashMap
  --   { key // ∃ var ∈ m.fixedSizeIntervals, var.name.val = key }
  --   { val // CpsatSolver.Int64.Proof val }

/--
theorem List.append_fin_length_sum {idx : ℕ} {a : List α} {b : List α}
  (h : idx < (a ++ b).length)
  : idx < (a.length + b.length) :=
    let hLengthAppendEq : (a ++ b).length = a.length + b.length :=
      List.length_append (as := a) (bs := b);
    Eq.subst
      (motive := fun x => idx < x)
      hLengthAppendEq h

def List.mergeSortInner {α : Type}
  [Preorder α]
  [DecidableLE α]
  (a : List α)
  (haSorted : a.SortedLE)
  (b : List α)
  (hbSorted : b.SortedLE)
  (out : List α)
  (houtSorted : out.SortedLE)
  (houtLastLeqA :
    (houtNonempty : out ≠ []) →
    (haNonempty : a ≠ []) →
      out.getLast houtNonempty ≤ a.head haNonempty
  )
  (houtLastLeqB :
    (houtNonempty : out ≠ []) →
    (hbNonempty : b ≠ []) →
      out.getLast houtNonempty ≤ b.head hbNonempty
  ) : { x : List α // List.SortedLE x } :=
    match a, b with
    | List.nil, List.nil => { val := out, property := houtSorted }
    | List.cons ahead atail, List.nil =>
      if outNonempty : out ≠ List.nil then
        let appended := out ++ a;
        let outLastH := houtLastLeqA
          outNonempty
          (List.cons_ne_nil ahead atail);
        let prop : appended.SortedLE := fun left right hLeftLeRight =>
          Fin.addCases (m := out.length) (n := a.length)
            (fun (leftNarrowed : Fin out.length) =>
              let leftEq : left.val = leftNarrowed.val := rfl;
              Fin.addCases (m := out.length) (n := a.length)
                (fun (rightNarrowed : Fin out.length) =>
                  let rightEq : right.val = rightNarrowed.val := rfl;
                  -- let equal : (leftNarrowed ≤ rightNarrowed) = (leftNarrowed.val ≤ rightNarrowed.val) :=
                  --   rfl;
                  -- let hLeftLeRight : leftNarrowed.val ≤ rightNarrowed.val :=
                  --   Eq.subst rightEq (Eq.subst
                  --     (motive := fun x => x ≤ right)
                  --     leftEq ▸ hLeftLeRight);
                  -- let tmp := houtSorted hLeftLeRight;
                  sorry
                )
                (fun (rightNarrowed : Fin a.length) => sorry)
                {
                  val := right.val,
                  isLt := List.append_fin_length_sum right.prop
                })
            (fun (leftNarrowed : Fin a.length) =>
              Fin.addCases (m := out.length) (n := a.length)
                (fun (rightNarrowed : Fin out.length) => sorry)
                (fun (rightNarrowed : Fin a.length) => sorry)
                {
                  val := right.val,
                  isLt := List.append_fin_length_sum right.prop
                })
            {
              val := left.val,
              isLt := List.append_fin_length_sum left.prop
            };
          -- for any i ∈ (old ++ new)
          -- i ∈ old ∨ i ∈ new
          --
          -- we prove that if we take any l,r from (old ++ new)
          -- s.t. l ≤ r
          -- 1. our cases are either:
          --    1. l ∈ old.bounds, r ∈ old.bounds -> use sorted old
          --    2. l ∈ old.bounds, r ∈ new.bounds -> use houtLastLeqA
          --    3. l ∈ new.bounds, r ∈ new.bounds -> use sorted a
        {
          val := appended,
          property := prop
        }
      else
        sorry
    | List.nil, List.cons _ _ => out.append b
    | List.cons ahead atail, List.cons bhead btail =>
      if ahead ≥ bhead then
        List.mergeSortInner (ahead :: atail) btail (out.append [ bhead ])
      else
        List.mergeSortInner atail (bhead :: btail) (out.append [ ahead ])
termination_by a.length + b.length

def List.mergeSort {α : Type}
  [Preorder α]
  [DecidableLE α]
  (a : List α)
  (b : List α) : List α :=
  List.mergeSortInner a b []

-- instance [LE α] [DecidableLE α]
--   : Std.Commutative fun a b => List.mergeSort (α := α) a b [] where
--     comm a b
--/

def Model.pythonScript (m : Model) : Python.Script :=
  let importCpModel :=
    (Python.Statement.importLine
      (Python.Import.fromForm
        #[
          (Python.ValidName.mk "ortools" (by native_decide)),
          (Python.ValidName.mk "sat" (by native_decide)),
          (Python.ValidName.mk "python" (by native_decide)),
        ]
        #[ (Python.NameAs.unaliased
            (Python.ValidName.mk "cp_model" (by native_decide))) ]));
  let intVars := m.ints.map (Model.repr.intVar ·)
  let boolVars := m.bools.map (Model.repr.boolVar ·)
  let fixedSizeIntervalsVars := m.fixedSizeIntervals.map (Model.repr.fixedSizeIntervalVar ·)
  let constraints := m.constraints.map (Model.repr.constraint ·)
  let statements := Array.append
    (Array.append
      (Array.append
        (Array.append
          #[ importCpModel ]
          intVars.toArray)
        boolVars.toArray)
      fixedSizeIntervalsVars.toArray)
    constraints.toArray
  { statements := statements }

end CpsatSolver

