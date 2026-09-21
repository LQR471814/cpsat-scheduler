import CpsatScheduler.CpsatSolver.LinearExpr
import CpsatScheduler.CpsatSolver.ToPython

import Lean.Data.Json.Parser

/-!
# CP-SAT model builder, assignment checking, and Python serialization
-/

namespace CpsatSolver

namespace Model.Python.Name
private def print := Python.ValidName.mk "print" (by decide)
private def json := Python.ValidName.mk "json" (by decide)
private def cpModelLib := Python.ValidName.mk "cp_model" (by decide)
private def model := Python.ValidName.mk "__cpsat_model__" (by decide)
private def cpsatSolver := Python.ValidName.mk "__cpsat_solver__" (by decide)
private def solveStatus := Python.ValidName.mk "__solve_status__" (by decide)
private def output := Python.ValidName.mk "__output__" (by decide)
end Model.Python.Name

namespace Model.Python.Literals
private def ints := "ints"
private def bools := "bools"
private def status := "status"
private def solverObjective := "solver_objective"
end Model.Python.Literals

structure RawModel where
  nextId : Nat := 0
  ints : Array IntVar := #[]
  bools : Array BoolVar := #[]
  intervals : Array FixedSizeIntervalVar := #[]
  constraints : Array Constraint := #[]
  objective : Objective := .none

def RawModel.declaredIntIds (m : RawModel) : List EntityId :=
  m.ints.toList.map (·.id)

def RawModel.declaredBoolIds (m : RawModel) : List EntityId :=
  m.bools.toList.map (·.id)

def RawModel.declaredIntervalIds (m : RawModel) : List EntityId :=
  m.intervals.toList.map (·.id)

def RawModel.ReferencesWellFormed (m : RawModel) : Prop :=
  (∀ v ∈ m.ints, v.id.val < m.nextId) ∧
  (∀ v ∈ m.bools, v.id.val < m.nextId) ∧
  (∀ v ∈ m.intervals, v.id.val < m.nextId) ∧
  (∀ c ∈ m.constraints, c.id.val < m.nextId) ∧
  (∀ c ∈ m.constraints,
    (∀ v ∈ c.intVars, v.id ∈ m.declaredIntIds) ∧
    (∀ b ∈ c.enforcement.boolVars, b.id ∈ m.declaredBoolIds)) ∧
  (∀ e ∈ m.objective.intVars, e.id ∈ m.declaredIntIds)

structure Model where
  raw : RawModel
  uniqueInts : idsUnique raw.ints
  uniqueBools : idsUnique raw.bools
  uniqueIntervals : idsUnique raw.intervals
  uniqueConstraints : idsUnique raw.constraints
  references : raw.ReferencesWellFormed
  variantsWF : ∀ c ∈ raw.constraints, c.variant.WellFormed
  presolve : ∀ c ∈ raw.constraints, c.PassesPresolveSanityChecks

abbrev Builder := StateM RawModel

def Builder.freshId : Builder EntityId := do
  let s ← get
  set { s with nextId := s.nextId + 1 }
  pure ⟨s.nextId⟩

/-- Result of allocating an integer variable. The `id` is chosen opaquely by the
builder, but `eq` recovers the full record structure so callers can reason about
every field definitionally. -/
structure NewIntVar (domain : NonemptyDomain) (label : Option String) where
  id : EntityId
  var : IntVar
  eq : var = { id := id, domain := domain, label := label }

/-- Result of allocating a boolean variable, with `eq` recovering the record. -/
structure NewBoolVar (label : Option String) where
  id : EntityId
  var : BoolVar
  eq : var = { id := id, label := label }

/-- Result of allocating a fixed-size interval, with `eq` recovering the record. -/
structure NewFixedSizeInterval {b : Bounds}
    (start : LinearExpr b) (size : Int64) (size_nonneg : (0 : ℤ) ≤ size)
    (label : Option String) where
  id : EntityId
  var : FixedSizeIntervalVar
  eq : var =
    { id := id, startBounds := b, start := start, size := size,
      size_nonneg := size_nonneg, label := label }

/-- Result of allocating a constraint, with `eq` recovering the record. -/
structure NewConstraint (enforcement : Constraint.Enforcement)
    (variant : Constraint.Variant) (label : Option String) where
  id : EntityId
  constraint : Constraint
  eq : constraint =
    { id := id, label := label, enforcement := enforcement, variant := variant }

