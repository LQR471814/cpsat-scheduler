from __future__ import annotations

from typing import Self
from ortools.sat.python import cp_model, cp_model_helper as cmh
from dataclasses import dataclass


@dataclass
class CostInterval:
    """
    The specified cost applies if the task's absolute end time is within the interval.
    """

    interval: tuple[int, int]
    cost: int


@dataclass
class CostConfig:
    costs: list[CostInterval]
    children: list[int]
    duration: int | None


@dataclass
class ParentCond:
    # the id of the possible parent
    id: int
    # the cost config it must be under for the task for it to be considered the
    # parent
    config: int


@dataclass
class Config:
    timescales: list[int]
    # margin will not be auto-created, the user is in charge of specifying magin
    tasks: list[int]
    task_timescale_units: dict[int, int]
    task_cost_configs: dict[int, list[CostConfig]]
    # in terms of the atomic timescale unit, each value should have the same
    # length as the corresponding value in task_cost_configs (as there should
    # be a duration for each config)
    task_prerequisites: dict[int, list[int]]
    task_start: dict[int, int]
    task_end: dict[int, int]
    # each parent condition represents a possible parent of the task and the
    # cost config such that it will have this task as one of its children (if
    # there are none, it indicates that the task is a root task)
    task_parent_conditions: dict[int, list[ParentCond]]


def guard_bool(
    model: cp_model.CpModel,
    name: str,
    cond_true: cp_model.BoundedLinearExpression | bool,
    cond_false: cp_model.BoundedLinearExpression | bool,
) -> cp_model.IntVar:
    guard_var = model.new_bool_var(name)
    model.add(cond_true).only_enforce_if(guard_var)
    model.add(cond_false).only_enforce_if(guard_var.Not())
    return guard_var


def and_bool(
    model: cp_model.CpModel, name: str, *cond: cp_model.IntVar
) -> cp_model.IntVar:
    bool_var = model.new_bool_var(name)
    for c in cond:
        model.add_implication(bool_var, c)
    model.add_bool_and(*cond, bool_var).only_enforce_if(bool_var)
    model.add_bool_or(*[b.Not() for b in cond]).only_enforce_if(bool_var.Not())
    return bool_var


