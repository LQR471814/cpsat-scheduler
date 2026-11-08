import CpsatScheduler.Schedule.Defs

namespace CpsatScheduler.Schedule

open CpsatScheduler
open CpsatSolver

private abbrev unixInt (t : Std.Time.Timestamp) :=
  t.toNanosecondsSinceUnixEpoch.toInt

private abbrev intDur (d : Std.Time.Duration) :=
  d.toNanoseconds.toInt

theorem Time.nonoverflow (t : Time) :
    CpsatSolver.Int64.Nonoverflow t.val := by
  unfold Int64.Nonoverflow
  constructor
  · have h1 := t.nonneg
    have h2 : Int64.min ≤ 0 := by native_decide
    exact Int.le_trans h2 h1
  · exact t.le_max

def Config.NonnegStandardTime (c : Config)
    (t : Std.Time.Timestamp) : Prop :=
  (unixInt t) - (unixInt c.reference) ≥ 0

def Config.ScheduleTimeLeMax (c : Config)
      (t : Std.Time.Timestamp) (u : Unit.Scale) : Prop :=
  ((unixInt t) - (unixInt c.reference)) /
    (u.val * (intDur c.atomicDur)) ≤ Int64.max

def Config.toScheduleTime
  (c : Config)
  (t : Std.Time.Timestamp)
  (u : Unit.Scale)
  (nonneg_since_ref : c.NonnegStandardTime t := by native_decide)
  (div_safe : c.ScheduleTimeLeMax t u := by native_decide) :
    Time :=
  let dur_since_ref := (unixInt t) - (unixInt c.reference)
  let blocksize := u.val * (intDur c.atomicDur)
  have blocksize_pos : blocksize > 0 := by
    unfold blocksize
    have h1 : intDur c.atomicDur > 0 := c.atomic_dur_pos
    have h2 : (0 : ℤ) < u.val := by exact_mod_cast u.pos
    exact mul_pos h2 h1
  let schedule_time := dur_since_ref / blocksize
  have nonneg : schedule_time ≥ 0 := by
    unfold schedule_time
    apply Int.ediv_nonneg
    · exact nonneg_since_ref
    · exact Int.le_of_lt blocksize_pos
  {
    val := schedule_time
    unit := u
    nonneg := nonneg
    le_max := div_safe
  }

def Config.toStandardTime (c : Config) (t : Time) :
    Std.Time.Timestamp :=
  c.reference + t.val * t.unit.val * c.atomicDur

def Config.ScheduleDurationLeMax (c : Config)
    (d : Std.Time.Duration) (u : Unit.Scale) : Prop :=
  (intDur d) / (intDur c.atomicDur) / u.val ≤
    CpsatSolver.Int64.max

def Config.toScheduleDuration (c : Config) (d : Std.Time.Duration)
  (u : Unit.Scale)
  (nonneg_dur : (intDur d) ≥ 0 := by native_decide)
  (div_safe : c.ScheduleDurationLeMax d u := by native_decide) :
    Duration :=
  let units := (intDur d) / (intDur c.atomicDur) / u.val
  {
    val := units
    unit := u
    nonneg := by
      unfold units
      apply Int.ediv_nonneg
      · apply Int.ediv_nonneg
        · exact nonneg_dur
        · exact Int.le_of_lt c.atomic_dur_pos
      · exact Int.le_of_lt u.pos
    le_max := div_safe
  }

def Config.toStandardDuration (c : Config) (d : Duration) :
    Std.Time.Duration :=
  d.val * d.unit.val * c.atomicDur

theorem Duration.intDur_lt_of_lt {a b : Std.Time.Duration} (h : a > b) :
    intDur a > intDur b :=
  h

theorem Duration.intDur_lt_of_le {a b : Std.Time.Duration} (h : a ≤ b) :
    intDur a ≤ intDur b :=
  h

theorem Timestamp.unixInt_lt_of_lt {a b : Std.Time.Timestamp} (h : a > b) :
    unixInt a > unixInt b :=
  h

theorem Timestamp.unixInt_lt_of_le {a b : Std.Time.Timestamp} (h : a ≤ b) :
    unixInt a ≤ unixInt b :=
  h

theorem Config.toScheduleTime_val_mono
  (c : Config) (u : Unit.Scale) {a b : Std.Time.Timestamp}
  (hab : a ≥ b)
  {na nb da db} :
    (c.toScheduleTime a u na da).val ≥ (c.toScheduleTime b u nb db).val := by
  apply Int.ediv_le_ediv
  · have h1 : intDur c.atomicDur > 0 := c.atomic_dur_pos
    have h2 : (0 : ℤ) < u.val := by exact_mod_cast u.pos
    exact mul_pos h2 h1
  · exact Int.sub_le_sub_right (Timestamp.unixInt_lt_of_le hab) _

theorem Config.toScheduleTime_val_anti
  (c : Config) (u : Unit.Scale) {a b : Std.Time.Timestamp}
  (hab : a ≤ b)
  {na nb da db} :
    (c.toScheduleTime a u na da).val ≤ (c.toScheduleTime b u nb db).val :=
  c.toScheduleTime_val_mono u hab

theorem Config.toScheduleDuration_val_mono
  (c : Config) (u : Unit.Scale) {a b : Std.Time.Duration}
  (hab : a ≥ b)
  {na nb da db} :
    (c.toScheduleDuration a u na da).val ≥ (c.toScheduleDuration b u nb db).val := by
  apply Int.ediv_le_ediv (by exact_mod_cast u.pos)
  apply Int.ediv_le_ediv c.atomic_dur_pos
  exact Duration.intDur_lt_of_le hab

theorem Config.toScheduleDuration_val_anti
  (c : Config) (u : Unit.Scale) {a b : Std.Time.Duration}
  (hab : a ≤ b)
  {na nb da db} :
    (c.toScheduleDuration a u na da).val ≤ (c.toScheduleDuration b u nb db).val :=
  c.toScheduleDuration_val_mono u hab

end CpsatScheduler.Schedule