def Builder.newIntVar (domain : NonemptyDomain) (label : Option String := none) :
    Builder (NewIntVar domain label) := do
  let id ← Builder.freshId
  let v : IntVar := { id := id, domain := domain, label := label }
  modify fun s => { s with ints := s.ints.push v }
  pure { id := id, var := v, eq := rfl }

def Builder.newBoolVar (label : Option String := none) :
    Builder (NewBoolVar label) := do
  let id ← Builder.freshId
  let v : BoolVar := { id := id, label := label }
  modify fun s => { s with bools := s.bools.push v }
  pure { id := id, var := v, eq := rfl }

def Builder.newFixedSizeInterval {b : Bounds}
    (start : LinearExpr b) (size : Int64)
    (size_nonneg : (0 : ℤ) ≤ size := by decide)
    (label : Option String := none) :
    Builder (NewFixedSizeInterval start size size_nonneg label) := do
  let id ← Builder.freshId
  let v : FixedSizeIntervalVar := {
    id := id, startBounds := b, start := start, size := size,
    size_nonneg := size_nonneg, label := label
  }
  modify fun s => { s with intervals := s.intervals.push v }
  pure { id := id, var := v, eq := rfl }

def Builder.addConstraint (enforcement : Constraint.Enforcement)
    (variant : Constraint.Variant) (label : Option String := none) :
    Builder (NewConstraint enforcement variant label) := do
  let id ← Builder.freshId
  let c : Constraint := {
    id := id, label := label, enforcement := enforcement, variant := variant
  }
  modify fun s => { s with constraints := s.constraints.push c }
  pure { id := id, constraint := c, eq := rfl }

def Builder.setObjective (obj : Objective) : Builder Unit :=
  modify fun s => { s with objective := obj }

structure TruncDivEqResult
    (nb nt : Bounds) (numerator : LinearExpr nb)
    (divisor : Int64) where
  constraint : Constraint
  prop : ∀ val, (numerator.eval val) ∈ nb →
    (numerator.eval val) / divisor ∈ nt

/-- Truncating coarsening: allocate an auxiliary quotient and a division-equality
constraint. -/
def Builder.addTruncDivEq {nb : Bounds}
  (numerator : LinearExpr nb) (divisor : Int64) (hdiv : (0 : ℤ) < divisor) :=
  let nt := nb.divPosConst divisor hdiv
  have div_mem := nb.mem_const_div divisor hdiv
  let curried (target : LinearExpr nt) (label : Option String := none) :
      Builder (TruncDivEqResult nb nt numerator divisor) := do
    let c ← Builder.addConstraint .always
      (.div_eq ⟨nt, target⟩ ⟨nb, numerator⟩ divisor hdiv) label
    pure {
      constraint := c.constraint
      prop := fun valuation val_mem_nb =>
        let val := numerator.eval valuation
        by
          change (nb.mem val) at val_mem_nb
          dsimp [Interval.mem] at val_mem_nb
          dsimp [nt, Interval.divPosConst]
          constructor
          · apply Int.ediv_le_ediv
            · exact hdiv
            · change nb.left ≤ val
              exact val_mem_nb.1
          · simp only
            apply Int.ediv_le_ediv
            · exact hdiv
            · change val ≤ nb.right
              exact val_mem_nb.2
    }
  curried

/-- Truncating coarsening: allocate an auxiliary quotient variable and emit
positive-constant division equality. -/
def Builder.truncCoarsen {nb : Bounds}
    (numerator : LinearExpr nb) (divisor : Int64) (hdiv : (0 : ℤ) < divisor)
    (label : Option String := none) :
    Builder IntVar := do
  let quotDomain := NonemptyDomain.interval
    (nb.divPosConst divisor hdiv)
  let quot ← Builder.newIntVar quotDomain label
  let quotTarget : LinearExpr (Interval.divPosConst nb (↑divisor) hdiv) :=
    let quotExpr := LinearExpr.var quot.var
    by
      have var_eq := quot.eq
      rw [var_eq] at quotExpr
      simp only at quotExpr
      have quot_div_eq := NonemptyDomain.hull_interval_eq
        quotDomain rfl
      rw [quot_div_eq.symm]
      exact quotExpr
  let _ ← Builder.addTruncDivEq
    numerator divisor hdiv quotTarget
  pure quot.var

