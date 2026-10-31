import CpsatScheduler.Schedule.Mapping

example : sampleMap.scheduleTimeSec 900 .down = 1 := by native_decide
example : sampleMap.scheduleTimeSec 899 .down = 0 := by native_decide
example : sampleMap.scheduleTimeSec 899 .up = 1 := by native_decide
example : sampleMap.scheduleDurationSec 2700 .down = 3 := by native_decide
example : sampleMap.scheduleDurationSec 2701 .up = 4 := by native_decide
example : sampleMap.realTimeSec (sampleMap.scheduleTimeSec 950 .down) = 900 := by native_decide

example : (32 : ℤ) ∈ sampleTask.startDomain.domain := by native_decide
example : (40 : ℤ) ∈ sampleTask.startDomain.domain := by native_decide
example : (31 : ℤ) ∉ sampleTask.startDomain.domain := by native_decide
example : (41 : ℤ) ∉ sampleTask.startDomain.domain := by native_decide

example : (0 : ℤ) ∈ sampleTaskFull.startDomain.domain := by native_decide
example : (95 : ℤ) ∈ sampleTaskFull.startDomain.domain := by native_decide
example : (96 : ℤ) ∉ sampleTaskFull.startDomain.domain := by native_decide

example : (Horizon.ofSec 0 900 0 86400).begin = 0 := by native_decide
example : (Horizon.ofSec 0 900 0 86400).end_ = 96 := by native_decide
example : (Horizon.ofSec 0 900 901 3601).begin = 1 := by native_decide
example : (Horizon.ofSec 0 900 901 3601).end_ = 5 := by native_decide
