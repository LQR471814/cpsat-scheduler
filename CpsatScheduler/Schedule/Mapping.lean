import CpsatScheduler.Task

import Std.Time

set_option linter.style.nativeDecide false

namespace CpsatScheduler.Schedule

open CpsatScheduler

inductive Rounding where
  | up
  | down
deriving DecidableEq, Repr

structure ScheduleMap where
  mkRaw ::
  scales : Timescales
  epochSec : ℤ
  atomicSec : ℤ
  atomic_pos : 0 < atomicSec

@[simp] def ScheduleMap.mk
    (scales : Timescales) (epochSec atomicSec : ℤ)
    (atomic_pos : 0 < atomicSec := by decide) : ScheduleMap :=
  ⟨scales, epochSec, atomicSec, atomic_pos⟩

def ScheduleMap.scheduleDurationSec
    (m : ScheduleMap) (secs : ℤ) : Rounding → ℤ
  | .down => secs / m.atomicSec
  | .up => (secs + m.atomicSec - 1) / m.atomicSec

def ScheduleMap.scheduleTimeSec (m : ScheduleMap) (tsSec : ℤ) (r : Rounding) : ℤ :=
  m.scheduleDurationSec (tsSec - m.epochSec) r

def ScheduleMap.realDurationSec (m : ScheduleMap) (k : ℤ) : ℤ :=
  k * m.atomicSec

def ScheduleMap.realTimeSec (m : ScheduleMap) (k : ℤ) : ℤ :=
  m.epochSec + m.realDurationSec k

theorem ScheduleMap.scheduleDurationSec_down_nonneg
    (m : ScheduleMap) {secs : ℤ} (h : 0 ≤ secs) :
    0 ≤ m.scheduleDurationSec secs .down :=
  Int.ediv_nonneg h (le_of_lt m.atomic_pos)

theorem ScheduleMap.scheduleTimeSec_nonneg
    (m : ScheduleMap) {tsSec : ℤ} (h : m.epochSec ≤ tsSec) :
    0 ≤ m.scheduleTimeSec tsSec .down :=
  m.scheduleDurationSec_down_nonneg (sub_nonneg.mpr h)

theorem ScheduleMap.scheduleDurationSec_down_monotone
    (m : ScheduleMap) {a b : ℤ} (hab : a ≤ b) :
    m.scheduleDurationSec a .down ≤ m.scheduleDurationSec b .down :=
  Int.ediv_le_ediv m.atomic_pos hab

theorem ScheduleMap.scheduleTimeSec_down_monotone
    (m : ScheduleMap) {a b : ℤ} (hab : a ≤ b) :
    m.scheduleTimeSec a .down ≤ m.scheduleTimeSec b .down :=
  m.scheduleDurationSec_down_monotone (by linarith)

theorem ScheduleMap.floor_le_ceil (m : ScheduleMap) (secs : ℤ) :
    m.scheduleDurationSec secs .down ≤ m.scheduleDurationSec secs .up :=
  Int.ediv_le_ediv m.atomic_pos (by have := m.atomic_pos; linarith)

theorem ScheduleMap.realTimeSec_scheduleTimeSec_le
    (m : ScheduleMap) (tsSec : ℤ) :
    m.realTimeSec (m.scheduleTimeSec tsSec .down) ≤ tsSec := by
  simp only [ScheduleMap.realTimeSec, ScheduleMap.realDurationSec,
    ScheduleMap.scheduleTimeSec, ScheduleMap.scheduleDurationSec]
  have := Int.ediv_mul_le (tsSec - m.epochSec) (ne_of_gt m.atomic_pos)
  linarith

theorem ScheduleMap.lt_realTimeSec_succ
    (m : ScheduleMap) (tsSec : ℤ) :
    tsSec < m.realTimeSec (m.scheduleTimeSec tsSec .down) + m.atomicSec := by
  simp only [ScheduleMap.realTimeSec, ScheduleMap.realDurationSec,
    ScheduleMap.scheduleTimeSec, ScheduleMap.scheduleDurationSec]
  have := Int.lt_ediv_add_one_mul_self (tsSec - m.epochSec) m.atomic_pos
  nlinarith [this, m.atomic_pos]

def plainDateTimeToSecUTC (dt : Std.Time.PlainDateTime) : ℤ :=
  (dt.toWallTime.toTimestamp Std.Time.TimeZone.Offset.zero).toSecondsSinceUnixEpoch.val

