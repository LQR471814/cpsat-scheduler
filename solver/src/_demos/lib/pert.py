from cpsatmodel import Task, atomic_unit
from scipy.stats import beta
import _demos.lib.cost_topo as cost_topo


pert_fidelity: list[float] = [0, 0.4, 0.8, 0.9, 0.95, 0.99, 1]


# PPF is the inverse of CDF, here it gives the duration to achieve a given
# probability
def pert_ppf(p: float, optimistic: float, expected: float, pessimistic: float):
    alpha = 1 + 4 * (expected - optimistic) / (pessimistic - optimistic)
    beta_param = 1 + 4 * (pessimistic - expected) / (pessimistic - optimistic)
    t: float = beta.ppf([p], alpha, beta_param).item()
    return optimistic + t * (pessimistic - optimistic)


# optimistic/expected/pessimistic durations must be in terms of the atomic unit
def cost_deadline(
    t: Task,
    full_cost: int,
    deadline: atomic_unit,
    # opt, exp, pes
    pert: tuple[atomic_unit, atomic_unit, atomic_unit],
) -> Task:
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
    return t


def cost_const(
    t: Task,
    full_cost: int,
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
            cost_topo.constant(
                full_cost - exp_earn,
            ),
            exp_duration,
        )
    return t
