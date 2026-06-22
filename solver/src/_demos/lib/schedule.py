from _demos.lib import cost_topo
from cpsatmodel import (
    ScheduledTask,
    Model,
    ConfigBuilder,
    Task,
    atomic_unit,
    task_unit,
)
from ortools.sat.python import cp_model
from _demos.lib.units import timescale_names, hour_4
from datetime import datetime, timedelta
from enum import Enum
from math import ceil, floor


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
                self.schedule_time(horizon[1]),
            )
        )

    def schedule_duration(
        self, dur: timedelta, round: Round = Round.DOWN
    ) -> atomic_unit:
        if round == Round.UP:
            return atomic_unit(ceil(dur / atomic_unit_timedelta))
        return atomic_unit(dur // atomic_unit_timedelta)

    def schedule_time(self, ts: datetime, round: Round = Round.DOWN) -> atomic_unit:
        if round == Round.UP:
            return atomic_unit(ceil((ts - self.horizon[0]) / atomic_unit_timedelta))
        return atomic_unit((ts - self.horizon[0]) // atomic_unit_timedelta)

    def real_time(self, t: atomic_unit) -> datetime:
        return self.horizon[0] + self.real_duration(t)

    def real_duration(self, t: atomic_unit) -> timedelta:
        return int(t) * atomic_unit_timedelta

    def task(
        self,
        name: str,
        unit: atomic_unit,
        start_after: datetime | None = None,
        start_before: datetime | None = None,
    ):
        start = (
            # we round up because worst case, we limit to after the true start_after
            task_unit(self.schedule_time(start_after, round=Round.UP) // unit)
            if start_after is not None
            else None
        )
        end = (
            # we round down because worst case, we limit to before the true start_before
            task_unit(self.schedule_time(start_before, round=Round.DOWN) // unit)
            if start_before is not None
            else None
        )

        t = Task(
            builder=self.builder,
            unit=unit,
            start=start,
            end=end,
        )
        self.task_names[t.id] = name
        self.timescales.add(unit)
        return t

    def event(self, name: str, start: datetime, end: datetime, unit=hour_4):
        # we calculate the timescale units it occupies and create the
        # appropriate tasks (for the smallest timescale unit)

        # this gives the timescale instance which the event starts within
        #
        # we round down, worst case we start before the event actually starts
        task_time = task_unit(self.schedule_time(start) // unit)

        # round up because worst case we want to have more time than is
        # strictly necessary for the event
        duration_remaining = self.schedule_duration(end - start, round=Round.UP)

        i = 0
        while duration_remaining > atomic_unit(0):
            alloc = unit

            task_current = task_time + task_unit(i)
            task_next = task_time + task_unit(i + 1)

            instance_start = self.real_time(int(task_current) * unit)
            instance_end = self.real_time(int(task_next) * unit)

            # if task starts after timescale instance starts
            if start > instance_start:
                # we only allocate part after starting (subtract extra prefix)
                alloc -= self.schedule_duration(start - instance_start)
            elif instance_end > end:
                # we only allocate part before ending (subtract extra suffix)
                alloc -= self.schedule_duration(instance_end - end)

            t = Task(
                builder=self.builder,
                unit=unit,
                start=task_current,
                end=task_next,
            )
            t.add_cost_config_duration(cost_topo.constant(0), alloc)
            self.task_names[t.id] = name
            self.timescales.add(unit)

            duration_remaining -= alloc
            i += 1

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
                time = self.real_time(int(starting_time) * unit)

                print(f"\nStart {time} | {starting_time}:")

                for s in groups[starting_time]:
                    task = self.builder.tasks[s.task_id]

                    name = ""
                    if task.id in self.task_names:
                        name = self.task_names[task.id]
                    else:
                        assert task.id in self.builder.temp_tasks
                        name = f"__temp_{task.id}__"

                    start_date = self.real_time(int(s.start) * unit)
                    end_date = self.real_time(s.real_end)
                    dur = self.real_duration(s.real_duration)

                    hours, rem = divmod(dur.total_seconds(), 3600)
                    minutes, _ = divmod(rem, 60)

                    print(
                        "\t".join(
                            [
                                name,
                                f"id: {s.task_id}",
                                f"start: {start_date} ({s.start})",
                                f"end: {end_date}",
                                f"cfg: {s.config}",
                                f"cost: {s.real_cost}",
                                f"dur: {int(hours)}:{int(minutes):02}",
                            ]
                        ),
                    )