def ScheduleMap.ofDateTime
    (scales : Timescales)
    (epoch : Std.Time.PlainDateTime) (atomicSec : ℤ)
    (atomic_pos : 0 < atomicSec := by decide) : ScheduleMap :=
  ⟨scales, plainDateTimeToSecUTC epoch, atomicSec, atomic_pos⟩

def ScheduleMap.scheduleDateTime
    (m : ScheduleMap) (dt : Std.Time.PlainDateTime) (r : Rounding) : ℤ :=
  m.scheduleTimeSec (plainDateTimeToSecUTC dt) r

def ScheduleMap.realDateTime (m : ScheduleMap) (k : ℤ) : Std.Time.PlainDateTime :=
  let ts := Std.Time.Timestamp.ofSecondsSinceUnixEpoch
    (Std.Time.Second.Offset.ofInt (m.realTimeSec k))
  Std.Time.PlainDateTime.ofWallTime (ts.toWallTime Std.Time.TimeZone.Offset.zero)

def ScheduleMap.realDateTimeOfBucket
    (m : ScheduleMap) (unit : UnitScale) (k : ℤ) : Std.Time.PlainDateTime :=
  m.realDateTime (k * (unit.val : ℤ))

def ScheduleMap.bucketDateString
    (m : ScheduleMap) (unit : UnitScale) (k : ℤ) : String :=
  (m.realDateTimeOfBucket unit k).toLeanDateTimeString

def ScheduleMap.scheduleTimeBucket
    (m : ScheduleMap) (tsSec : ℤ) (unit : UnitScale) (r : Rounding) : ℤ :=
  m.scheduleTimeSec tsSec r / (unit.val : ℤ)

/-- Declare a task from real second-offset start bounds: `startAfter` rounds up,
`startBefore` rounds down, giving the inclusive start-bucket range `[kLo, kHi]`. -/
@[simp] def ScheduleMap.task
    (m : ScheduleMap)
    (id : TaskId)
    (unit : { u : UnitScale // u ∈ m.scales.units.set })
    (startAfterSec : ℤ)
    (startBeforeSec : ℤ)
    (kLo : ℤ := m.scheduleTimeBucket startAfterSec unit.val .up)
    (kHi : ℤ := m.scheduleTimeBucket startBeforeSec unit.val .down)
    (hle : kLo ≤ kHi := by decide)
    (hbegin : (m.scales.horizon.begin : ℤ) ≤ kLo * unit.val.val := by decide)
    (hend : (kHi + 1) * unit.val.val ≤ m.scales.horizon.end_ := by decide)
    (label : Option String := none) :
    Task m.scales :=
  Task.ofBucketRange m.scales id unit kLo kHi hle hbegin hend label

section Test

private def sampleScales : Timescales :=
  { units :=
      { set := {UnitScale.atomic}
        has_atomic := by decide
        divisibility := by decide }
    horizon :=
      { begin := 0, end_ := 96, begin_lt_end := by decide,
        begin_safe := by decide, end_safe := by decide } }

private def sampleMap : ScheduleMap :=
  ScheduleMap.mk sampleScales (epochSec := 0) (atomicSec := 900)

example : sampleMap.scheduleTimeSec 900 .down = 1 := by decide
example : sampleMap.scheduleTimeSec 899 .down = 0 := by decide
example : sampleMap.scheduleTimeSec 899 .up = 1 := by decide
example : sampleMap.scheduleDurationSec 2700 .down = 3 := by decide
example : sampleMap.scheduleDurationSec 2701 .up = 4 := by decide
example : sampleMap.realTimeSec (sampleMap.scheduleTimeSec 950 .down) = 900 := by decide

def sampleTask : Task sampleScales :=
  sampleMap.task { val := 1 } (Subtype.mk UnitScale.atomic (by decide))
    (startAfterSec := 8 * 3600) (startBeforeSec := 10 * 3600)
    (label := some "morning_task")

example : (32 : ℤ) ∈ sampleTask.startDomain.domain := by native_decide
example : (40 : ℤ) ∈ sampleTask.startDomain.domain := by native_decide
example : (31 : ℤ) ∉ sampleTask.startDomain.domain := by native_decide
example : (41 : ℤ) ∉ sampleTask.startDomain.domain := by native_decide

end Test

end CpsatScheduler.Schedule
