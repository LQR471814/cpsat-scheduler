from cpsatmodel import atomic_unit
from sys import maxsize

# atomic timescale
minute_15 = atomic_unit(1)
hour_4 = 4 * 4 * minute_15
day = 6 * hour_4
week = 7 * day
month = 4 * week
quarter = 3 * month
year = 4 * quarter
year_2 = 2 * year
year_4 = 2 * year_2
year_8 = 2 * year_4
year_16 = 2 * year_8
year_32 = 2 * year_16
year_64 = 2 * year_32
year_128 = 2 * year_64

timescale_names: dict[atomic_unit, str] = {
    minute_15: "minute_15",
    hour_4: "hour_4",
    day: "day",
    week: "week",
    month: "month",
    quarter: "quarter",
    year: "year",
    year_2: "year_2",
    year_4: "year_4",
    year_8: "year_8",
    year_16: "year_16",
    year_32: "year_32",
    year_64: "year_64",
    year_128: "year_128",
}

MAX_TIME = atomic_unit(maxsize - 1)

hour = 4 * minute_15
