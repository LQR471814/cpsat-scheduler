from config import ConfigBuilder, CostInterval, Task, Model


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
# 3.

END_TIME = year_128

midterm_study_1 = Task(builder, day)
midterm_study_1.add_cost_config_duration(
    [CostInterval((0, END_TIME), 0)],
    minute_15 * 4,
)

midterm_study_2 = Task(builder, day)
midterm_study_2.add_cost_config_duration(
    [CostInterval((0, END_TIME), 0)],
    minute_15 * 4,
)
midterm_study_2.add_prereq(midterm_study_1)

# midterm occurring on wednesday
midterm = Task(
    builder,
    week,
    start=0 * week,
    end=1 * week,
)
# there is a 30% chance of failure upon studying twice
midterm.add_cost_config_children(
    [CostInterval((0, 3 * day), 0), CostInterval((3 * day, END_TIME), 30)],
    [
        midterm_study_1,
        midterm_study_2,
    ],
)
# there is an 70% chance of failure upon studying once
midterm.add_cost_config_children(
    [
        CostInterval((0, day * 3), 0),
        CostInterval((day * 3, END_TIME), 70),
    ],
    [midterm_study_1],
)

# homework 1, due tuesday
hw1 = Task(
    builder,
    day,
    end=2 * day,  # must start before wednesday
)

# homework 2, due thursday
hw2 = Task(
    builder,
    day,
    end=4 * day,  # must start before friday
)


cfg = builder.build()
print(cfg)
model = Model(cfg)
model.solve()
