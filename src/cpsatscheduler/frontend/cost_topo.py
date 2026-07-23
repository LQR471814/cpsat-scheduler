from cpsatscheduler.backend import CostInterval, atomic_unit
from cpsatscheduler.frontend.units import MAX_TIME

ZERO_TIME = atomic_unit(0)


def constant(cost: int):
    return [CostInterval((ZERO_TIME, MAX_TIME), cost)]


def step_fn(
    step_time: atomic_unit,
    cost_before_step: int,
    cost_after_step: int,
    start=ZERO_TIME,
    end=MAX_TIME,
):
    return [
        CostInterval((start, step_time), cost_before_step),
        CostInterval((step_time, end), cost_after_step),
    ]
