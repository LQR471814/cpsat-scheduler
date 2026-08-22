import CpsatScheduler.Schedule.Mapping
import CpsatScheduler.CostTable

import Mathlib.Tactic.Ring
import Mathlib.Tactic.Linarith

namespace CpsatScheduler.Schedule

open CpsatScheduler

/-- A time allocation: `alloc` atomic units of the instance indexed `bucket`
(in `unit` coordinates). -/
structure Alloc where
  bucket : ℤ
  alloc : ℤ
deriving DecidableEq, Repr

/-- Overlap of event `[startA, endA)` with the instance `[instStart, instStart+unit)`. -/
def allocFor (startA endA unit instStart : ℤ) : ℤ :=
  let nextInst := instStart + unit
  let startIn := instStart < startA ∧ startA < nextInst
  let endIn := instStart < endA ∧ endA < nextInst
  if startIn ∧ endIn then endA - startA
  else if startIn then nextInst - startA
  else if endIn then endA - instStart
  else unit

def allocWalk (startA endA unit instStart : ℤ) : ℕ → List Alloc
  | 0 => []
  | n + 1 =>
    { bucket := instStart / unit, alloc := allocFor startA endA unit instStart }
      :: allocWalk startA endA unit (instStart + unit) n

/-- Quantize event `[startA, endA)` at timescale `unit`: one `Alloc` per touched
instance, in increasing bucket order. -/
def quantizeAtomic (startA endA unit : ℤ) : List Alloc :=
  let firstInst := startA - startA % unit
  let n := ((endA - firstInst) + unit - 1) / unit
  allocWalk startA endA unit firstInst n.toNat

def ScheduleMap.quantizeEventSec
    (m : ScheduleMap) (startSec endSec : ℤ) (unit : UnitScale) : List Alloc :=
  quantizeAtomic
    (m.scheduleTimeSec startSec .down)
    (m.scheduleTimeSec endSec .down)
    (unit.val : ℤ)

def ScheduleMap.quantizeEventDateTime
    (m : ScheduleMap) (start «end» : Std.Time.PlainDateTime) (unit : UnitScale) :
    List Alloc :=
  m.quantizeEventSec (plainDateTimeToSecUTC start) (plainDateTimeToSecUTC «end») unit

