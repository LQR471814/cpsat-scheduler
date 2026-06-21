from cpsatmodel import (
    CostInterval,
    atomic_unit,
)
from _demos.lib.units import MAX_TIME


def constant(cost: int):
    return [CostInterval((atomic_unit(0), MAX_TIME), cost)]


def step_fn(
    step_time: atomic_unit,
    cost_before_step: int,
    cost_after_step: int,
    start=atomic_unit(0),
    end=MAX_TIME,
):
    return [
        CostInterval((start, step_time), cost_before_step),
        CostInterval((step_time, end), cost_after_step),
    ]


