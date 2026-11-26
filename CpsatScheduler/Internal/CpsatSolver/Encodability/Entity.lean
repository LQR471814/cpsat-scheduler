module

public import CpsatScheduler.Internal.CpsatSolver.Encodability.Cpsat

import Mathlib.Logic.Equiv.Finset

public section

namespace CpsatSolver

class CpsatType (α : Type) [HasRepr α] where
  type : ℕ

/-- Encode a tagged value as a `List ℕ`: the type tag as a leading element,
    followed by the value's `HasRepr` representation. -/
def CpsatType.encode [HasRepr α] [CpsatType α] (a : α) : ReprType :=
  CpsatType.type α :: HasRepr.toRepr a

instance : CpsatType IntVar := { type := 0 }
instance : CpsatType BoolVar := { type := 1 }
instance : CpsatType BoolLit := { type := 2 }
instance : CpsatType (UnitAwareIntVar S) := { type := 3 }
instance : CpsatType LinearExpr.Raw := { type := 4 }
instance : CpsatType LinearExpr := { type := 5 }
instance : CpsatType FixedSizeIntervalVar := { type := 6 }
instance : CpsatType BoundedLinearExpr.Rel := { type := 7 }
instance : CpsatType BoundedLinearExpr := { type := 8 }
instance : CpsatType Constraint.CumulativeItem := { type := 9 }
instance : CpsatType Constraint.Enforcement := { type := 10 }
instance : CpsatType Constraint.Variant := { type := 11 }
instance : CpsatType Constraint := { type := 12 }
instance : CpsatType Objective := { type := 13 }

structure CpsatID where
  private mk ::
  vals : Finset ReprType
deriving DecidableEq

/-- Deterministic `List ℕ` encoding of an identity: sort the (finite) set of
    per-component reprs into their canonical order (`List ℕ` has a
    `LinearOrder`) and chunk-encode the result. Determinism follows from the
    canonical sort; set-equality of `vals` yields identical encodings. -/
def CpsatID.encode (e : CpsatID) : ReprType :=
  encodeChunks (e.vals.sort (· ≤ ·))

def CpsatID.nil : CpsatID :=
  ⟨{}⟩

def CpsatID.singleton [HasRepr α] [CpsatType α]
  (v : α) : CpsatID :=
  ⟨{ (CpsatType.encode v) }⟩

def CpsatID.of [HasRepr α] [CpsatType α]
  (self : α) (others : Finset CpsatID) :
    CpsatID :=
  let mergeWith := others.image (fun x => x.encode)
  ⟨mergeWith ∪ { (CpsatType.encode self) }⟩

structure Entity (α : Type) [HasRepr α] where
  id : CpsatID
  val : α
deriving DecidableEq

instance [HasRepr α] : Coe (Entity α) α where
  coe a := a.val

def Entity.of [HasRepr α] [CpsatType α]
  (a : α) (others : Finset CpsatID) : Entity α :=
  {
    id := .of a others
    val := a
  }

def Entity.encode [HasRepr α] [CpsatType α]
  (e : Entity α) : ReprType :=
  (CpsatID.of e.val {e.id}).encode

end CpsatSolver
