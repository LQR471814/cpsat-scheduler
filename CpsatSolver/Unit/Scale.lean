module

import CpsatSolver.Domain.Defs
public meta import CpsatSolver.Domain.Defs
public import CpsatScheduler.Util.Finset

import Mathlib.Order.Int.ConditionallyCompleteOrder
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Algebra.Order.Star.Int
import Mathlib.Algebra.Order.Ring.Star
import Mathlib.Data.Nat.Cast.Order.Ring
import Mathlib.Data.Int.Order.Basic
import Mathlib.Logic.Encodable.Basic
import Mathlib.Tactic.DeriveEncodable

public import Mathlib.Tactic

public section

namespace CpsatSolver.Unit

@[ext]
structure Scale where
  val : ℤ
  pos : 0 < val
  nonoverflow : CpsatSolver.Int64.Nonoverflow val
deriving DecidableEq

instance : Encodable Scale :=
  Encodable.ofLeftInjection
    (fun s => s.val)
    (fun v => if h : 0 < v ∧ CpsatSolver.Int64.Nonoverflow v then
      .some ⟨v, h.1, h.2⟩
    else
      .none)
    (fun d => by simp [d.pos, d.nonoverflow])

instance : Coe Scale ℕ where
  coe u := u.val.toNat

instance : Coe Scale ℤ where
  coe u := u.val

instance : LE Scale where
  le a b := a.val ≤ b.val

instance : LT Scale where
  lt a b := a.val < b.val

instance : Dvd Scale where
  dvd a b := a.val ∣ b.val

instance : DecidableLE Scale := by infer_instance

instance : DecidableLT Scale := by infer_instance

def Scale.of
  (val : ℤ)
  (pos : 0 < val := by native_decide)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow val := by native_decide) :
    Scale :=
  {
    val := val
    pos := pos
    nonoverflow := nonoverflow
  }

def Scale.atomic : Scale :=
  {
    val := 1
    pos := by native_decide
    nonoverflow := by native_decide
  }

theorem Scale.ratio_nonoverflow (u v : Scale) :
    CpsatSolver.Int64.Nonoverflow (u.val / v.val) := by
  have hu := u.nonoverflow
  have hnn : 0 ≤ (u.val / v.val) := by
    apply Int.ediv_nonneg
    · exact Int.le_of_lt u.pos
    · exact Int.le_of_lt v.pos
  have hle : (u.val / v.val) ≤ (u.val : ℤ) := by
    apply Int.ediv_le_self
    exact Int.le_of_lt u.pos
  constructor
  · have hmin : CpsatSolver.Int64.min ≤ 0 := by native_decide
    exact le_trans hmin hnn
  · exact le_trans hle hu.2

def Scale.exactRatio (u v : Scale) (_hv : v.val ∣ u.val) :
    CpsatSolver.Int64 :=
  ⟨u.val / v.val, Scale.ratio_nonoverflow u v⟩

instance : Coe Scale CpsatSolver.Int64 where
  coe v := Subtype.mk (v.val : ℤ) v.nonoverflow

private def scaleSetKey (s : Finset Scale) : s → ℤ :=
  fun x => x.val.val

private theorem scaleSetKey_inj (s : Finset Scale) :
    Function.Injective (scaleSetKey s) :=
  by
    unfold Function.Injective
    intro a1 a2 h
    ext
    exact h

def Scale.sort (s : Finset Scale) : List Scale :=
  Finset.sortByKey s (scaleSetKey s) (scaleSetKey_inj s)

theorem Scale.mem_sort {us : Finset Scale}
  (u : Scale) (h : u ∈ Scale.sort us) :
    u ∈ us :=
  us.mem_sortByKey.mpr h

end CpsatSolver.Unit

