import CpsatScheduler.CpsatSolver.Basic
import CpsatScheduler.CpsatSolver.Helpers

import Mathlib.Data.Finset.Defs

import Std.Data.Iterators
import Lean.Data.Json.Basic

namespace CpsatSolver

namespace ScriptIDs
private def model := "model"
private def solution := "solution"
end ScriptIDs

structure Model where
  boolVars : Finset CpsatSolver.BoolVar
  intVars : Finset CpsatSolver.IntVar
  constraints : Finset CpsatSolver.Constraint

def Model.repr.boolVarDef
  (m : Model)
  (var : CpsatSolver.BoolVar)
  (_ : var ∈ m.boolVars) :=
    let name := Lean.Json.compress (Lean.Json.str var.name);
    s!"{var.name} = {ScriptIDs.model}.new_bool_var({name})"

def Model.repr.intVarDef
  (m : Model)
  (var : CpsatSolver.IntVar)
  (_ : var ∈ m.intVars) :=
    let name := Lean.Json.compress (Lean.Json.str var.name);
    s!"{var.name} = {ScriptIDs.model}.new_int_var({var.domain.min}, {var.domain.max}, {name})"

def Model.repr.constraintDef
  (m : Model)
  (cnst : CpsatSolver.Constraint)
  (_ : cnst ∈ m.constraints) :=
    let joinReprsWithCommas {α : Type} [ToString α] (args : List α) :=
      ", ".intercalate (args.map (fun (x : α) => s!"{x}"))
    let constraint := match cnst.variant with
      | Constraint.Variant.bounded_linear expr =>
        s!"{ScriptIDs.model}.add({expr.repr})"
      | Constraint.Variant.bool_and terms =>
        s!"{ScriptIDs.model}.add_bool_and({joinReprsWithCommas terms})"
      | Constraint.Variant.bool_or terms =>
        s!"{ScriptIDs.model}.add_bool_or({joinReprsWithCommas terms})"
      | Constraint.Variant.implication src dst =>
        s!"{ScriptIDs.model}.add_implication({src}, {dst})"
      | Constraint.Variant.max_equality target exprs =>
        s!"{ScriptIDs.model}.add_max_equality({target}, {joinReprsWithCommas exprs})"
      | Constraint.Variant.cumulative intervals demands capacity =>
        sorry
      ;
    let label :=
      let nameQuoted := Lean.Json.compress (Lean.Json.str cnst.name);
      s!".with_label({nameQuoted})";
    let enforcement := match cnst.enforcement with
      | Constraint.Enforcement.always => ""
      | Constraint.Enforcement.onlyWhenAll literals =>
        s!".only_enforce_if({joinReprsWithCommas literals.toList})"
      ;
    s!"{constraint}{label}{enforcement}"

structure SolveRequest (m : Model) where
  requestBoolVars : Finset CpsatSolver.BoolVar
  requestIntVars : Finset CpsatSolver.IntVar
  boolVarsIsSubset : requestBoolVars ⊆ m.boolVars
  intVarsIsSubset : requestIntVars ⊆ m.intVars

structure SolveResponse (m : Model) where


-- TODO: add an "extend model" function that extends a model with additional
-- definitions or constraints

-- TODO: add a structure representing a "solve request" along with "queries"
-- for information in the solution

end CpsatSolver

