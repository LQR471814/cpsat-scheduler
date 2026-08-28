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
  vars : Finset CpsatSolver.Var
  constraints : Finset CpsatSolver.Constraint

def Model.isBoolVar (var : CpsatSolver.Var) (boolVar : CpsatSolver.BoolVar) : Prop :=
  match var with
  | CpsatSolver.Var.bool v => (v = boolVar)
  | _ => False

instance
  (var : CpsatSolver.Var)
  (boolVar : CpsatSolver.BoolVar) : Decidable (Model.isBoolVar var boolVar) :=
  match var with
  | CpsatSolver.Var.bool b => (inferInstance : (Decidable (b = boolVar)))
  | CpsatSolver.Var.int _ => Decidable.isFalse (fun h => h)
  | CpsatSolver.Var.fixedSizeInterval _ => Decidable.isFalse (fun h => h)

def Model.hasBoolVar (m : Model) (boolVar : CpsatSolver.BoolVar) :=
  ∃ var ∈ m.vars, Model.isBoolVar var boolVar

instance : Decidable (Model.hasBoolVar α β) :=
  (inferInstance : Decidable (∃ var ∈ α.vars, Model.isBoolVar var β))

def Model.isIntVar (var : CpsatSolver.Var) (intVar : CpsatSolver.IntVar) : Prop :=
  match var with
  | CpsatSolver.Var.int v => (v = intVar)
  | _ => False

instance
  (var : CpsatSolver.Var)
  (intVar : CpsatSolver.IntVar) : Decidable (Model.isIntVar var intVar) :=
  match var with
  | CpsatSolver.Var.bool _ => Decidable.isFalse (fun h => h)
  | CpsatSolver.Var.int i => (inferInstance : (Decidable (i = intVar)))
  | CpsatSolver.Var.fixedSizeInterval _ => Decidable.isFalse (fun h => h)

def Model.hasIntVar (m : Model) (intVar : CpsatSolver.IntVar) :=
  ∃ var ∈ m.vars, Model.isIntVar var intVar

instance : Decidable (Model.hasIntVar α β) :=
  (inferInstance : Decidable (∃ var ∈ α.vars, Model.isIntVar var β))

def Model.repr.boolVarDef
  (m : Model)
  (var : CpsatSolver.BoolVar)
  (_ : Model.hasBoolVar m var) :=
    let name := Lean.Json.compress (Lean.Json.str var.name);
    s!"{var.name} = {ScriptIDs.model}.new_bool_var({name})"

def Model.repr.intVarDef
  (m : Model)
  (var : CpsatSolver.IntVar)
  (_ : Model.hasIntVar m var) :=
    let name := Lean.Json.compress (Lean.Json.str var.name);
    s!"{var.name} = {ScriptIDs.model}.new_int_var({var.domain.min}, {var.domain.max}, {name})"

def Model.repr.constraintDef
  (m : Model)
  (cnst : CpsatSolver.Constraint)
  (_ : cnst ∈ m.constraints) :=
    let joinReprsWithCommas {α : Type} [ToString α] (args : Array α) :=
      ", ".intercalate (args.map (fun (x : α) => s!"{x}")).toList
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
        s!"{ScriptIDs.model}.add_cumulative(
            [{joinReprsWithCommas intervals}],
            [{joinReprsWithCommas demands}],
            {capacity}
          )"
      ;
    let label :=
      let nameQuoted := Lean.Json.compress (Lean.Json.str cnst.name);
      s!".with_label({nameQuoted})";
    let enforcement := match cnst.enforcement with
      | Constraint.Enforcement.always => ""
      | Constraint.Enforcement.onlyWhenAll literals =>
        s!".only_enforce_if({joinReprsWithCommas literals.toArray})"
      ;
    s!"{constraint}{label}{enforcement}"

structure SolveRequest (m : Model) where
  requestVars : Finset CpsatSolver.Var
  varsIsSubset : requestVars ⊆ m.vars

structure SolveResponse (m : Model) where

-- TODO: add an "extend model" function that extends a model with additional
-- definitions or constraints

-- TODO: add a structure representing a "solve request" along with "queries"
-- for information in the solution

end CpsatSolver

