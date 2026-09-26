import CpsatScheduler.CpsatSolver.Model
import CpsatScheduler.Task
import CpsatScheduler.TaskVars
import CpsatScheduler.ConstrainPrereq
import CpsatScheduler.ConstrainPacking
import CpsatScheduler.ConstrainPERT
import CpsatScheduler.Objective

open CpsatScheduler
open CpsatSolver
open Scipy

def atomic : UnitScale := UnitScale.mk 1
def unit2 : UnitScale := UnitScale.mk 2
def unit4 : UnitScale := UnitScale.mk 4

def unitSet : Finset UnitScale := { atomic, unit2, unit4 }

def units : CpsatScheduler.Units := CpsatScheduler.Units.of unitSet

def horizon : Horizon := Horizon.mk 0 12

def scales := Timescales.mk units horizon

@[simp] def taskA : Task scales :=
  Task.ofBucketRange scales { val := 1 } (Subtype.mk atomic (by decide))
    (kLo := 0) (kHi := 11)
    (label := Option.some "task_a")

@[simp] def taskB : Task scales :=
  Task.ofBucketRange scales { val := 2 } (Subtype.mk unit4 (by decide))
    (kHi := 1)
    (label := Option.some "task_b")

@[simp] def taskC : Task scales :=
  Task.ofBucketRange scales { val := 3 } (Subtype.mk unit4 (by decide))
    (kHi := 1)
    (label := Option.some "task_c")

def configA : Constraint.PERT.Config :=
  { opt := 1.0, exp := 2.0, pes := 5.0, cost := 1000.0, steps := 2, steps_nonzero := by decide }

def configB : Constraint.PERT.Config :=
  { opt := 2.0, exp := 4.0, pes := 9.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

def configC : Constraint.PERT.Config :=
  { opt := 1.0, exp := 3.0, pes := 8.0, cost := 1000.0, steps := 5, steps_nonzero := by decide }

def demoModel? (tableA : CostTable atomic) (tableB : CostTable unit4)
    (tableC : CostTable unit4) : Option Model :=
  let result := Builder.run do
    let a ← TaskVars.of taskA tableA.costHull
    let b ← TaskVars.of taskB tableB.costHull
    let c ← TaskVars.of taskC tableC.costHull
    let _ ← Builder.addConstraint .always
      (.bounded_linear
        (Constraint.prerequisite
          c.vars.startVar a.vars.startVar
          (by
            rw [a.start_domain]
            simp only [NonemptyDomain.hull, Domain.hullOf, TaskVars.startDomain, taskA,
              Task.ofBucketRange, NonemptyDomain.interval, Domain.interval, Interval.of,
              List.head_cons, List.getLast_singleton, zero_add, Int.reduceAdd]
            decide)))
      (some "task_c_before_a")
    let _ ← Constraint.packing #[ a.vars, b.vars, c.vars ]
    Constraint.PERT.costByTable a.vars tableA
    Constraint.PERT.costByTable b.vars tableB
    Constraint.PERT.costByTable c.vars tableC
    let _ ← Objective.minimizeCostSum #[ a.vars, b.vars, c.vars ]
    pure ()
  result.1.finalize?

def labeledInts (model : Model) (a : Assignment) : List (String × ℤ) :=
  a.ints.map fun (id, val) =>
    ((model.labelOf id).getD id.toPythonName.val, val)

def main : IO Unit := do
  let runtime : Python.Runtime := { path := ".venv/bin/python3" }
  let (⟨hA, hB, hC⟩, results) ← PertM.run runtime do
    let hA ← Constraint.PERT.requestCostTable configA
    let hB ← Constraint.PERT.requestCostTable configB
    let hC ← Constraint.PERT.requestCostTable configC
    pure (hA, hB, hC)
  let some tableA := hA.resolve results atomic | IO.println "table A failed"
  let some tableB := hB.resolve results unit4 | IO.println "table B failed"
  let some tableC := hC.resolve results unit4 | IO.println "table C failed"
  match demoModel? tableA tableB tableC with
  | none => IO.println "invalid model"
  | some model =>
    IO.println "solving..."
    match ← model.solve runtime with
    | .error err => IO.println s!"error: {err}"
    | .ok (.optimal asgn _) =>
      let assignments := (labeledInts model asgn).map fun p => s!"{p.1}={p.2}"
      IO.println s!"optimal: {assignments.foldl (s!"{·} {·}") ""}"
    | .ok (.feasible _ _) => IO.println "feasible"
    | .ok (.infeasible) => IO.println "infeasible"
    | .ok (.modelInvalid) => IO.println "model invalid"
    | .ok (.unknown) => IO.println "unknown"
