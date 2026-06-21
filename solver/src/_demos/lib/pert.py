from cpsatmodel import Task
from scipy.stats import beta
import _demos.lib.cost_topo as cost_topo
from _demos.lib.units import atomic_unit


pert_fidelity: list[float] = [0, 0.4, 0.8, 0.9, 0.95, 0.99, 1]


# PPF is the inverse of CDF, here it gives the duration to achieve a given
# probability
def pert_ppf(p: float, optimistic: float, expected: float, pessimistic: float):
    alpha = 1 + 4 * (expected - optimistic) / (pessimistic - optimistic)
    beta_param = 1 + 4 * (pessimistic - expected) / (pessimistic - optimistic)
    t: float = beta.ppf([p], alpha, beta_param).item()
    return optimistic + t * (pessimistic - optimistic)


# optimistic/expected/pessimistic durations must be in terms of the atomic unit
def add_cost_topos(
    t: Task,
    full_cost: int,
    deadline: atomic_unit,
    # opt, exp, pes
    pert: tuple[atomic_unit, atomic_unit, atomic_unit],
):
    opt, exp, pes = pert
    for p in pert_fidelity:
        exp_earn = round(p * full_cost)
        exp_duration = atomic_unit(
            round(pert_ppf(p, float(opt), float(exp), float(pes)))
        )
        t.add_cost_config_duration(
            cost_topo.step_fn(
                deadline,
                full_cost - exp_earn,
                full_cost,
            ),
            exp_duration,
        )
