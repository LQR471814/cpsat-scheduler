from config import ConfigBuilder, CostInterval, Task, CostConfig, Model


# the atomic timescale unit is 15 minutes
minute_15 = 1
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

timescales: list[int] = [
    minute_15,
    hour_4,
    day,
    week,
    month,
    quarter,
    year,
    year_2,
    year_4,
    year_8,
    year_16,
    year_32,
    year_64,
    year_128,
]

builder = ConfigBuilder()

# 1. each cost configuration represents a different probability???
# 2. this doesn't make any sense, as the cost should only depend on the end time

# on wednesday
midterm = Task(
    builder,
    week,
    [
        CostConfig(
            [
                CostInterval((0, day * 3), 0),
                CostInterval((day * 3, year_128), 10),
            ]
        ),
        CostConfig(
            [
                CostInterval((0, day * 3), 0),
                CostInterval((day * 3, year_128), 10),
            ]
        ),
    ],
    end=week,
)

hw1 = Task(
    builder,
    day,
    [],
    end=week,
)

hw2 = Task(
    builder,
    day,
    [],
    end=week,
)


cfg = builder.build()
model = Model(cfg)
model.solve()