class Model:
    config: Config

    def __init__(self, config: Config):
        self.config = config

    # in general, worst case: O(task * cost config * cost interval)
    def _model(self):
        model = cp_model.CpModel()

        # find max timescale (for default upper-bound without knowing anything else)
        max_timescale = 0
        for t in self.config.tasks:
            if self.config.task_timescale_units[t] > max_timescale:
                max_timescale = self.config.task_timescale_units[t]
        max_timescale_count = 0
        for t in self.config.tasks:
            if self.config.task_timescale_units[t] == max_timescale:
                max_timescale_count += 1
        max_start_time = max_timescale * (max_timescale_count - 1)
        max_end_time = max_timescale * max_timescale_count

        min_cost = 0
        max_cost = 0
        for t in self.config.tasks:
            for cfg in self.config.task_cost_configs[t]:
                for intv in cfg.costs:
                    if intv.cost > max_cost:
                        max_cost = intv.cost
                    if intv.cost < min_cost:
                        min_cost = intv.cost

        max_scaling_factor = 1
        prev = self.config.timescales[0]
        for u in self.config.timescales[1:]:
            scale = u // prev
            if scale > max_scaling_factor:
                max_scaling_factor = scale

        timescales_domain = cp_model.Domain.from_values(self.config.timescales)
        zero_domain = cp_model.Domain.from_values([0])

        # init decision variables O(task)
        self.var_starting_times: dict[int, cmh.IntVar] = {}
        self.var_cost_config_select: dict[int, cmh.IntVar] = {}
        # init computed variables O(task)
        self.var_real_end_times: dict[int, cmh.IntVar] = {}
        self.var_real_duration: dict[int, cmh.IntVar] = {}
        self.var_real_cost: dict[int, cmh.IntVar] = {}
        self.var_cost_config_active_bools: dict[int, list[cmh.IntVar]] = {}
        self.var_parent_start: dict[int, cmh.IntVar] = {}
        self.var_parent_unit: dict[int, cmh.IntVar] = {}
        for t in self.config.tasks:
            unit = self.config.task_timescale_units[t]
            self.var_starting_times[t] = model.new_int_var(
                0, max_start_time // unit, f"t{t}_st"
            )
            self.var_cost_config_select[t] = model.new_int_var(
                0, len(self.config.task_cost_configs) - 1, f"t{t}_cfg"
            )
            self.var_real_duration[t] = model.new_int_var(0, max_end_time, f"t{t}_dur")
            self.var_real_end_times[t] = model.new_int_var(
                0, max_end_time // unit, f"t{t}_end"
            )
            self.var_real_cost[t] = model.new_int_var(min_cost, max_cost, f"t{t}_cost")
            self.var_parent_start[t] = model.new_int_var(
                0, max_start_time, f"t{t}_parent_start"
            )
            self.var_parent_unit[t] = model.new_int_var_from_domain(
                timescales_domain.addition_with(zero_domain), f"t{t}_parent_unit"
            )
            self.var_cost_config_active_bools[t] = [
                guard_bool(
                    model,
                    f"t{t}_cfg{i}_active",
                    self.var_cost_config_select[t] == i,
                    self.var_cost_config_select[t] != i,
                )
                for i in range(len(self.config.task_cost_configs[t]))
            ]

        # init computed duration & end time variables defs
        for t in self.config.tasks:
            unit = self.config.task_timescale_units[t]
            start_time = self.var_starting_times[t]
            end_time = self.var_real_end_times[t]
            real_duration = self.var_real_duration[t]
            cost_config_active_bools = self.var_cost_config_active_bools[t]

            configs = self.config.task_cost_configs[t]
            for i, cfg in enumerate(configs):
                children = cfg.children
                config_active = cost_config_active_bools[i]

                if len(children) > 0:  # O(task)
                    # define real duration as sum of children
                    real_duration_expr = 0
                    for c in children:
                        dur = self.var_real_duration[c]
                        real_duration_expr += dur

                    model.add(real_duration == real_duration_expr).only_enforce_if(
                        config_active
                    )

                    # define real end time as max of children end times
                    children_exprs = [self.var_real_end_times[c] for c in children]
                    model.add_max_equality(end_time, children_exprs).only_enforce_if(
                        config_active
                    )
                else:  # O(cost config * task)
                    # define real duration as function of selected cost config
                    assert cfg.duration is not None
                    defined = cfg.duration
                    model.add(real_duration == defined).only_enforce_if(config_active)
                    # define real end time as real start time + real duration
                    model.add(
                        end_time == unit * start_time + real_duration
                    ).only_enforce_if(config_active)

        # init computed parent vars O(task)
        for t in self.config.tasks:
            task_parent_unit = self.var_parent_unit[t]
            task_parent_start = self.var_parent_start[t]

            if len(self.config.task_parent_conditions) == 0:
                # indicates that task does not have parent
                model.add((task_parent_unit == 0) & (task_parent_start == 0))
                continue

            for cond in self.config.task_parent_conditions[t]:
                parent_unit = self.config.task_timescale_units[cond.id]
                parent_start = self.var_starting_times[cond.id]
                parent_cost_config_active = self.var_cost_config_active_bools[cond.id][
                    cond.config
                ]
                model.add(task_parent_unit == parent_unit).only_enforce_if(
                    parent_cost_config_active
                )
                model.add(task_parent_start == parent_start).only_enforce_if(
                    parent_cost_config_active
                )

        # add start/end constraints O(task)
        for t in self.config.tasks:
            task_unit = self.config.task_timescale_units[t]
            task_starting_var = self.var_starting_times[t]

            # define parent start/end constraints (tautalogy if not specified)
            parent_unit = self.var_parent_unit[t]
            parent_start_var = self.var_parent_start[t]

            # 1. compute scaling factor
            scaling_factor = model.new_int_var(
                1, max_scaling_factor, f"scaling_factor_{t}"
            )
            model.add_division_equality(scaling_factor, parent_unit, task_unit)

            # 2. compute parent start in the task's unit
            parent_start_converted = model.new_int_var(
                0, max_start_time, f"parent_start_converted_{t}"
            )
            model.add_multiplication_equality(
                parent_start_converted, scaling_factor, parent_start_var
            )

            # 3. bound the task start time decision variable to what the
            # parent's bounds are
            parent_not_null = guard_bool(
                model,
                f"task_parent_not_null_{t}",
                self.var_parent_unit[t] != 0,
                self.var_parent_unit[t] == 0,
            )
            model.add(task_starting_var >= parent_start_converted).only_enforce_if(
                parent_not_null
            )
            model.add(
                task_starting_var < parent_start_converted + scaling_factor
            ).only_enforce_if(parent_not_null)

            # define intrinsic start/end constraints (tautalogy if not specified)
            if t in self.config.task_start:
                model.add(task_starting_var >= self.config.task_start[t])
            if t in self.config.task_end:
                model.add(task_starting_var < self.config.task_end[t])

        # add prereq constraints O(prereqs * task)
        for t in self.config.tasks:
            start_var = self.var_starting_times[t]
            prereqs = self.config.task_prerequisites[t]
            for p in prereqs:
                p_real_end_var = self.var_real_end_times[p]
                model.add(p_real_end_var <= start_var)

        # this constrains timescale instance overflow O(task)
        #
        # we assume that the # tasks will be much smaller than the number of
        # timescale instances, we simply check from the perspective of each task,
        # what the sum with other equal tasks is and make sure it is under the
        # limit
        #
        # this is an O(n^2) algorithm, where n is the # of tasks
        #
        # we can improve perf. in the expected case by filtering by tasks in the
        # same timescale
        for t in self.config.tasks:
            defined = self.var_real_duration[t]
            unit = self.config.task_timescale_units[t]  # this is also the max duration

            sum = defined
            for other in self.config.tasks:
                if other == t:
                    continue
                if self.config.task_timescale_units[other] != unit:
                    continue
                other_duration = self.var_real_duration[other]
                sum += other_duration

            model.add(sum <= unit)

        # add computed costs O(cost config * cost interval * task)
        for t in self.config.tasks:
            real_end_time = self.var_real_end_times[t]
            real_cost = self.var_real_cost[t]

            for i, cfg in enumerate(self.config.task_cost_configs[t]):
                config_active = self.var_cost_config_active_bools[t][i]
                for j, intv in enumerate(cfg.costs):
                    start, end = intv.interval
                    cost_intv_after_start = guard_bool(
                        model,
                        f"t{t}_cfg{i}_intv{j}_before_start",
                        real_end_time >= start,
                        real_end_time < start,
                    )
                    cost_intv_before_end = guard_bool(
                        model,
                        f"t{t}_cfg{i}_intv{j}_after_end",
                        real_end_time <= end,
                        real_end_time > end,
                    )
                    model.add(real_cost == intv.cost).only_enforce_if(
                        config_active, cost_intv_after_start, cost_intv_before_end
                    )

        # objective function O(task)
        sum_cost_expr = 0
        for t in self.config.tasks:
            sum_cost_expr += self.var_real_cost[t]
        model.minimize(sum_cost_expr)

        return model

    def solve(self):
        model = self._model()
        solver = cp_model.CpSolver()
        status = solver.solve(model)
        if status == cp_model.OPTIMAL or status == cp_model.FEASIBLE:
            print(status)
            for t in self.config.tasks:
                print(f"Task {t}:")
                print(f"\tstart = {solver.value(self.var_starting_times[t])}")
                print(f"\tend = {solver.value(self.var_real_end_times[t])}")
                print(f"\tcost = {solver.value(self.var_real_cost[t])}")
                print(f"\tcost_cfg = {solver.value(self.var_cost_config_select[t])}")
        else:
            print("No solution found.", status)