def Builder.newBucketInterval (start : IntVar) (label : Option String := none) :
    Builder FixedSizeIntervalVar := do
  let iv ← Builder.newFixedSizeInterval (LinearExpr.var start) (Int64.of 1) (by decide) label
  pure iv.var

def Builder.run (x : Builder α) : RawModel × α :=
  let (a, s) := StateT.run x {}
  (s, a)

def idsUniqueB {α : Type} [HasId α] (arr : Array α) : Bool :=
  (List.finRange arr.size).all fun i =>
    (List.finRange arr.size).all fun j =>
      decide (i = j ∨ HasId.id arr[i] ≠ HasId.id arr[j])

theorem idsUniqueB_iff {α : Type} [HasId α] (arr : Array α) :
    idsUniqueB arr = true ↔ idsUnique arr := by
  unfold idsUniqueB idsUnique
  rw [List.all_eq_true]
  constructor
  · intro h a b hab
    have hi := h a (List.mem_finRange a)
    rw [List.all_eq_true] at hi
    have hj := of_decide_eq_true (hi b (List.mem_finRange b))
    cases hj with
    | inl heq => exact (hab heq).elim
    | inr hne => exact hne
  · intro h i _hi
    rw [List.all_eq_true]
    intro j _hj
    refine decide_eq_true ?_
    by_cases heq : i = j
    · exact Or.inl heq
    · exact Or.inr (h i j heq)

def RawModel.refsOkB (m : RawModel) : Bool :=
  m.ints.all (fun v => decide (v.id.val < m.nextId)) &&
  m.bools.all (fun v => decide (v.id.val < m.nextId)) &&
  m.intervals.all (fun v => decide (v.id.val < m.nextId)) &&
  m.constraints.all (fun c => decide (c.id.val < m.nextId)) &&
  m.constraints.all (fun c =>
    c.intVars.all (fun v => decide (v.id ∈ m.declaredIntIds)) &&
    c.enforcement.boolVars.all (fun b => decide (b.id ∈ m.declaredBoolIds))) &&
  m.objective.intVars.all (fun e => decide (e.id ∈ m.declaredIntIds))

