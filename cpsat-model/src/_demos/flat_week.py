from _demos.demo import (
    minute_15,
    day,
    week,
    task,
    ZERO_COST_INTERVALS,
    constant_cost_intervals,
    deadline_intervals,
    solve,
)


# --- TASK DESCRIPTION


def __ee98():
    # EE 98 HW 6, due friday (15 pt)
    # unit = we decide which week to put this multi-day task in, so unit is week
    # start/end = cannot possibly schedule this after this week and cannot be negative start

    ee98_hw6 = task("ee98_hw6", week)
    ee98_hw6_hrs = [task(f"ee98_hw6_hr{i}", day) for i in range(6)]
    for hr in ee98_hw6_hrs:
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
    comm20_survey = task("comm20_survey", day)
    comm20_survey.add_cost_config_duration(
        deadline_intervals(4 * day, 0, 25), 6 * minute_15
    )
    comm20_survey.add_cost_config_duration(
        deadline_intervals(4 * day, 5, 25), 3 * minute_15
    )
    comm20_survey.add_cost_config_duration(constant_cost_intervals(25), 0)

    # COMM 20 quiz, due Friday (5 pt)
    comm20_quiz = task("comm20_quiz", day)
    comm20_quiz.add_cost_config_duration(
        deadline_intervals(4 * day, 0, 5), 1 * minute_15
    )
    comm20_quiz.add_cost_config_duration(constant_cost_intervals(5), 0)


def __cmpe50():
    # CMPE 50 Midterm 2 (100 pt)
    cmpe50_midterm2_hrs = [task(f"cmpe50_midterm2_hr{i}", day) for i in range(3)]
    for hr in cmpe50_midterm2_hrs:
        hr.add_cost_config_duration(ZERO_COST_INTERVALS, 4 * minute_15)
    cmpe50_midterm2 = task("cmpe50_midterm2", week)
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
    cmpe50_hw6 = task("cmpe50_hw6", day, end=2)
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
    engr10_robot_lab = task("engr10_robot_lab", day)
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
    engr10_hw3 = task("engr10_hw3", day)
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
        t = task(f"fixed_time_{i}", day, start=i, end=i + 1)
        t.add_cost_config_duration(ZERO_COST_INTERVALS, 19 * 4 * minute_15)
    t = task("fixed_time_5", day, start=5, end=6)
    t.add_cost_config_duration(
        ZERO_COST_INTERVALS,
        8 * 4 * minute_15,
    )
    t = task("fixed_time_6", day, start=6, end=7)
    t.add_cost_config_duration(
        ZERO_COST_INTERVALS,
        10 * 4 * minute_15,
    )


def main():
    __ee98()
    __comm20()
    __cmpe50()
    __engr10()
    __fixed_time_usage()
    solve()
