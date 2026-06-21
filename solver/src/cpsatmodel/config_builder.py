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
        start: task_unit | None = None,
        end: task_unit | None = None,
    ) -> None:
        builder.next_id += 1
        builder.tasks[builder.next_id] = self
        builder.timescales.add(unit)

        self._configs = []
        self._prerequisites = []
        self._parent = None
        self._parent_cfgs = []
        self._builder = builder

        self.id = builder.next_id
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


class ConfigBuilder:
    def __init__(self, horizon: tuple[atomic_unit, atomic_unit]):
        self.horizon = horizon
        self.next_id = 0
        self.timescales: set[atomic_unit] = set()
        # margin will not be auto-created, the user is in charge of specifying magin
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

    def __ensure_parents(self):
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
            if len(task._parent_cfgs) > 0:
                continue
            if task.unit == max_timescale:
                continue

            assert task.unit < max_timescale

            prev: Task | None = None
            # we create all parents starting from right above the task ->
            # max_timescale
            for i in range(0, scales.index(task.unit)):
                unit = scales[i]
                tmp = Task(self, unit)
                self.temp_tasks.add(tmp.id)

                if prev is not None:
                    prev.add_cost_config_children(
                        [CostInterval((atomic_unit(0), atomic_unit(maxsize - 1)), 0)],
                        [tmp],
                    )
                prev = tmp

            # since task timescale cannot be index 0
            assert prev is not None

            # the last prev will be the parent closest to the task timescale
            prev.add_cost_config_children(
                [CostInterval((atomic_unit(0), atomic_unit(maxsize - 1)), 0)],
                [task],
            )

    def build(self) -> Config:
        self.__ensure_parents()

        timescales: list[atomic_unit] = list(self.timescales)
        task_configs: dict[int, TaskConfig] = {}
        for id in self.tasks:
            t = self.tasks[id]
            task_configs[id] = TaskConfig(
                id=id,
                timescale_unit=t.unit,
                start=t.start,
                end=t.end,
                prerequisites=t._prerequisites,
                cost_configs=t._configs,
                parent_configs=t._parent_cfgs,
                parent=t._parent,
            )
        return Config(
            horizon=self.horizon,
            timescales=timescales,
            tasks=task_configs,
        )