theorem RawModel.refsOkB_iff (m : RawModel) :
    m.refsOkB = true ↔ m.ReferencesWellFormed := by
  unfold RawModel.refsOkB RawModel.ReferencesWellFormed
  simp only [Bool.and_eq_true]
  rw [Array.all_eq_true', Array.all_eq_true', Array.all_eq_true', Array.all_eq_true',
    Array.all_eq_true']
  simp [Bool.and_eq_true, List.all_eq_true, and_assoc]

def RawModel.finalize (m : RawModel)
    (uniqueInts : idsUnique m.ints)
    (uniqueBools : idsUnique m.bools)
    (uniqueIntervals : idsUnique m.intervals)
    (uniqueConstraints : idsUnique m.constraints)
    (references : m.ReferencesWellFormed)
    (variantsWF : ∀ c ∈ m.constraints, c.variant.WellFormed)
    (presolve : ∀ c ∈ m.constraints, c.PassesPresolveSanityChecks) : Model :=
  {
    raw := m
    uniqueInts := uniqueInts
    uniqueBools := uniqueBools
    uniqueIntervals := uniqueIntervals
    uniqueConstraints := uniqueConstraints
    references := references
    variantsWF := variantsWF
    presolve := presolve
  }

def RawModel.wfB (m : RawModel) : Bool :=
  m.constraints.all (fun c => decide c.variant.WellFormed)

def RawModel.presolveB (m : RawModel) : Bool :=
  m.constraints.all (fun c => decide c.PassesPresolveSanityChecks)

def RawModel.finalize? (m : RawModel) : Option Model :=
  if h1 : idsUniqueB m.ints = true then
  if h2 : idsUniqueB m.bools = true then
  if h3 : idsUniqueB m.intervals = true then
  if h4 : idsUniqueB m.constraints = true then
  if h5 : m.refsOkB = true then
  if h6 : m.wfB = true then
  if h7 : m.presolveB = true then
    some (m.finalize
      ((idsUniqueB_iff m.ints).mp h1)
      ((idsUniqueB_iff m.bools).mp h2)
      ((idsUniqueB_iff m.intervals).mp h3)
      ((idsUniqueB_iff m.constraints).mp h4)
      ((RawModel.refsOkB_iff m).mp h5)
      (by
        unfold RawModel.wfB at h6
        intro c hc
        obtain ⟨i, hi, rfl⟩ := Array.getElem_of_mem hc
        exact of_decide_eq_true (Array.all_eq_true.mp h6 i hi))
      (by
        unfold RawModel.presolveB at h7
        intro c hc
        obtain ⟨i, hi, rfl⟩ := Array.getElem_of_mem hc
        exact of_decide_eq_true (Array.all_eq_true.mp h7 i hi)))
  else none else none else none else none else none else none else none

namespace LinearExpr

def meaning {bounds : Bounds} (expr : LinearExpr bounds) :
    Set ((EntityId → ℤ) × ℤ) :=
  {pair | pair.2 = expr.eval pair.1}

def possibleValues {bounds : Bounds} (expr : LinearExpr bounds) : Set ℤ :=
  {value | ∃ valuation : EntityId → ℤ, (valuation, value) ∈ expr.meaning}

theorem meaning_eq_iff {α β : Bounds}
    (a : LinearExpr α) (b : LinearExpr β) :
    @meaning α a = @meaning β b ↔ ∀ valuation : EntityId → ℤ,
      a.eval valuation = b.eval valuation := by
  constructor
  · intro h valuation
    have := Set.ext_iff.mp h (valuation, a.eval valuation)
    simpa [meaning] using this.mp rfl
  · intro h
    ext pair
    simp [meaning, h]

theorem meaning_double_neg {α : Bounds}
    (a : LinearExpr α)
    (h₁ : Int64.Nonoverflow (-α.right : ℤ) ∧ Int64.Nonoverflow (-α.left : ℤ))
    (h₂ : Int64.Nonoverflow (-(α.neg h₁).right : ℤ) ∧
      Int64.Nonoverflow (-(α.neg h₁).left : ℤ)) :
    meaning (LinearExpr.fromNeg (LinearExpr.fromNeg a h₁) h₂) = meaning a := by
  apply (meaning_eq_iff _ _).mpr
  intro valuation
  simp [LinearExpr.eval]

theorem meaning_add_sub_cancel {α β : Bounds}
    (a : LinearExpr α) (b : LinearExpr β)
    (hAdd : Int64.Nonoverflow ((α.left : ℤ) + β.left) ∧
      Int64.Nonoverflow ((α.right : ℤ) + β.right))
    (hSub : Int64.Nonoverflow (((α.add β hAdd).left : ℤ) - β.right) ∧
      Int64.Nonoverflow (((α.add β hAdd).right : ℤ) - β.left)) :
    meaning (LinearExpr.fromSub (LinearExpr.fromAdd a b hAdd) b hSub) =
      meaning a := by
  apply (meaning_eq_iff _ _).mpr
  intro valuation
  simp [LinearExpr.eval]

theorem meaning_sub_self {α : Bounds} (a : LinearExpr α)
    (hSub : Int64.Nonoverflow ((α.left : ℤ) - α.right) ∧
      Int64.Nonoverflow ((α.right : ℤ) - α.left)) :
    meaning (LinearExpr.fromSub a a hSub) =
      meaning (LinearExpr.fromConst (Subtype.mk 0 (by decide))) := by
  apply (meaning_eq_iff _ _).mpr
  intro
  simp [LinearExpr.eval]

end LinearExpr

structure Assignment where
  ints : List (EntityId × ℤ)
  bools : List (EntityId × Bool)

def Assignment.intVal (a : Assignment) (id : EntityId) : ℤ :=
  match a.ints.find? (fun p => p.1 == id) with
  | some p => p.2
  | none => 0

def Assignment.boolVal (a : Assignment) (id : EntityId) : Bool :=
  match a.bools.find? (fun p => p.1 == id) with
  | some p => p.2
  | none => false

def Assignment.valuation (a : Assignment) : EntityId → ℤ :=
  fun id => a.intVal id

def BoolLit.eval (a : Assignment) : BoolLit → Bool
  | .var v => a.boolVal v.id
  | .neg v => !a.boolVal v.id

def Constraint.Enforcement.active (a : Assignment) : Constraint.Enforcement → Bool
  | .always => true
  | .onlyWhenAll literals => literals.toList.all (fun l => l.eval a)

def BoundedLinearExpr.holdsB (expr : BoundedLinearExpr) (a : Assignment) : Bool :=
  let l := expr.left.eval a.valuation
  let r := expr.right.eval a.valuation
  match expr.rel with
  | .eq => decide (l = r)
  | .neq => decide (l ≠ r)
  | .gt => decide (l > r)
  | .gte => decide (l ≥ r)
  | .lt => decide (l < r)
  | .lte => decide (l ≤ r)

def BoundedLinearExpr.holds (expr : BoundedLinearExpr) (a : Assignment) : Prop :=
  expr.holdsB a = true

def Constraint.Variant.holdsB (v : Constraint.Variant) (a : Assignment) : Bool :=
  match v with
  | .bounded_linear expr => expr.holdsB a
  | .max_equality target exprs =>
    let tv := target.snd.eval a.valuation
    exprs.all (fun e => decide (e.snd.eval a.valuation ≤ tv)) &&
      (decide (exprs.size = 0) ||
        exprs.any (fun e => decide (e.snd.eval a.valuation = tv)))
  | .div_eq target numerator divisor _ =>
    decide (target.snd.eval a.valuation =
      Int.tdiv (numerator.snd.eval a.valuation) divisor.val)
  | allowed_assignments vars rows =>
    rows.any fun row =>
      decide (∀ i : Fin vars.size, a.intVal vars[i].id = row[i].val)
  | .cumulative items capacity =>
    let cap := capacity.snd.eval a.valuation
    let starts := items.toList.map fun it => it.interval.start.eval a.valuation
    starts.all fun t =>
      decide ((items.toList.foldl (fun acc it =>
        let s := it.interval.start.eval a.valuation
        let sz := it.interval.size.val
        let d := it.demand.snd.eval a.valuation
        if s ≤ t ∧ t < s + sz then acc + d else acc) 0) ≤ cap)
  | .bool_and terms => terms.toList.all (fun l => l.eval a)
  | .bool_or terms => terms.toList.any (fun l => l.eval a)
  | .implication src dst => (!src.eval a || dst.eval a)

def Constraint.Variant.holds (v : Constraint.Variant) (a : Assignment) : Prop :=
  v.holdsB a = true

def Constraint.Holds (c : Constraint) (a : Assignment) : Prop :=
  c.enforcement.active a = true → c.variant.holds a

def Constraint.holdsB (c : Constraint) (a : Assignment) : Bool :=
  !(c.enforcement.active a) || c.variant.holdsB a

theorem Constraint.holdsB_iff (c : Constraint) (a : Assignment) :
    c.holdsB a = true ↔ c.Holds a := by
  cases hact : c.enforcement.active a <;> simp [Constraint.holdsB, Constraint.Holds, hact,
    Constraint.Variant.holds]

def Model.domainOkB (model : Model) (a : Assignment) : Bool :=
  model.raw.ints.all (fun v => v.domain.domain.contains (a.intVal v.id)) &&
    model.raw.bools.all (fun v => (a.bools.find? (fun p => p.1 == v.id)).isSome)

def Model.domainOk (model : Model) (a : Assignment) : Prop :=
  model.domainOkB a = true

def Model.satisfiesB (model : Model) (a : Assignment) : Bool :=
  model.domainOkB a && model.raw.constraints.all (fun c => c.holdsB a)

def Model.Satisfies (model : Model) (a : Assignment) : Prop :=
  model.satisfiesB a = true

theorem Model.satisfiesB_iff (model : Model) (a : Assignment) :
    model.satisfiesB a = true ↔ model.Satisfies a := Iff.rfl

def Objective.eval (obj : Objective) (a : Assignment) : Option ℤ :=
  match obj with
  | Objective.none => Option.none
  | Objective.minimize e => Option.some (e.snd.eval a.valuation)
  | Objective.maximize e => Option.some (e.snd.eval a.valuation)

def Model.evalObjective (model : Model) (a : Assignment) : Option ℤ :=
  model.raw.objective.eval a

inductive SolveStatus where
  | unknown
  | infeasible
  | modelInvalid
  | feasible
  | optimal

inductive SolveResult (model : Model) where
  | infeasible
  | modelInvalid
  | unknown
  | feasible (asgn : Assignment) (sat : model.Satisfies asgn)
  | optimal (asgn : Assignment) (sat : model.Satisfies asgn)

private def Model.Python.domainExpr (d : Domain) : Python.Expr :=
  Python.Expr.call
    (Python.Expr.dot
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.cpModelLib)
        (Python.ValidName.mk "Domain" (by decide)))
      (Python.ValidName.mk "from_intervals" (by decide)))
    #[Python.Expr.lit (Python.Literal.array
      (d.intervals.toArray.map fun i =>
        Python.Expr.lit (Python.Literal.array #[
          Python.Expr.lit (Python.Literal.int i.left),
          Python.Expr.lit (Python.Literal.int i.right)])))]

