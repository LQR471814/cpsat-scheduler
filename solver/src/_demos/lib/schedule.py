from sys import stderr

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
from math import ceil

from cpsatmodel.config import Solution


zero_duration = timedelta()
atomic_unit_timedelta = timedelta(seconds=15 * 60)


def grey_text(text: str) -> str:
    return f"\033[90m{text}\033[0m"


class Round(Enum):
    UP = "up"
    DOWN = "down"


class Schedule:
    horizon: tuple[datetime, datetime]
    task_names: dict[int, str]
    events: set[int]
    builder: ConfigBuilder
    timescales: set[atomic_unit]

    def __init__(self, horizon: tuple[datetime, datetime]) -> None:
        self.horizon = horizon
        self.task_names = {}
        self.timescales = set()
        self.events = set()
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
        assert ts >= self.horizon[0]
        assert ts <= self.horizon[1]
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
        if start_before is not None and start_before < self.horizon[0]:
            raise Exception("start_before cannot be before horizon lower bound")
        if start_after is not None and start_after > self.horizon[1]:
            raise Exception("start_after cannot be after horizon upper bound")

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
        if end < self.horizon[0]:
            raise Exception("end cannot be before horizon lower bound")
        if start > self.horizon[1]:
            raise Exception("start cannot be after horizon upper bound")

        # --- Sleep start: AtomicUnit(198) end: AtomicUnit(232)
        # start AtomicUnit(198) ( Quantity(192) Quantity(208) )
        # end AtomicUnit(232) ( Quantity(224) Quantity(240) )
        #
        # --- Breakfast start: AtomicUnit(234) end: AtomicUnit(235)
        # start AtomicUnit(234) ( Quantity(224) Quantity(240) )
        #
        # --- Work start: AtomicUnit(236) end: AtomicUnit(254)
        # start AtomicUnit(236) ( Quantity(224) Quantity(240) )
        # end AtomicUnit(254) ( Quantity(240) Quantity(256) )

        # events:
        # 198 -> 232: A
        # 234 -> 235: B
        # 236 -> 254: C

        # blocks:
        # 192 -> 208 (16): A(10)
        # 208 -> 224 (16): A(16)
        # 224 -> 240 (16): A(8) + B(1) + C(4)
        # 240 -> 256 (16): C(14)

        # we calculate the timescale units it occupies and create the
        # appropriate tasks (for the smallest timescale unit)

        # this gives the timescale instance which the event starts within
        #
        # we round down, worst case we start before the event actually starts
        task_start = self.schedule_time(start)

        # we round down so we don't accidentally make the event longer and
        # cause overflow that doesn't actually exist
        task_end = self.schedule_time(end)

        current_inst = task_start - (task_start % unit)

        while current_inst < task_end:
            next_inst = current_inst + unit

            # we have 4 cases:
            # start & end both in current instance -> alloc = end - start
            # start in current instance            -> alloc = next - start
            # end in current instance              -> alloc = end - current
            # neither in current instance          -> alloc = unit

            start_in_inst = current_inst < task_start and task_start < next_inst
            end_in_inst = current_inst < task_end and task_end < next_inst

            alloc = unit
            if start_in_inst and end_in_inst:
                alloc = task_end - task_start
            elif start_in_inst:
                alloc = next_inst - task_start
            elif end_in_inst:
                alloc = task_end - current_inst

            t = Task(
                builder=self.builder,
                unit=unit,
                start=task_unit(current_inst // unit),
                end=task_unit(next_inst // unit),
            )
            self.events.add(t.id)

            t.add_cost_config_duration(cost_topo.constant(0), alloc)
            self.task_names[t.id] = name
            self.timescales.add(unit)

            current_inst += unit

    def print_solution(self, solution: Solution):
        status = solution.status
        total_cost = solution.cost
        tasks = solution.tasks

        if status != cp_model.OPTIMAL and status != cp_model.FEASIBLE:
            print("failed to solve!", status)
            return

        print(status, "cost:", total_cost)

        for unit in self.timescales:
            unit_name = timescale_names[unit]
            in_unit = [
                s
                for s in tasks
                # don't show if temp task
                if s.task_id not in self.builder.temp_tasks
                # don't show if task has no duration
                and s.real_duration > atomic_unit(0)
                # only choose tasks of this unit
                and self.builder.tasks[s.task_id].unit == unit
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

                    name = self.task_names[task.id]

                    start_date = self.real_time(int(s.start) * unit)
                    end_date = self.real_time(s.real_end)
                    dur = self.real_duration(s.real_duration)

                    hours, rem = divmod(dur.total_seconds(), 3600)
                    minutes, _ = divmod(rem, 60)

                    line = "\t".join(
                        [
                            f"{name}",
                            f"id: {s.task_id}",
                            f"start: {start_date} ({s.start})",
                            f"end: {end_date}",
                            f"cfg: {s.config}",
                            f"cost: {s.real_cost}",
                            f"dur: {int(hours)}:{int(minutes):02}",
                        ]
                    )
                    print(
                        grey_text(line) if task.id in self.events else line,
                    )

    def json_solution(self, solution: Solution):
        tasks = []
        for s in solution.tasks:
            if s.task_id in self.builder.temp_tasks:
                continue
            if s.real_duration == atomic_unit(0):
                continue
            t = self.builder.tasks[s.task_id]
            start_date = self.real_time(int(s.start) * t.unit)
            end_date = self.real_time(s.real_end)
            dur = self.real_duration(s.real_duration)
            tasks.append(
                {
                    "id": t.id,
                    "unit": int(timedelta(minutes=15 * int(t.unit)).total_seconds()),
                    "name": self.task_names[t.id],
                    "start": start_date.isoformat(),
                    "end": end_date.isoformat(),
                    "duration": int(dur.total_seconds()),
                    "config": s.config,
                }
            )
        return {
            "status": solution.status.name,
            "cost": solution.cost,
            "tasks": tasks,
        }

    def solve(self):
        cfg = self.builder.build()
        model = Model(cfg)

        cpmodel = model.make_cpmodel()

        proto = cpmodel.Proto()
        print(
            "solving...",
            "variables:",
            len(proto.variables),
            "constraints:",
            len(proto.constraints),
            file=stderr,
        )

        return model.solve(cpmodel)
