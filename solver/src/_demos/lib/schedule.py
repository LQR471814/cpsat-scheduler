from cpsatmodel import (
    ScheduledTask,
    Model,
    ConfigBuilder,
    Task,
    atomic_unit,
    task_unit,
)
from ortools.sat.python import cp_model
from _demos.lib.units import timescale_names
from datetime import datetime, timedelta
from enum import Enum
from math import ceil


atomic_unit_timedelta = timedelta(seconds=15 * 60)


class Round(Enum):
    UP = "up"
    DOWN = "down"


class Schedule:
    horizon: tuple[datetime, datetime]
    task_names: dict[int, str]
    builder: ConfigBuilder
    timescales: set[atomic_unit]

    def __init__(self, horizon: tuple[datetime, datetime]) -> None:
        self.horizon = horizon
        self.task_names = {}
        self.timescales = set()
        self.builder = ConfigBuilder(
            (
                atomic_unit(0),
                self.horizon_time(horizon[1]),
            )
        )

    def horizon_time(self, ts: datetime, round: Round = Round.DOWN) -> atomic_unit:
        if round == Round.UP:
            return atomic_unit(
                ceil((ts - self.horizon[0]).seconds / atomic_unit_timedelta.seconds)
            )
        return atomic_unit(
            (ts - self.horizon[0]).seconds // atomic_unit_timedelta.seconds
        )

    def task(
        self,
        name: str,
        unit: atomic_unit,
        start_after: datetime | None = None,
        start_before: datetime | None = None,
    ):
        t = Task(
            self.builder,
            unit,
            task_unit(self.horizon_time(start_after, round=Round.UP) // unit)
            if start_after is not None
            else None,
            task_unit(self.horizon_time(start_before, round=Round.DOWN) // unit)
            if start_before is not None
            else None,
        )
        self.task_names[t.id] = name
        self.timescales.add(unit)
        return t

    def event(self, name: str, start: datetime, end: datetime):
        pass

    def solve(self):
        cfg = self.builder.build()
        model = Model(cfg)
        status, total_cost, solution_tasks = model.solve()

        if status != cp_model.OPTIMAL and status != cp_model.FEASIBLE:
            print("failed to solve!", status)
            return

        print(status, "cost:", total_cost)

        for unit in self.timescales:
            unit_name = timescale_names[unit]
            in_unit = [
                s for s in solution_tasks if self.builder.tasks[s.task_id].unit == unit
            ]

            if len(in_unit) == 0:
                continue

            groups: dict[task_unit, list[ScheduledTask]] = {}
            for s in in_unit:
                if s.start not in groups:
                    groups[s.start] = []
                groups[s.start].append(s)

            print(f"\n\nUNIT --- {unit_name} ({unit} atomic units)\n")

            for starting_time in sorted(groups.keys()):
                print(f"\nUnit {starting_time}:")

                for s in groups[starting_time]:
                    task = self.builder.tasks[s.task_id]

                    name = ""
                    if task.id in self.task_names:
                        name = self.task_names[task.id]
                    else:
                        assert task.id in self.builder.temp_tasks
                        name = f"__temp_{task.id}__"

                    print(
                        f"{name}\tid: {s.task_id}\tstart: {s.start}\tcost: {s.real_cost}\tdur: {s.real_duration}\tend: {s.real_end}\tcfg: {s.config}",
                    )
