import CpsatScheduler.UnitScale

namespace CpsatScheduler.StandardUnits

open CpsatScheduler

def atomic : UnitScale := UnitScale.mk 1
abbrev fifteen_minute := atomic
def four_hour := UnitScale.mk (16*fifteen_minute.val)
def day := UnitScale.mk (24*four_hour.val)
def week := UnitScale.mk (7*day.val)
def two_week := UnitScale.mk (2*week.val)
def month := UnitScale.mk (4*week.val)
def quarter := UnitScale.mk (12*week.val)
def year := UnitScale.mk (4*quarter.val)
def two_year := UnitScale.mk (2*year.val)
def four_year := UnitScale.mk (4*year.val)
def eight_year := UnitScale.mk (8*year.val)
def sixteen_year := UnitScale.mk (16*year.val)
def thirtytwo_year := UnitScale.mk (32*year.val)
def sixtyfour_year := UnitScale.mk (64*year.val)

def units : CpsatScheduler.Units := CpsatScheduler.Units.of {
  atomic,
  four_hour,
  day,
  week,
  two_week,
  month,
  quarter,
  year,
  two_year,
  four_year,
  eight_year,
  sixteen_year,
  thirtytwo_year,
  sixtyfour_year
}

end CpsatScheduler.StandardUnits

