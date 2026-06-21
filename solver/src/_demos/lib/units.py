from cpsatmodel import atomic_unit
from sys import maxsize

# atomic timescale
minute_15 = atomic_unit(1)
hour_4 = atomic_unit(4 * 4 * minute_15)
day = atomic_unit(6 * hour_4)
week = atomic_unit(7 * day)
month = atomic_unit(4 * week)
quarter = atomic_unit(3 * month)
year = atomic_unit(4 * quarter)
year_2 = atomic_unit(2 * year)
year_4 = atomic_unit(2 * year_2)
year_8 = atomic_unit(2 * year_4)
year_16 = atomic_unit(2 * year_8)
year_32 = atomic_unit(2 * year_16)
year_64 = atomic_unit(2 * year_32)
year_128 = atomic_unit(2 * year_64)

timescale_names: dict[int, str] = {
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
