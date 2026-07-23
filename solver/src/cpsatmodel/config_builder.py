from __future__ import annotations
from typing import Self
from cpsatmodel.config import (
    CostInterval,
    CostConfig,
    Config,
    TaskConfig,
    atomic_unit,
    task_unit,
)
from sys import maxsize


ZERO_COST_ALWAYS = [CostInterval((atomic_unit(0), atomic_unit(maxsize - 1)), 0)]


class Task:
    id: int
    unit: atomic_unit
    start: task_unit | None
    end: task_unit | None

    _prerequisites: list[int]

    _configs: list[CostConfig]

    _parent: int | None
    _parent_cfgs: list[int]

    _builder: ConfigBuilder

    def __init__(
        self,
        builder: ConfigBuilder,
        unit: atomic_unit,
        # start is inclusive
        start: task_unit | None = None,
        # end is inclusive
        end: task_unit | None = None,
    ) -> None:
        builder.task_next_id += 1
        builder.tasks[builder.task_next_id] = self
        builder.timescales.add(unit)

        self._configs = []
        self._prerequisites = []
        self._parent = None
        self._parent_cfgs = []
        self._builder = builder

        self.id = builder.task_next_id
        self.unit = unit
        self.start = start
        self.end = end
        assert start is None or end is None or start < end

    def add_cost_config_duration(
        self, costs: list[CostInterval], duration: atomic_unit
    ):
        assert duration >= atomic_unit(0)
        self._configs.append(
            CostConfig(
                costs=costs,
                children=[],
                duration=duration,
            )
        )

    def add_cost_config_children(self, costs: list[CostInterval], children: list[Task]):
        for c in children:
            # child must exist
            assert c.id in self._builder.tasks
            # child must not already be a child of another task
            assert c._parent is None or c._parent == self.id
            assert c.unit < self.unit
            c._parent = self.id
            c._parent_cfgs.append(len(self._configs))

        self._configs.append(
            CostConfig(
                costs=costs,
                children=[c.id for c in children],
                duration=None,
            )
        )

    def add_prereq(self, prereq: Self):
        # prereq must exist
        assert prereq.id in self._builder.tasks
        self._prerequisites.append(prereq.id)

    def config(self) -> TaskConfig:
        return TaskConfig(
            id=self.id,
            timescale_unit=self.unit,
            start=self.start,
            end=self.end,
            prerequisites=self._prerequisites,
            cost_configs=self._configs,
            parent_configs=self._parent_cfgs,
            parent=self._parent,
        )


class ConfigBuilder:
    def __init__(self, horizon: tuple[atomic_unit, atomic_unit]):
        self.horizon = horizon
        self.timescales: set[atomic_unit] = set()

        self.task_next_id = 0
        self.tasks: dict[int, Task] = {}

        self.temp_tasks: set[int] = set()

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
            if len(self.tasks[t]._parent_cfgs) > 0:
                continue
            self._detect_cycles(t, visited, [], 0)

    def __create_tmp_parents(self):
        # from largest -> smallest
        scales = sorted(self.timescales, reverse=True)

        # since scales are dynamically computed from given tasks, then sorted
        # from largest -> smallest, scales[0] must be the largest timescale
        max_timescale = scales[0]

        # fill in parents to the max timescale for each task without parent
        # with timescale < max_timescale

        tasks = list(self.tasks.values())
        for task in tasks:
            # skip tasks with parents and root tasks
            if task.unit == max_timescale:
                continue

            task_unit_idx = scales.index(task.unit)

            parent: Task | None = None
            parent_unit_idx: int | None = None
            if task._parent is not None:
                parent = self.tasks[task._parent]
                parent_unit_idx = scales.index(parent.unit)

            # the difference between the parent and current task index in the
            # sorted timescale list
            unit_idx_diff = (
                abs(parent_unit_idx - task_unit_idx)
                if parent_unit_idx is not None
                else -1
            )

            if unit_idx_diff == 0:
                assert parent is not None
                raise Exception(f"task {task.id} has a parent {parent.id} with the same unit as it {task.unit}")
            elif unit_idx_diff == 1:
                # skip tasks with one direct parent
                continue
            elif unit_idx_diff > 1:
                # add temporary parents inbetween a task and a parent that is
                # not in the timescale immediately above it
                #
                # ex. hour_4 -> week
                # becomes: hour_4 -> day (temp) -> week
                assert parent is not None

                # we copy this list because it will be mutated when we run
                # add_cost_config_children later
                parent_cfgs = [*task._parent_cfgs]

                # we detach the current's task from original parent
                task._parent = None
                task._parent_cfgs = []

                # we add temporary wrappers until reaching parent
                prev = task
                for i in range(unit_idx_diff - 1):
                    tmp_parent_unit = scales[task_unit_idx - i - 1]
                    tmp = Task(self, tmp_parent_unit)
                    self.temp_tasks.add(tmp.id)

                    tmp.add_cost_config_children(ZERO_COST_ALWAYS, [prev])
                    prev = tmp

                # we connect last wrapper to original parent
                prev._parent = parent.id
                for idx in parent_cfgs:
                    cfg = parent._configs[idx]
                    cfg.children.remove(task.id)
                    cfg.children.append(prev.id)
                    prev._parent_cfgs.append(idx)
            else:
                # if task has no parents at all and has unit < max_timescale
                assert task.unit < max_timescale
                assert task._parent is None

                prev: Task | None = None
                # we create all parents starting from right above the task ->
                # max_timescale
                for i in range(0, task_unit_idx):
                    unit = scales[i]
                    tmp = Task(self, unit)
                    self.temp_tasks.add(tmp.id)

                    if prev is not None:
                        prev.add_cost_config_children(ZERO_COST_ALWAYS, [tmp])
                    prev = tmp

                # since task timescale cannot be index 0
                assert prev is not None

                # the last prev will be the parent closest to the task timescale
                prev.add_cost_config_children(ZERO_COST_ALWAYS, [task])

    def build(self) -> Config:
        self.__create_tmp_parents()

        timescales: list[atomic_unit] = list(self.timescales)

        task_configs: dict[int, TaskConfig] = {}
        for t in self.tasks.values():
            task_configs[t.id] = t.config()

        return Config(
            horizon=self.horizon,
            timescales=timescales,
            tasks=task_configs,
        )