/-- The instance the event starts in, `⌊startA / unit⌋` (the spec's `Q(v)_t`). -/
def startBucket (startA unit : ℤ) : ℤ := startA / unit

def totalAlloc (as : List Alloc) : ℤ := (as.map (·.alloc)).sum

private theorem sub_mul_ediv_eq_emod (a b : ℤ) :
    a - b * (a / b) = a % b := by
  have h := Int.emod_add_ediv_mul a b
  have hcomm : a / b * b = b * (a / b) := mul_comm _ _
  linarith [h, hcomm]

/-- Guarantee (b): the event start is within one unit of its assigned instance. -/
theorem startDiff_lt_unit (startA unit : ℤ) (hunit : 0 < unit) :
    startA - unit * startBucket startA unit < unit := by
  unfold startBucket
  rw [sub_mul_ediv_eq_emod]
  exact Int.emod_lt_of_pos startA hunit

theorem startDiff_nonneg (startA unit : ℤ) (hunit : 0 < unit) :
    0 ≤ startA - unit * startBucket startA unit := by
  unfold startBucket
  rw [sub_mul_ediv_eq_emod]
  exact Int.emod_nonneg startA (ne_of_gt hunit)

/-- Guarantee (a): order-preservation — `startBucket` is monotone in the start. -/
theorem startBucket_monotone {s₁ s₂ unit : ℤ} (hunit : 0 < unit) (h : s₁ ≤ s₂) :
    startBucket s₁ unit ≤ startBucket s₂ unit :=
  Int.ediv_le_ediv hunit h

private theorem allocFor_start_irrel
    (s₁ s₂ endA unit instStart : ℤ)
    (h₁ : s₁ ≤ instStart) (h₂ : s₂ ≤ instStart) :
    allocFor s₁ endA unit instStart = allocFor s₂ endA unit instStart := by
  unfold allocFor
  have hne₁ : ¬ (instStart < s₁ ∧ s₁ < instStart + unit) := fun h => absurd h.1 (by omega)
  have hne₂ : ¬ (instStart < s₂ ∧ s₂ < instStart + unit) := fun h => absurd h.1 (by omega)
  simp only [hne₁, hne₂, false_and, ite_false]

private theorem allocFor_head
    (startA endA unit cur : ℤ)
    (hcurle : cur ≤ startA) (hstartlt : startA < cur + unit) (hlt0 : cur < endA) :
    allocFor startA endA unit cur
      = (if endA < cur + unit then endA else cur + unit) - startA := by
  unfold allocFor
  by_cases hs : cur < startA <;> by_cases he : endA < cur + unit <;>
    simp only [hs, he, hstartlt, hlt0, and_true, and_self,
      ite_true, ite_false, and_false] <;>
    omega

private theorem allocWalk_start_irrel
    (s₁ s₂ endA unit : ℤ) (hunit : 0 < unit) :
    ∀ (k : ℕ) (base : ℤ), s₁ ≤ base → s₂ ≤ base →
      allocWalk s₁ endA unit base k = allocWalk s₂ endA unit base k := by
  intro k
  induction k with
  | zero => intro base _ _; simp only [allocWalk]
  | succ j jh =>
    intro base h1 h2
    simp only [allocWalk]
    rw [allocFor_start_irrel _ _ _ _ _ h1 h2, jh (base + unit) (by omega) (by omega)]

private theorem totalAlloc_allocWalk
    (endA unit : ℤ) (hunit : 0 < unit) :
    ∀ (n : ℕ) (cur startA : ℤ),
      cur ≤ startA → startA < cur + unit → startA < endA →
      cur + ((n : ℤ) - 1) * unit < endA →
      endA ≤ cur + (n : ℤ) * unit →
      totalAlloc (allocWalk startA endA unit cur n) = endA - startA := by
  intro n
  induction n with
  | zero =>
    intro cur startA _ _ _ _ hle
    simp only [Nat.cast_zero, zero_mul, add_zero] at hle
    exfalso; omega
  | succ k ih =>
    intro cur startA hcurle hstartlt hne hlt hle
    simp only [allocWalk, totalAlloc, List.map_cons, List.sum_cons]
    by_cases hk : k = 0
    · subst hk
      simp only [allocWalk, List.map_nil, List.sum_nil, add_zero]
      have hlt0 : cur < endA := by push_cast at hlt; nlinarith [hlt, hunit]
      rw [allocFor_head startA endA unit cur hcurle hstartlt hlt0]
      split_ifs <;> omega
    · have hkpos : 0 < k := Nat.pos_of_ne_zero hk
      have hk1 : (1 : ℤ) ≤ (k : ℤ) := by exact_mod_cast hkpos
      have hend_gt : cur + unit < endA := by push_cast at hlt; nlinarith [hlt, hunit, hk1]
      have hlt0 : cur < endA := by nlinarith [hend_gt, hunit]
      have hhead : allocFor startA endA unit cur = cur + unit - startA := by
        rw [allocFor_head startA endA unit cur hcurle hstartlt hlt0]
        have hin : ¬ endA < cur + unit := by omega
        simp only [hin, ite_false]
      have htail :
          totalAlloc (allocWalk startA endA unit (cur + unit) k) = endA - (cur + unit) := by
        rw [show allocWalk startA endA unit (cur + unit) k
              = allocWalk (cur + unit) endA unit (cur + unit) k from
            allocWalk_start_irrel startA (cur + unit) endA unit hunit k (cur + unit)
              (by omega) (le_refl _)]
        exact ih (cur + unit) (cur + unit) (le_refl _)
          (by nlinarith [hunit]) hend_gt
          (by push_cast at hlt ⊢; nlinarith [hlt, hunit])
          (by push_cast at hle ⊢; nlinarith [hle, hunit])
      simp only [totalAlloc] at htail
      rw [hhead, htail]; omega

/-- Guarantee (c): allocations tile the event exactly — total equals the event
length. -/
theorem totalAlloc_quantizeAtomic
    (startA endA unit : ℤ) (hunit : 0 < unit) (hne : startA < endA) :
    totalAlloc (quantizeAtomic startA endA unit) = endA - startA := by
  unfold quantizeAtomic
  set cur := startA - startA % unit with hcur
  have hmod_nn : 0 ≤ startA % unit := Int.emod_nonneg startA (ne_of_gt hunit)
  have hmod_lt : startA % unit < unit := Int.emod_lt_of_pos startA hunit
  have hcurle : cur ≤ startA := by rw [hcur]; omega
  have hstartlt : startA < cur + unit := by rw [hcur]; omega
  set n := ((endA - cur) + unit - 1) / unit with hn
  have hspan_pos : 0 < endA - cur := by omega
  have hn_pos : 0 < n := by
    rw [hn]
    have : (1 : ℤ) ≤ (endA - cur + unit - 1) / unit := by
      rw [Int.le_ediv_iff_mul_le hunit]; omega
    omega
  set nN := n.toNat with hnN
  have hnN_cast : (nN : ℤ) = n := Int.toNat_of_nonneg (le_of_lt hn_pos)
  have hupper : endA ≤ cur + (nN : ℤ) * unit := by
    rw [hnN_cast, hn]
    have := Int.lt_ediv_add_one_mul_self (endA - cur + unit - 1) hunit
    nlinarith [this, hunit]
  have hlower : cur + ((nN : ℤ) - 1) * unit < endA := by
    rw [hnN_cast, hn]
    have := Int.ediv_mul_le (endA - cur + unit - 1) (ne_of_gt hunit)
    nlinarith [this, hunit]
  exact totalAlloc_allocWalk endA unit hunit nN cur startA hcurle hstartlt hne hlower hupper

section Test

example : quantizeAtomic 198 232 16 = [⟨12, 10⟩, ⟨13, 16⟩, ⟨14, 8⟩] := by decide
example : quantizeAtomic 234 235 16 = [⟨14, 1⟩] := by decide
example : quantizeAtomic 236 254 16 = [⟨14, 4⟩, ⟨15, 14⟩] := by decide
example : totalAlloc (quantizeAtomic 198 232 16) = 232 - 198 := by decide
example : (198 : ℤ) - 16 * startBucket 198 16 < 16 := by decide
example : startBucket 198 16 ≤ startBucket 236 16 := by decide

end Test

end CpsatScheduler.Schedule
