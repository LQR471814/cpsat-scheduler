from _demos.lib.pert import pert_ppf
from cpsatmodel import (
    CostInterval,
    ScheduledTask,
    Model,
    ConfigBuilder,
    Task,
)
from ortools.sat.python import cp_model

minute_15 = 1  # atomic timescale
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

timescales: list[tuple[int, str]] = [
    (minute_15, "minute_15"),
    (hour_4, "hour_4"),
    (day, "day"),
    (week, "week"),
    (month, "month"),
    (quarter, "quarter"),
    (year, "year"),
    (year_2, "year_2"),
    (year_4, "year_4"),
    (year_8, "year_8"),
    (year_16, "year_16"),
    (year_32, "year_32"),
    (year_64, "year_64"),
    (year_128, "year_128"),
]

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


task_names: dict[int, str] = {}

builder = ConfigBuilder()


def task(
    name: str,
    unit: int,
    start: int | None = None,
    end: int | None = None,
):
    t = Task(builder, unit, start, end)
    task_names[t.id] = name
    return t


pert_fidelity: int = 3


# optimistic/expected/pessimistic durations must be in terms of the atomic unit
def pert_cost_cfg(
    t: Task,
    full_cost: int,
    deadline: int,
    # opt, exp, pes
    pert: tuple[int, int, int],
):
    optimistic, expected, pessimistic = pert
    incr = 1 / pert_fidelity
    for i in range(pert_fidelity):
        p = incr * i
        exp_cost = round(p * full_cost)
        exp_duration = round(pert_ppf(p, optimistic, expected, pessimistic))
        t.add_cost_config_duration(
            deadline_intervals(deadline, exp_cost, full_cost),
            exp_duration,
        )


def solve():
    cfg = builder.build()
    model = Model(cfg)
    status, total_cost, solution_tasks = model.solve()

    if status == cp_model.OPTIMAL or status == cp_model.FEASIBLE:
        print(status, "cost:", total_cost)

        for unit, name in timescales:
            in_unit = [
                s for s in solution_tasks if builder.tasks[s.task_id].unit == unit
            ]
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

                    name = ""
                    if task.id in task_names:
                        name = task_names[task.id]
                    else:
                        assert task.id in builder.temp_tasks
                        name = f"__temp_{task.id}__"

                    print(
                        f"{name}\tid: {s.task_id}\tstart: {s.start}\tcost: {s.real_cost}\tdur: {s.real_duration}\tend: {s.real_end}\tcfg: {s.config}",
                    )
    else:
        print("No solution:", status)
