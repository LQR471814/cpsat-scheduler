from __future__ import annotations
from typing import Self
from config import CostInterval, ParentCond, CostConfig, Config, TaskConfig


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
            # each child must not already be a child of another task
            for cond in c._parent_conds:
                assert cond.id == self.id
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
                parent_conditions=t._parent_conds,
            )
        return Config(timescales=timescales, tasks=task_configs)
