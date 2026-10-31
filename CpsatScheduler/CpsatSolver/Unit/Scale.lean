import CpsatScheduler.CpsatSolver.Domain.Defs
import CpsatScheduler.Util.Finset

import Mathlib.Data.Int.ConditionallyCompleteOrder
import Mathlib.Data.Int.Star
import Mathlib.Order.ConditionallyCompleteLattice.Basic
import Mathlib.Algebra.Order.Ring.Star
import Mathlib.Data.Nat.Cast.Order.Ring

namespace CpsatSolver.Unit

@[ext]
structure Scale where
  val : ℕ
  pos : 0 < val
  nonoverflow : CpsatSolver.Int64.Nonoverflow (val : ℤ)
deriving DecidableEq

instance : Coe Scale ℕ where
  coe u := u.val

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
  (val : ℕ)
  (pos : 0 < val := by native_decide)
  (nonoverflow : CpsatSolver.Int64.Nonoverflow (val : ℤ) := by native_decide) :
    Scale :=
  {
    val := val
    pos := pos
    nonoverflow := nonoverflow
  }

def Scale.atomic : Scale :=
  {
    val := 1
    pos := Nat.succ_pos 0
    nonoverflow := by native_decide
  }

theorem Scale.ratio_nonoverflow (u v : Scale) :
    CpsatSolver.Int64.Nonoverflow ((u.val / v.val : ℕ) : ℤ) := by
  have hu := u.nonoverflow
  have hnn : (0 : ℤ) ≤ ((u.val / v.val : ℕ) : ℤ) := Nat.cast_nonneg _
  have hle : ((u.val / v.val : ℕ) : ℤ) ≤ (u.val : ℤ) := by
    exact_mod_cast Nat.div_le_self u.val v.val
  constructor
  · have hmin : CpsatSolver.Int64.min ≤ 0 := by native_decide
    exact le_trans hmin hnn
  · exact le_trans hle hu.2

def Scale.exactRatio (u v : Scale) (_hv : v.val ∣ u.val) :
    CpsatSolver.Int64 :=
  ⟨u.val / v.val, Scale.ratio_nonoverflow u v⟩

instance : Coe Scale CpsatSolver.Int64 where
  coe v := Subtype.mk (v.val : ℤ) v.nonoverflow

private def scaleSetKey (s : Finset Scale) : s → ℕ :=
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