private def Model.Python.boolVar (var : BoolVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.id.toPythonName) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "new_bool_var" (by decide)))
      #[Python.Expr.lit (Python.Literal.str (var.label.getD var.id.toPythonName.val))]
  ))

private def Model.Python.intVar (var : IntVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.id.toPythonName) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "new_int_var_from_domain" (by decide)))
      #[
        Model.Python.domainExpr var.domain.domain,
        Python.Expr.lit (Python.Literal.str (var.label.getD var.id.toPythonName.val))
      ]
  ))

private def Model.Python.fixedSizeIntervalVar
    (var : FixedSizeIntervalVar) : Python.Statement :=
  Python.Statement.exprLine (Python.Expr.assign (Python.Expr.id var.id.toPythonName) (
    Python.Expr.call
      (Python.Expr.dot
        (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "new_fixed_size_interval_var" (by decide)))
      #[
        (@LinearExpr.toPythonExpr var.startBounds var.start),
        Python.Expr.lit (Python.Literal.int var.size),
        Python.Expr.lit (Python.Literal.str (var.label.getD var.id.toPythonName.val))
      ]
  ))

private def Model.Python.constraint (cnst : Constraint) : Python.Statement :=
  let sigmaExprToPython (e : LinearExpr.WithBounds) : Python.Expr :=
    @LinearExpr.toPythonExpr e.fst e.snd
  let modelDot (attr : Python.ValidName) : Python.Expr :=
    Python.Expr.dot (Python.Expr.id Model.Python.Name.model) attr
  let constraint : Python.Expr := match cnst.variant with
    | .bounded_linear expr =>
      Python.Expr.call (modelDot (Python.ValidName.mk "add" (by decide)))
        #[expr.toPythonExpr]
    | .bool_and terms =>
      Python.Expr.call (modelDot (Python.ValidName.mk "add_bool_and" (by decide)))
        (terms.map (fun t => t.toPythonExpr))
    | .bool_or terms =>
      Python.Expr.call (modelDot (Python.ValidName.mk "add_bool_or" (by decide)))
        (terms.map (fun t => t.toPythonExpr))
    | .implication src dst =>
      Python.Expr.call (modelDot (Python.ValidName.mk "add_implication" (by decide)))
        #[src.toPythonExpr, dst.toPythonExpr]
    | .max_equality target exprs =>
      Python.Expr.call (modelDot (Python.ValidName.mk "add_max_equality" (by decide)))
        (#[sigmaExprToPython target] ++ exprs.map sigmaExprToPython)
    | .div_eq target numerator divisor _ =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_division_equality" (by decide)))
        #[sigmaExprToPython target, sigmaExprToPython numerator,
          Python.Expr.lit (Python.Literal.int divisor)]
    | .allowed_assignments vars rows =>
      Python.Expr.call
        (modelDot (Python.ValidName.mk "add_allowed_assignments" (by decide)))
        #[
          Python.Expr.lit (Python.Literal.array
            (vars.toArray.map (fun v => v.toPythonExpr))),
          Python.Expr.lit (Python.Literal.array
            (rows.map fun row =>
              Python.Expr.lit (Python.Literal.array
                (row.toArray.map fun n =>
                  Python.Expr.lit (Python.Literal.int n.val)))))
        ]
    | .cumulative items capacity =>
      Python.Expr.call (modelDot (Python.ValidName.mk "add_cumulative" (by decide)))
        #[
          Python.Expr.lit (Python.Literal.array
            (items.map fun it => it.interval.toPythonExpr)),
          Python.Expr.lit (Python.Literal.array
            (items.map fun it => sigmaExprToPython it.demand)),
          sigmaExprToPython capacity
        ]
  let labeled :=
    match cnst.label with
    | some lab =>
      Python.Expr.call
        (Python.Expr.dot constraint (Python.ValidName.mk "with_name" (by decide)))
        #[Python.Expr.lit (Python.Literal.str lab)]
    | none =>
      Python.Expr.call
        (Python.Expr.dot constraint (Python.ValidName.mk "with_name" (by decide)))
        #[Python.Expr.lit (Python.Literal.str cnst.id.toPythonName.val)]
  match cnst.enforcement with
  | Constraint.Enforcement.always => Python.Statement.exprLine labeled
  | Constraint.Enforcement.onlyWhenAll literals =>
    Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.dot labeled (Python.ValidName.mk "only_enforce_if" (by decide)))
      (literals.map (fun l : BoolLit => l.toPythonExpr)).toArray)

