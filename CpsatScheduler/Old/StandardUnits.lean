import CpsatScheduler.CpsatSolver.Unit.Set

namespace CpsatScheduler.StandardUnits

open CpsatSolver

def atomic : Unit.Scale := Unit.Scale.of 1
abbrev fifteen_minute := atomic
def four_hour := Unit.Scale.of (16*fifteen_minute.val)
def day := Unit.Scale.of (24*four_hour.val)
def week := Unit.Scale.of (7*day.val)
def two_week := Unit.Scale.of (2*week.val)
def month := Unit.Scale.of (4*week.val)
def quarter := Unit.Scale.of (12*week.val)
def year := Unit.Scale.of (4*quarter.val)
def two_year := Unit.Scale.of (2*year.val)
def four_year := Unit.Scale.of (4*year.val)
def eight_year := Unit.Scale.of (8*year.val)
def sixteen_year := Unit.Scale.of (16*year.val)
def thirtytwo_year := Unit.Scale.of (32*year.val)
def sixtyfour_year := Unit.Scale.of (64*year.val)

def units : Unit.Set := {
  fs := {
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
  has_atomic := by native_decide
  divisibility := by native_decide
}

end CpsatScheduler.StandardUnits

