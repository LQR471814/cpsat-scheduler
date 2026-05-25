from cpsatmodel import (
    CostInterval,
    ScheduledTask,
    Model,
    ConfigBuilder,
    Task,
    atomic_unit,
    task_unit,
)
from ortools.sat.python import cp_model

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
    return [CostInterval((atomic_unit(0), END_TIME), cost)]


ZERO_COST_INTERVALS = constant_cost_intervals(0)


def deadline_intervals(
    deadline: atomic_unit,
    exp_cost: int,
    full_cost: int,
    start=atomic_unit(0),
    end=END_TIME,
):
    return [
        CostInterval((start, deadline), exp_cost),
        CostInterval((deadline, end), full_cost),
    ]


task_names: dict[int, str] = {}


def task_builder(builder: ConfigBuilder):
    def task(
        name: str,
        unit: atomic_unit,
        start: task_unit | None = None,
        end: task_unit | None = None,
    ):
        t = Task(builder, unit, start, end)
        task_names[t.id] = name
        return t

    return task


pert_fidelity: list[float] = [0, 0.4, 0.8, 0.9, 0.95, 0.99, 1]


# from scipy.stats import beta
#
#
# # PPF is the inverse of CDF, here it gives the duration to achieve a given
# # probability
# def pert_ppf(p: float, optimistic: float, expected: float, pessimistic: float):
#     alpha = 1 + 4 * (expected - optimistic) / (pessimistic - optimistic)
#     beta_param = 1 + 4 * (pessimistic - expected) / (pessimistic - optimistic)
#     t: float = beta.ppf([p], alpha, beta_param).item()
#     return optimistic + t * (pessimistic - optimistic)
#
# # optimistic/expected/pessimistic durations must be in terms of the atomic unit
# def pert_cost_cfg(
#     t: Task,
#     full_cost: int,
#     deadline: int,
#     # opt, exp, pes
#     pert: tuple[int, int, int],
# ):
#     optimistic, expected, pessimistic = pert
#     for p in pert_fidelity:
#         exp_earn = round(p * full_cost)
#         exp_duration = round(pert_ppf(p, optimistic, expected, pessimistic))
#         t.add_cost_config_duration(
#             deadline_intervals(deadline, full_cost - exp_earn, full_cost),
#             exp_duration,
#         )


def solve(builder: ConfigBuilder):
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