private def Model.Python.objective (obj : Objective) : Array Python.Statement :=
  match obj with
  | .none => #[]
  | .minimize e =>
    #[Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.dot (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "minimize" (by decide)))
      #[@LinearExpr.toPythonExpr e.fst e.snd])]
  | .maximize e =>
    #[Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.dot (Python.Expr.id Model.Python.Name.model)
        (Python.ValidName.mk "maximize" (by decide)))
      #[@LinearExpr.toPythonExpr e.fst e.snd])]

private def Model.Python.imports : Array Python.Statement := #[
  Python.Statement.importLine
    (Python.Import.fromForm
      #[Python.ValidName.mk "ortools" (by decide),
        Python.ValidName.mk "sat" (by decide),
        Python.ValidName.mk "python" (by decide)]
      #[Python.NameAs.unaliased Model.Python.Name.cpModelLib]),
  Python.Statement.importLine
    (Python.Import.basicForm #[Model.Python.Name.json] Option.none)
]

private def Model.Python.modelDef (model : Model) : Array Python.Statement :=
  let frontmatter : Array Python.Statement := #[
    Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.model)
      (Python.Expr.call
        (Python.Expr.dot (Python.Expr.id Model.Python.Name.cpModelLib)
          (Python.ValidName.mk "CpModel" (by decide))) #[]))
  ]
  frontmatter ++
    (model.raw.ints.map Model.Python.intVar) ++
    (model.raw.bools.map Model.Python.boolVar) ++
    (model.raw.intervals.map Model.Python.fixedSizeIntervalVar) ++
    (model.raw.constraints.map Model.Python.constraint) ++
    Model.Python.objective model.raw.objective