class Task:
    id: int
    unit: int
    start: int | None
    end: int | None

    _prerequisites: list[int]

    _configs: list[CostConfig]
    _parent_conds: list[ParentCond]

    _builder: ConfigBuilder

    def __init__(
        self,
        builder: ConfigBuilder,
        unit: int,
        start: int | None = None,
        end: int | None = None,
    ) -> None:
        builder.next_id += 1
        builder.tasks[builder.next_id] = self
        builder.timescales.add(unit)

        self._configs = []
        self._prerequisites = []
        self._parent_conds = []
        self._builder = builder

        self.id = builder.next_id
        self.unit = unit
        self.start = start
        self.end = end
        assert start is None or end is None or start < end

    def add_cost_config_duration(self, costs: list[CostInterval], duration: int):
        assert duration >= 0
        self._configs.append(
            CostConfig(
                costs=costs,
                children=[],
                duration=duration,
            )
        )

    def add_cost_config_children(self, costs: list[CostInterval], children: list[Task]):
        for c in children:
            assert c.id in self._builder.tasks
            c._parent_conds.append(ParentCond(id=self.id, config=len(self._configs)))
        self._configs.append(
            CostConfig(
                costs=costs,
                children=[c.id for c in children],
                duration=None,
            )
        )

    def add_prereq(self, prereq: Self):
        assert prereq.id in self._builder.tasks
        self._prerequisites.append(prereq.id)


