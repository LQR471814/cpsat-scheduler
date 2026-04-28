from _demos.lib.demo import (
    minute_15,
    hour_4,
    task,
    solve,
    pert_cost_cfg,
)


def __task_a():
    t = task("task A", hour_4)
    pert_cost_cfg(t, 100, 2 * hour_4, (minute_15, 3 * minute_15, 6 * minute_15))


def main():
    __task_a()
    solve()