private def Model.Python.reportSolution (model : Model) : Array Python.Statement :=
  #[
    Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.cpsatSolver)
      (Python.Expr.call
        (Python.Expr.dot (Python.Expr.id Model.Python.Name.cpModelLib)
          (Python.ValidName.mk "CpSolver" (by decide))) #[])),
    Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.solveStatus)
      (Python.Expr.call
        (Python.Expr.dot (Python.Expr.id Model.Python.Name.cpsatSolver)
          (Python.ValidName.mk "solve" (by decide)))
        #[Python.Expr.id Model.Python.Name.model])),
    Python.Statement.exprLine (Python.Expr.assign
      (Python.Expr.id Model.Python.Name.output)
      (Python.Expr.lit (Python.Literal.dict #[
        (Prod.mk
          (Python.Expr.lit (Python.Literal.str Model.Python.Literals.ints))
          (Python.Expr.lit (Python.Literal.dict
            (model.raw.ints.map fun v =>
              (Python.Expr.lit (Python.Literal.str v.id.toPythonName.val),
                Python.Expr.call
                  (Python.Expr.dot (Python.Expr.id Model.Python.Name.cpsatSolver)
                    (Python.ValidName.mk "value" (by decide)))
                  #[v.toPythonExpr]))))),
        (Prod.mk
          (Python.Expr.lit (Python.Literal.str Model.Python.Literals.bools))
          (Python.Expr.lit (Python.Literal.dict
            (model.raw.bools.map fun v =>
              (Python.Expr.lit (Python.Literal.str v.id.toPythonName.val),
                Python.Expr.call
                  (Python.Expr.dot (Python.Expr.id Model.Python.Name.cpsatSolver)
                    (Python.ValidName.mk "value" (by decide)))
                  #[Python.Expr.id v.id.toPythonName]))))),
        (Prod.mk
          (Python.Expr.lit (Python.Literal.str Model.Python.Literals.status))
          (Python.Expr.call (Python.Expr.id (Python.ValidName.mk "str" (by decide)))
            #[Python.Expr.id Model.Python.Name.solveStatus])),
        (Prod.mk
          (Python.Expr.lit (Python.Literal.str Model.Python.Literals.solverObjective))
          (Python.Expr.dot (Python.Expr.id Model.Python.Name.cpsatSolver)
            (Python.ValidName.mk "objective_value" (by decide))))
      ]))),
    Python.Statement.exprLine (Python.Expr.call
      (Python.Expr.id Model.Python.Name.print)
      #[Python.Expr.call
        (Python.Expr.dot (Python.Expr.id Model.Python.Name.json)
          (Python.ValidName.mk "dumps" (by decide)))
        #[Python.Expr.id Model.Python.Name.output]])
  ]

def Model.script (model : Model) : Python.Script := {
  statements := Model.Python.imports ++ Model.Python.modelDef model ++
    Model.Python.reportSolution model
}

private def parseJsonInteger (json : Lean.Json) : Except String ℤ :=
  match json with
  | .num num =>
    if num.exponent = 0 then Except.ok num.mantissa
    else Except.error "Expected no decimal numbers."
  | _ => Except.error "Expected number type."

private def parseStatus (map : Std.TreeMap.Raw String Lean.Json compare) :
    Except String SolveStatus :=
  match map.get? Model.Python.Literals.status with
  | none => Except.error "Missing status."
  | some (.str statusStr) =>
    Except.ok (match statusStr with
      | "CpSolverStatus.INFEASIBLE" => SolveStatus.infeasible
      | "CpSolverStatus.MODEL_INVALID" => SolveStatus.modelInvalid
      | "CpSolverStatus.FEASIBLE" => SolveStatus.feasible
      | "CpSolverStatus.OPTIMAL" => SolveStatus.optimal
      | _ => SolveStatus.unknown)
  | some _ => Except.error "Expected string status."

private def parseNamedInts (model : Model)
    (map : Std.TreeMap.Raw String Lean.Json compare) :
    Except String (List (EntityId × ℤ)) :=
  match map.get? Model.Python.Literals.ints with
  | some (.obj obj) =>
    model.raw.ints.toList.mapM fun v =>
      match obj.get? v.id.toPythonName.val with
      | some j => parseJsonInteger j |>.map fun n => (v.id, n)
      | none => Except.error s!"Missing int {v.id.toPythonName.val}"
  | _ => Except.error "Missing ints object."

private def parseNamedBools (model : Model)
    (map : Std.TreeMap.Raw String Lean.Json compare) :
    Except String (List (EntityId × Bool)) :=
  match map.get? Model.Python.Literals.bools with
  | some (.obj obj) =>
    model.raw.bools.toList.mapM fun v =>
      match obj.get? v.id.toPythonName.val with
      | some j => parseJsonInteger j |>.map fun n => (v.id, n ≠ 0)
      | none => Except.error s!"Missing bool {v.id.toPythonName.val}"
  | _ => Except.error "Missing bools object."

def Model.parseScriptOutput (model : Model) (scriptOutput : String) :
    Except String (SolveStatus × Assignment) :=
  match Lean.Json.parse scriptOutput with
  | .error err => Except.error s!"Parse JSON: {err}"
  | .ok (.obj map) =>
    match parseStatus map, parseNamedInts model map, parseNamedBools model map with
    | .ok status, .ok ints, .ok bools =>
      Except.ok (status, { ints := ints, bools := bools })
    | .error err, _, _ => Except.error s!"status: {err}"
    | _, .error err, _ => Except.error s!"ints: {err}"
    | _, _, .error err => Except.error s!"bools: {err}"
  | .ok _ => Except.error "Expected JSON object."

def Model.interpret (model : Model) (status : SolveStatus) (asgn : Assignment) :
    Except String (SolveResult model) :=
  match status with
  | .infeasible => .ok .infeasible
  | .modelInvalid => .ok .modelInvalid
  | .unknown => .ok .unknown
  | .feasible =>
    if h : model.satisfiesB asgn = true then
      .ok (.feasible asgn ((Model.satisfiesB_iff model asgn).mp h))
    else
      .error "Returned assignment does not satisfy the model."
  | .optimal =>
    if h : model.satisfiesB asgn = true then
      .ok (.optimal asgn ((Model.satisfiesB_iff model asgn).mp h))
    else
      .error "Returned assignment does not satisfy the model."

def Model.solve (model : Model) (pythonRuntime : Python.Runtime) :
    IO (Except String (SolveResult model)) := do
  let out ← Python.Script.exec pythonRuntime model.script
  match Model.parseScriptOutput model out.stdout with
  | .error err => return .error err
  | .ok (status, asgn) => return model.interpret status asgn

end CpsatSolver
