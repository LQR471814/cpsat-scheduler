from _demos.lib.schedule import Schedule
from cpsatmodel import Task, atomic_unit
from scipy.stats import beta
import _demos.lib.cost_topo as cost_topo
from typing import overload


pert_fidelity: list[float] = [0, 0.4, 0.8, 0.9, 0.95, 0.99, 1]


# PPF is the inverse of CDF, here it gives the duration to achieve a given
# probability
def pert_ppf(p: float, optimistic: float, expected: float, pessimistic: float):
    alpha = 1 + 4 * (expected - optimistic) / (pessimistic - optimistic)
    beta_param = 1 + 4 * (pessimistic - expected) / (pessimistic - optimistic)
    t: float = beta.ppf([p], alpha, beta_param).item()
    return optimistic + t * (pessimistic - optimistic)


class PERTCosts:
    def __init__(
        self,
        stops: list[float],
        full_cost: int,
        pert: tuple[atomic_unit, atomic_unit, atomic_unit],
    ) -> None:
        # smallest -> largest
        self.stops = sorted(stops)
        self.full_cost = full_cost
        self.opt, self.exp, self.pes = pert
        self.i = 0
        assert self.pes >= self.exp and self.exp >= self.opt

    def __iter__(self):
        return self

    def __next__(self):
        if self.i >= len(self.stops):
            raise StopIteration

        p = self.stops[self.i]
        exp_earn = round(p * self.full_cost)
        exp_duration = atomic_unit(
            round(pert_ppf(p, float(self.opt), float(self.exp), float(self.pes)))
        )

        self.i += 1
        return exp_earn, exp_duration


# optimistic/expected/pessimistic durations must be in terms of the
# atomic unit
@overload
def cost_deadline(
    t: Task,
    full_cost: int,
    deadline: atomic_unit,
    pert: tuple[atomic_unit, atomic_unit, atomic_unit],
) -> Task: ...


@overload
def cost_deadline(
    t: Task,
    full_cost: int,
    deadline: atomic_unit,
    # opt, exp, pes
    pert: tuple[atomic_unit, atomic_unit, atomic_unit],
    block_size: atomic_unit,
    block_unit: atomic_unit,
    schedule: Schedule,
) -> Task: ...


def cost_deadline(
    t: Task,
    full_cost: int,
    deadline: atomic_unit,
    # opt, exp, pes
    pert: tuple[atomic_unit, atomic_unit, atomic_unit],
    block_size: atomic_unit | None = None,
    block_unit: atomic_unit | None = None,
    schedule: Schedule | None = None,
) -> Task:
    if block_size is not None and schedule is not None and block_unit is not None:
        task_name = schedule.task_names[t.id]

        pert_entries = list(PERTCosts(pert_fidelity, full_cost, pert))

        max_dur = atomic_unit(0)
        for _, exp_dur in pert_entries:
            if exp_dur > max_dur:
                max_dur = exp_dur

        # block tasks are all the child tasks with a duration = block_size
        block_tasks: list[Task] = []

        # we create all the necessary block tasks
        for i in range(max_dur // block_size):
            child = schedule.task(
                f"{task_name} (block {i + 1})",
                block_unit,
            )

            child.add_cost_config_duration(cost_topo.constant(0), block_size)

            if i > 0:
                # blocks of lower number must occur before blocks of
                # higher number, this reduces # of states
                child.add_prereq(block_tasks[-1])

            block_tasks.append(child)

        # we enumerate pert fidelities and add child configs for each fidelity
        for i, entry in enumerate(pert_entries):
            exp_earn, exp_dur = entry

            # num_blocks is the number of tasks of duration = block_size
            # necessary to cover the expected duration
            num_blocks = exp_dur // block_size

            children = block_tasks[:num_blocks]

            # if there is remaining time left uncovered by tasks of dur =
            # block_size we create a task of duration < block_size to cover the
            # remainder
            remainder = exp_dur % block_size
            if remainder > atomic_unit(0):
                child = schedule.task(
                    f"{task_name} (block {exp_dur // block_size + 1})",
                    block_unit,
                )

                child.add_cost_config_duration(cost_topo.constant(0), remainder)

                if len(block_tasks) > 0:
                    # blocks of lower number must occur before blocks of
                    # higher number, this reduces # of states
                    child.add_prereq(block_tasks[-1])

                children.append(child)

            t.add_cost_config_children(
                cost_topo.step_fn(
                    deadline,
                    full_cost - exp_earn,
                    full_cost,
                ),
                children,
            )

        return t

    for exp_earn, exp_dur in PERTCosts(pert_fidelity, full_cost, pert):
        t.add_cost_config_duration(
            cost_topo.step_fn(
                deadline,
                full_cost - exp_earn,
                full_cost,
            ),
            exp_dur,
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