class ConfigBuilder:
    def __init__(self):
        self.next_id = 0
        self.timescales: set[int] = set()
        # margin will not be auto-created, the user is in charge of specifying magin
        self.tasks: dict[int, Task] = {}

    def _detect_cycles(self, id: int, visited: set[int], trace: list[int], depth: int):
        trace = trace[:depth]
        trace.append(id)
        if id in visited:
            raise Exception(f"Detected cycle! Trace: {trace}")
        visited.add(id)
        for cfg in self.tasks[id]._configs:
            for child in cfg.children:
                self._detect_cycles(child, visited, trace, depth + 1)

    def _validate(self):
        # ensure that all timescales are multiples of each other
        assert len(self.timescales) > 0
        scales = sorted(list(self.timescales), reverse=True)
        parent = scales[0]
        for s in scales[1:]:
            assert parent % s == 0
            parent = s

        # ensure that no cycles are present
        visited: set[int] = set()
        for t in self.tasks:
            if len(self.tasks[t]._parent_conds) > 0:
                continue
            self._detect_cycles(t, visited, [], 0)

    def build(self) -> Config:
        timescales: list[int] = list(self.timescales)
        tasks: list[int] = list(self.tasks.keys())

        task_timescale_units: dict[int, int] = {}
        task_cost_configs: dict[int, list[CostConfig]] = {}
        task_prerequisites: dict[int, list[int]] = {}
        task_start: dict[int, int] = {}
        task_end: dict[int, int] = {}
        task_parent_conditions: dict[int, list[ParentCond]] = {}

        for id in self.tasks:
            task = self.tasks[id]
            task_timescale_units[id] = task.unit
            task_cost_configs[id] = task._configs
            task_prerequisites[id] = task._prerequisites
            if task.start is not None:
                task_start[id] = task.start
            if task.end is not None:
                task_end[id] = task.end
            task_parent_conditions[id] = task._parent_conds

        return Config(
            timescales=timescales,
            tasks=tasks,
            task_timescale_units=task_timescale_units,
            task_cost_configs=task_cost_configs,
            task_prerequisites=task_prerequisites,
            task_start=task_start,
            task_end=task_end,
            task_parent_conditions=task_parent_conditions,
        )
