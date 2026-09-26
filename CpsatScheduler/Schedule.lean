import CpsatScheduler.Schedule.Mapping
import CpsatScheduler.Schedule.Event

set_option linter.style.nativeDecide false

namespace CpsatScheduler.Schedule

open CpsatScheduler

section Integration

private def hour4 : UnitScale := ⟨16, by decide, by decide⟩

private def demoScales : Timescales :=
  { units :=
      { set := {UnitScale.atomic, hour4}
        has_atomic := by decide
        divisibility := by decide }
    horizon :=
      { begin := 0, end_ := 384, begin_lt_end := by decide,
        begin_safe := by decide, end_safe := by decide } }

private def demoMap : ScheduleMap :=
  ScheduleMap.mk demoScales (epochSec := 0) (atomicSec := 900)

def demoTask : Task demoScales :=
  demoMap.task { val := 100 } (Subtype.mk UnitScale.atomic (by decide))
    (startAfterSec := 8 * 3600) (startBeforeSec := 12 * 3600)
    (label := some "study_block")

def demoEventAllocs : List Alloc :=
  demoMap.quantizeEventSec (startSec := 0) (endSec := 8 * 3600) hour4

example : (32 : ℤ) ∈ demoTask.startDomain.domain := by native_decide
example : (48 : ℤ) ∈ demoTask.startDomain.domain := by native_decide
example : demoEventAllocs = [⟨0, 16⟩, ⟨1, 16⟩] := by decide
example : totalAlloc demoEventAllocs = 32 := by decide

end Integration

end CpsatScheduler.Schedule
