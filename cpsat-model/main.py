from config import (
    CostInterval,
    ProtoPrinter,
    ScheduledTask,
    Model,
    assert_non_overflow,
    assert_intrinsic_start_end,
)
from config_builder import ConfigBuilder, Task
from ortools.sat.python import cp_model


# --- FRONT MATTER


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

timescale_names: list[str] = [
    "minute_15",
    "hour_4",
    "day",
    "week",
    "month",
    "quarter",
    "year",
    "year_2",
    "year_4",
    "year_8",
    "year_16",
    "year_32",
    "year_64",
    "year_128",
]
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

END_TIME = year_128


def constant_cost_intervals(cost: int):
    return [CostInterval((0, END_TIME), cost)]


ZERO_COST_INTERVALS = constant_cost_intervals(0)


def deadline_intervals(
    deadline: int, exp_cost: int, full_cost: int, start=0, end=END_TIME
):
    return [
        CostInterval((start, deadline), exp_cost),
        CostInterval((deadline, end), full_cost),
    ]


# --- TASK DESCRIPTION


task_names: dict[int, str] = {}


def __ee98():
    # EE 98 HW 6, due friday (15 pt)
    # unit = we decide which week to put this multi-day task in, so unit is week
    # start/end = cannot possibly schedule this after this week and cannot be negative start

    ee98_hw6 = Task(builder, week, end=1)
    task_names[ee98_hw6.id] = "ee98_hw6"

    ee98_hw6_hrs = [Task(builder, day) for _ in range(3)]
    for i, hr in enumerate(ee98_hw6_hrs):
        task_names[hr.id] = f"ee98_hw6_hr{i}"
        hr.add_cost_config_duration(ZERO_COST_INTERVALS, 4 * minute_15)

    ee98_hw6.add_cost_config_duration(constant_cost_intervals(15), 15)

    for duration_hrs, exp_cost in [
        (5, 0),
        (4, 2),
        (3, 3),
        (2, 5),
        (1, 7),
    ]:
        ee98_hw6.add_cost_config_children(
            deadline_intervals(5 * day, exp_cost, 15),
            ee98_hw6_hrs[0:duration_hrs],
        )


def __comm20():
    # COMM 20 survey, due thursday (25 pt)
    comm20_survey = Task(builder, week, end=1)
    task_names[comm20_survey.id] = "comm20_survey"
    comm20_survey.add_cost_config_duration(
        deadline_intervals(4 * day, 0, 25), 6 * minute_15
    )
    comm20_survey.add_cost_config_duration(
        deadline_intervals(4 * day, 5, 25), 3 * minute_15
    )
    comm20_survey.add_cost_config_duration(constant_cost_intervals(25), 0)

    # COMM 20 quiz, due Friday (5 pt)
    comm20_quiz = Task(builder, week, end=1)
    task_names[comm20_quiz.id] = "comm20_quiz"
    comm20_quiz.add_cost_config_duration(
        deadline_intervals(4 * day, 0, 5), 1 * minute_15
    )
    comm20_quiz.add_cost_config_duration(constant_cost_intervals(5), 0)


def __cmpe50():
    # CMPE 50 Midterm 2 (100 pt)
    cmpe50_midterm2_hrs = [Task(builder, day) for _ in range(3)]
    for i, hr in enumerate(cmpe50_midterm2_hrs):
        task_names[hr.id] = f"cmpe50_midterm2_hr{i}"
        hr.add_cost_config_duration(ZERO_COST_INTERVALS, 4 * minute_15)
    cmpe50_midterm2 = Task(builder, week, end=1)
    task_names[cmpe50_midterm2.id] = "cmpe50_midterm2"
    for duration_hrs, exp_cost in [
        (3, 0),
        (2, 8),
        (1, 20),
    ]:
        cmpe50_midterm2.add_cost_config_children(
            deadline_intervals(4 * day, exp_cost, 100),
            cmpe50_midterm2_hrs[0:duration_hrs],
        )
    cmpe50_midterm2.add_cost_config_duration(constant_cost_intervals(100), 0)

    # CMPE 50 HW 6 (30 pt) due tuesday
    cmpe50_hw6 = Task(builder, day, end=2)
    task_names[cmpe50_hw6.id] = "cmpe50_hw6"
    cmpe50_hw6.add_cost_config_duration(
        deadline_intervals(2 * day, 0, 30),
        4 * minute_15,
    )
    cmpe50_hw6.add_cost_config_duration(
        deadline_intervals(2 * day, 15, 30), 2 * minute_15
    )
    cmpe50_hw6.add_cost_config_duration(constant_cost_intervals(30), 0)


