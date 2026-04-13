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
    intervals: list[CostInterval]


@dataclass
class Config:
    timescales: list[int]
    # margin will not be auto-created, the user is in charge of specifying magin
    tasks: list[int]
    task_timescale_units: dict[int, int]
    task_cost_configs: dict[int, list[CostConfig]]
    task_prerequisites: dict[int, list[int]]
    task_start: dict[int, int]
    task_end: dict[int, int]
    task_children: dict[int, list[int]]
    task_parent: dict[int, int]
    # in terms of the atomic timescale unit, each value should have the same
    # length as the corresponding value in task_cost_configs (as there should
    # be a duration for each config)
    leaf_task_duration: dict[int, list[int]]


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
                for intv in cfg.intervals:
                    if intv.cost > max_cost:
                        max_cost = intv.cost
                    if intv.cost < min_cost:
                        min_cost = intv.cost

        # init decision variables O(task)
        self.var_starting_times: dict[int, cmh.IntVar] = {}
        self.var_cost_config_select: dict[int, cmh.IntVar] = {}
        # init computed variables O(task)
        self.var_real_end_times: dict[int, cmh.IntVar] = {}
        self.var_real_duration: dict[int, cmh.IntVar] = {}
        self.var_real_cost: dict[int, cmh.IntVar] = {}
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

        # init computed duration & end time variables defs
        for t in self.config.tasks:
            unit = self.config.task_timescale_units[t]
            start_time = self.var_starting_times[t]
            end_time = self.var_real_end_times[t]
            real_duration = self.var_real_duration[t]
            cost_config = self.var_cost_config_select[t]

            children = self.config.task_children[t]
            if len(children) > 0:  # O(task)
                # define real duration as sum of children
                real_duration_expr = 0
                for c in children:
                    dur = self.var_real_duration[c]
                    real_duration_expr += dur
                model.add(real_duration == real_duration_expr)

                # define real end time as max of children end times
                children_exprs = [self.var_real_end_times[c] for c in children]
                model.add_max_equality(end_time, children_exprs)
            else:  # O(cost config * task)
                # define real duration as function of selected cost config
                assert t in self.config.leaf_task_duration
                defined_durs = self.config.leaf_task_duration[t]
                for i, d in enumerate(defined_durs):
                    model.add(real_duration == d).only_enforce_if(cost_config == i)
                # define real end time as real start time + real duration
                model.add(end_time == unit * start_time + real_duration)

        # add start/end constraints O(task)
        for t in self.config.tasks:
            task_unit = self.config.task_timescale_units[t]
            task_starting_var = self.var_starting_times[t]

            # define parent start/end constraints (tautalogy if not specified)
            parent: int | None = (
                self.config.task_parent[t] if t in self.config.task_parent else None
            )
            parent_start_cond = True
            parent_end_cond = True
            if parent is not None:
                parent_unit = self.config.task_timescale_units[parent]
                # we are guaranteed a non-zero integer as the parent unit must be > child unit
                assert parent_unit > task_unit
                scaling_factor = parent_unit // task_unit
                parent_start_var = self.var_starting_times[parent]
                parent_start_cond = (
                    task_starting_var >= scaling_factor * parent_start_var
                )
                parent_end_cond = task_starting_var < scaling_factor * (
                    parent_start_var + 1
                )

            # define task intrinsic start/end constraints (tautalogy if not specified)
            task_start_cond = True
            if t in self.config.task_start:
                task_start_cond = task_starting_var >= self.config.task_start[t]
            task_end_cond = True
            if t in self.config.task_end:
                task_end_cond = task_starting_var < self.config.task_end[t]

            # ensure both parent and task start/end constraints are met
            model.add_bool_and(
                parent_start_cond, task_start_cond, parent_end_cond, task_end_cond
            )

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
            duration = self.var_real_duration[t]
            unit = self.config.task_timescale_units[t]  # this is also the max duration

            sum = duration
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
            cost_config = self.var_cost_config_select[t]
            real_cost = self.var_real_cost[t]

            for i, cfg in enumerate(self.config.task_cost_configs[t]):
                for intv in cfg.intervals:
                    start, end = intv.interval
                    model.add(real_cost == intv.cost).only_enforce_if(
                        cost_config == i
                        and real_end_time >= start
                        and real_end_time <= end
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
                print(f"\tunit = {self.config.task_timescale_units[t]}")
                print(f"\tstart = {self.var_starting_times[t]}")
                print(f"\tend = {self.var_real_end_times[t]}")
                print(f"\tcost = {self.var_real_cost[t]}")
                print(f"\tcost_cfg = {self.var_cost_config_select[t]}")
        else:
            print("No solution found.", status)


class Task:
    id: int
    unit: int
    configs: list[CostConfig]
    durations: list[int] | None
    start: int | None
    end: int | None

    _prerequisites: list[int]
    _children: list[int]
    _parent: int | None
    _builder: ConfigBuilder

    def __init__(
        self,
        builder: ConfigBuilder,
        unit: int,
        configs: list[CostConfig],
        start: int | None = None,
        end: int | None = None,
        duration: int | None = None,
    ) -> None:
        builder.next_id += 1
        self.id = builder.next_id
        self.unit = unit
        self.configs = configs
        self.start = start
        self.end = end
        assert start is None or end is None or start < end
        self.duration = duration
        self._prerequisites = []
        self._children = []
        self._parent = None
        self._builder = builder
        builder.tasks[self.id] = self
        builder.timescales.add(unit)

    def add_child(self, child: Self):
        assert child.id in self._builder.tasks
        child._parent = self.id
        self._children.append(child.id)


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
        for child in self.tasks[id]._children:
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
            if self.tasks[t]._parent is not None:
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
        task_children: dict[int, list[int]] = {}
        task_parent: dict[int, int] = {}
        leaf_task_duration: dict[int, list[int]] = {}

        for id in self.tasks:
            task = self.tasks[id]
            task_timescale_units[id] = task.unit
            task_cost_configs[id] = task.configs
            task_prerequisites[id] = task._prerequisites
            if task.start is not None:
                task_start[id] = task.start
            if task.end is not None:
                task_end[id] = task.end
            if task._parent is not None:
                task_parent[id] = task._parent
            task_children[id] = task._children
            if task.durations is not None:
                leaf_task_duration[id] = task.durations

        return Config(
            timescales=timescales,
            tasks=tasks,
            task_timescale_units=task_timescale_units,
            task_cost_configs=task_cost_configs,
            task_prerequisites=task_prerequisites,
            task_start=task_start,
            task_end=task_end,
            task_children=task_children,
            task_parent=task_parent,
            leaf_task_duration=leaf_task_duration,
        )