def __engr10():
    # ENGR 10 Robot Lab Prep. (est. 5 pt)
    engr10_robot_lab = Task(builder, week)
    task_names[engr10_robot_lab.id] = "engr10_robot_lab"
    engr10_robot_lab.add_cost_config_duration(
        deadline_intervals(5 * day, 0, 5), 6 * minute_15
    )
    engr10_robot_lab.add_cost_config_duration(
        deadline_intervals(5 * day, 1, 5), 4 * minute_15
    )
    engr10_robot_lab.add_cost_config_duration(
        deadline_intervals(5 * day, 4, 5), 2 * minute_15
    )
    engr10_robot_lab.add_cost_config_duration(constant_cost_intervals(10), 0)

    # ENGR 10 HW 3 (30 pt)
    engr10_hw3 = Task(builder, week)
    task_names[engr10_hw3.id] = "engr10_hw3"
    engr10_hw3.add_cost_config_duration(
        deadline_intervals(7 * day, 0, 30), 5 * minute_15
    )
    engr10_hw3.add_cost_config_duration(
        deadline_intervals(7 * day, 2, 30), 4 * minute_15
    )
    engr10_hw3.add_cost_config_duration(
        deadline_intervals(7 * day, 3, 30), 3 * minute_15
    )
    engr10_hw3.add_cost_config_duration(
        deadline_intervals(7 * day, 7, 30), 2 * minute_15
    )


def __fixed_time_usage():
    for i in range(5):
        t = Task(builder, day, start=i, end=i + 1)
        t.add_cost_config_duration(ZERO_COST_INTERVALS, 19 * 4 * minute_15)
        task_names[t.id] = f"fixed_time_{i}"
    t = Task(builder, day, start=5, end=6)
    t.add_cost_config_duration(
        ZERO_COST_INTERVALS,
        8 * 4 * minute_15,
    )
    task_names[t.id] = "fixed_time_5"
    t = Task(builder, day, start=6, end=7)
    t.add_cost_config_duration(
        ZERO_COST_INTERVALS,
        10 * 4 * minute_15,
    )
    task_names[t.id] = "fixed_time_6"


__ee98()
__comm20()
__cmpe50()
__engr10()
__fixed_time_usage()


cfg = builder.build()
model = Model(cfg)
status, total_cost, solution_tasks = model.solve()
printer = ProtoPrinter(model.model.Proto())
printer.print_text()

if status == cp_model.OPTIMAL or status == cp_model.FEASIBLE:
    print(status, "cost:", total_cost)
    assert_intrinsic_start_end(cfg, solution_tasks)
    assert_non_overflow(cfg, solution_tasks)

    for unit, name in zip(timescales, timescale_names):
        in_unit = [s for s in solution_tasks if builder.tasks[s.task_id].unit == unit]
        if len(in_unit) == 0:
            continue
        groups: dict[int, list[ScheduledTask]] = {}
        for s in in_unit:
            if s.start not in groups:
                groups[s.start] = []
            groups[s.start].append(s)
        print(f"\n\nUNIT --- {name} ({unit} atomic units)\n")
        for starting_time in sorted(groups.keys()):
            print(f"\nUnit {starting_time}:")
            for s in groups[starting_time]:
                task = builder.tasks[s.task_id]
                print(
                    f"{task_names[task.id]}\tid: {s.task_id}\tstart: {s.start}\tcost: {s.real_cost}\treal_end: {s.real_end}\tcfg: {s.config}",
                )
else:
    print("No solution:", status)
