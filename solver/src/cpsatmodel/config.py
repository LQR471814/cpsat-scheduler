from __future__ import annotations

from dataclasses import dataclass
from typing import Callable
from ortools.sat.python import cp_model, cp_model_helper as cmh
from cpsatmodel.print import print_vars
from functools import cache
import sys
from cpsatmodel.units import atomic_unit, task_unit


def guard_bool(
    model: cp_model.CpModel,
    name: str,
    cond_true: cp_model.BoundedLinearExpression | bool,
    cond_false: cp_model.BoundedLinearExpression | bool,
) -> cp_model.IntVar:
    guard_var = model.new_bool_var(name)
    model.add(cond_true).only_enforce_if(guard_var).with_name(f"{name}_true")
    model.add(cond_false).only_enforce_if(guard_var.Not()).with_name(f"{name}_false")
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


@dataclass
class CostInterval:
    """
    The specified cost applies if the task's absolute end time is within the interval.
    """

    interval: tuple[atomic_unit, atomic_unit]
    cost: int


@dataclass
class ParentCond:
    # the id of the possible parent
    id: int
    # the cost config it must be under for the task for it to be considered the
    # parent
    config: int


@dataclass
class CostConfig:
    costs: list[CostInterval]
    children: list[int]
    duration: atomic_unit | None


@dataclass
class TaskConfig:
    id: int
    timescale_unit: atomic_unit
    cost_configs: list[CostConfig]
    prerequisites: list[int]
    start: task_unit | None
    end: task_unit | None
    parent: int | None
    parent_configs: list[int]


@dataclass
class Config:
    horizon: tuple[atomic_unit, atomic_unit]
    timescales: list[atomic_unit]
    # margin will not be auto-created, the user is in charge of specifying magin
    # ids -> TaskConfig
    tasks: dict[int, TaskConfig]


@dataclass
class ModelProps:
    max_timescale: atomic_unit
    max_scaling_factor: atomic_unit

    def __init__(self, cfg: Config) -> None:
        self.max_timescale = max(cfg.timescales)
        self.max_scaling_factor = self.__get_max_scaling_factor(cfg)

    def __get_max_scaling_factor(self, config: Config) -> atomic_unit:
        max_scaling_factor = 1
        sorted_timescales = sorted(config.timescales)
        prev = sorted_timescales[0]
        for u in sorted_timescales[1:]:
            scale = u // prev
            if scale > max_scaling_factor:
                max_scaling_factor = scale
        return atomic_unit(max_scaling_factor)


class TaskProps:
    __props: Props

    def __init__(self, props: Props) -> None:
        self.__props = props

        self.resolve_scaling_factor: Callable[[int], atomic_unit | None] = cache(
            self.__get_scaling_factor
        )
        self.resolve_start_bounds: Callable[[int], tuple[task_unit, task_unit]] = cache(
            self.__compute_start_bounds
        )
        self.resolve_cost_bounds: Callable[[int], tuple[int, int]] = cache(
            self.__compute_cost_bounds
        )
        self.resolve_real_dur_bounds: Callable[
            [int], tuple[atomic_unit, atomic_unit]
        ] = cache(self.__compute_dur_bounds)
        self.resolve_real_end_bounds: Callable[
            [int], tuple[atomic_unit, atomic_unit]
        ] = cache(self.__compute_real_end_bounds)
        self.resolve_parent_cfg: Callable[[int], TaskConfig | None] = cache(
            self.__get_parent_cfg
        )

    def __get_task_cfg(self, task_id: int) -> TaskConfig:
        return self.__props._config.tasks[task_id]

    def __get_scaling_factor(self, task_id: int) -> atomic_unit | None:
        parent = self.resolve_parent_cfg(task_id)
        if parent is None:
            return None
        t = self.__get_task_cfg(task_id)
        return atomic_unit(parent.timescale_unit // t.timescale_unit)

    def __get_parent_cfg(self, task_id: int) -> TaskConfig | None:
        t = self.__get_task_cfg(task_id)
        if t.parent is None:
            return None
        return self.__props._config.tasks[t.parent]

    def __compute_start_bounds(self, task_id: int) -> tuple[task_unit, task_unit]:
        t = self.__get_task_cfg(task_id)

        # we derive bounds for this task's start from the parent
        bound_from_parent: tuple[task_unit, task_unit]
        if t.timescale_unit == self.__props.model.max_timescale:
            # horizon is parent if task is maximum timescale
            horizon_lb, horizon_ub = self.__props._config.horizon
            # we bound task start in terms of horizon lb/ub (which are in
            # terms of atomic unit)
            bound_from_parent = (
                task_unit(horizon_lb // t.timescale_unit),
                task_unit(horizon_ub // t.timescale_unit),
            )
        else:
            parent = self.resolve_parent_cfg(task_id)
            # we assume there is always a parent if below max timescale
            # (because temp tasks exist)
            assert parent is not None
            parent_lb, parent_ub = self.resolve_start_bounds(parent.id)
            parent_unit = self.__props._config.tasks[parent.id].timescale_unit
            # we convert parent's task unit into our task's unit
            bound_from_parent = (
                task_unit(int(parent_lb) * parent_unit // t.timescale_unit),
                task_unit(int(parent_ub) * parent_unit // t.timescale_unit),
            )

        start, end = bound_from_parent

        if t.start is not None:
            # explicit start cannot go outside parent bounds
            assert t.start >= bound_from_parent[0]
            assert t.start < bound_from_parent[1]
            start = t.start

        # it is okay to implicitly move the end constraint forward here because
        # technically all it says is that the task *must start* before this
        # date. if parent gives a tighter bound, it must abide
        if t.end is not None and t.end < bound_from_parent[1]:
            assert t.end > start
            end = t.end

        return (start, end)

    def __compute_real_end_bounds(
        self, task_id: int
    ) -> tuple[atomic_unit, atomic_unit]:
        t = self.__get_task_cfg(task_id)

        start_lb, start_ub = self.resolve_start_bounds(task_id)

        # convert start/end in terms of atomic unit
        start_lb = int(start_lb) * t.timescale_unit
        start_ub = int(start_ub) * t.timescale_unit

        # we find the minimum and maximum possible value for real_end

        min_end: atomic_unit = atomic_unit(sys.maxsize)
        max_end: atomic_unit = atomic_unit(0)

        for cfg in t.cost_configs:
            if len(cfg.children) == 0:
                assert cfg.duration is not None

                # we find the next timescale unit after the starting
                # lower/upper bound, which are the maximum and minimum values
                # for the real_end of the task (it cannot be possibly be
                # scheduled off the grid)

                end_lb = start_lb + t.timescale_unit
                if end_lb < min_end:
                    min_end = end_lb

                end_ub = start_ub + t.timescale_unit
                if end_ub > max_end:
                    max_end = end_ub

                continue

            for child in cfg.children:
                end_lb, end_ub = self.resolve_real_end_bounds(child)
                if end_lb < min_end:
                    min_end = end_lb
                if end_ub > max_end:
                    max_end = end_ub

        return (min_end, max_end)

    def __compute_cost_bounds(self, task_id: int) -> tuple[int, int]:
        t = self.__get_task_cfg(task_id)

        min_cost = sys.maxsize
        max_cost = -sys.maxsize
        for cfg in t.cost_configs:
            for intv in cfg.costs:
                if intv.cost < min_cost:
                    min_cost = intv.cost
                if intv.cost > max_cost:
                    max_cost = intv.cost

        return (min_cost, max_cost)

    def __compute_dur_bounds(self, task_id: int) -> tuple[atomic_unit, atomic_unit]:
        # non-leaf task: real duration = sum{children durations}
        # leaf task: real duration = chosen duration
        #
        # therefore:
        #
        # non-leaf task: max(real duration) = sum{max for each child duration}
        # leaf task: max(duration)

        t = self.__get_task_cfg(task_id)

        min_dur: atomic_unit = atomic_unit(sys.maxsize)
        max_dur: atomic_unit = atomic_unit(0)
        for cfg in t.cost_configs:
            if cfg.duration is not None:
                if cfg.duration > max_dur:
                    max_dur = cfg.duration
                if cfg.duration < min_dur:
                    min_dur = cfg.duration
                continue

            min_dur_sum = atomic_unit(0)
            max_dur_sum = atomic_unit(0)
            for child in cfg.children:
                lb, ub = self.resolve_real_dur_bounds(child)
                min_dur_sum = min_dur_sum + lb
                max_dur_sum = max_dur_sum + ub

            if min_dur_sum < min_dur:
                min_dur = min_dur_sum
            if max_dur_sum > max_dur:
                max_dur = max_dur_sum

        return (min_dur, max_dur)


# Props computes static properties of the config and tasks
class Props:
    _config: Config

    model: ModelProps
    task: TaskProps

    def __init__(self, config: Config) -> None:
        self._config = config
        self.model = ModelProps(config)
        self.task = TaskProps(self)


class DecisionState:
    # start is in terms of the task's unit
    start: cmh.IntVar
    config_select: cmh.IntVar

    def __init__(self, model: cp_model.CpModel, props: Props, t: TaskConfig) -> None:
        start_lb, start_ub = props.task.resolve_start_bounds(t.id)
        # we subtract by 1 because new_int_var is inclusive with its end and we
        # want the ub to be strictly not included
        self.start = model.new_int_var(int(start_lb), int(start_ub) - 1, f"t{t.id}_st")
        self.config_select = model.new_int_var(
            0, len(t.cost_configs) - 1, f"t{t.id}_cfg"
        )


class ComputedState:
    real_end: cmh.IntVar
    # the actual duration chosen out of the possible cost configurations
    real_duration: cmh.IntVar
    # the actual cost chosen out of the possible cost configurations and 0 if
    # the task can possibly be deactivated
    real_cost: cmh.IntVar
    # this should be a one hot
    configs_active: list[cmh.IntVar]
    # this is in terms of the child's task unit
    parent_start: cmh.IntVar | int
    # this is a boolean
    parent_active: cmh.IntVar | None

    def __init__(
        self,
        m: Model,
        t: TaskConfig,
    ) -> None:
        self.m = m
        self.t = t
        self.__setup_vars(m, t)

    def setup_constraints(self):
        self.__setup_par_constrain(self.m, self.t)
        self.__setup_real_dur(self.m, self.t)
        self.__setup_real_end(self.m, self.t)

    def __setup_vars(self, m: Model, t: TaskConfig):
        props = m.props
        model = m.model
        state = m.decision_vars[t.id]

        dur_lb, dur_ub = props.task.resolve_real_dur_bounds(t.id)
        self.real_duration = model.new_int_var_from_domain(
            # we always include 0 because all real duration has the possibility
            # of becoming 0 if the parent is not active
            cp_model.Domain(int(dur_lb), int(dur_ub)).union_with(
                cp_model.Domain.from_values([0])
            ),
            f"t{t.id}_real_dur",
        )

        # non-leaf task: real end = max{child end times}
        # leaf task: real end = next unit after start
        end_lb, end_ub = props.task.resolve_real_end_bounds(t.id)
        self.real_end = model.new_int_var(int(end_lb), int(end_ub), f"t{t.id}_real_end")

        # should compute min/max per task
        cost_lb, cost_ub = props.task.resolve_cost_bounds(t.id)
        self.real_cost = model.new_int_var(cost_lb, cost_ub, f"t{t.id}_real_cost")

        if t.parent is not None:
            # we assume all tasks have parent (except those of max timescale)
            parent_start_lb: task_unit
            parent_start_ub: task_unit
            if t.timescale_unit < props.model.max_timescale:
                parent = props.task.resolve_parent_cfg(t.id)
                assert parent is not None
                # this returns both values in terms of parent's task unit
                parent_start_lb, parent_start_ub = props.task.resolve_start_bounds(
                    parent.id
                )
                # therefore we convert both to the child's unit
                scaling_factor = parent.timescale_unit // t.timescale_unit
                parent_start_lb *= scaling_factor
                parent_start_ub *= scaling_factor
            else:
                parent_start_lb = task_unit(0)
                parent_start_ub = task_unit(0)

            self.parent_active = model.new_bool_var(f"t{t.id}_parent_active")
            self.parent_start = model.new_int_var(
                int(parent_start_lb), int(parent_start_ub), f"t{t.id}_parent_start"
            )
        else:
            self.parent_active = None
            self.parent_start = 0

        # we do not self.parent_active because it involves a lot of extra bools
        # that need to be constructed (you cannot use linear expressions like
        # == inside of a add_bool_or)
        self.configs_active = [
            guard_bool(
                model,
                f"t{t.id}_cfg{idx}_active",
                state.config_select == idx,
                state.config_select != idx,
            )
            for idx in range(len(t.cost_configs))
        ]

    def __setup_par_constrain(self, m: Model, t: TaskConfig):
        # both parent_active and parent_start will be constants if parent is null
        parent = m.props.task.resolve_parent_cfg(t.id)
        if parent is None:
            return

        assert isinstance(self.parent_active, cmh.IntVar)
        assert isinstance(self.parent_start, cmh.IntVar)

        parent_state = m._resolve_computed_state(parent.id)

        # parent active is true when at least one (and in this case, exactly
        # one) of parent_configs is active
        par_active_cfgs: list[cmh.Literal] = [
            parent_state.configs_active[c] for c in t.parent_configs
        ]
        m.model.add_bool_or(*par_active_cfgs).with_name(
            f"t{t.id}_parent_active"
        ).only_enforce_if(self.parent_active)
        m.model.add_bool_and(*[v.Not() for v in par_active_cfgs]).only_enforce_if(
            self.parent_active.Not()
        ).with_name(f"t{t.id}_parent_inactive")

        # parent_start is computed from the parent's decision variable and a
        # constant scaling factor
        scaling_factor = m.props.task.resolve_scaling_factor(t.id)
        assert scaling_factor is not None  # parent is not None
        parent_start_var = m.decision_vars[parent.id].start
        m.model.add(
            self.parent_start == parent_start_var * int(scaling_factor)
        ).with_name(f"t{t.id}_parent_start")

    def __setup_real_end(self, m: Model, t: TaskConfig):
        unit = t.timescale_unit
        decision = m.decision_vars[t.id]
        start_time = decision.start

        for i, cfg in enumerate(t.cost_configs):
            children = cfg.children
            config_active = self.configs_active[i]

            if len(children) > 0:  # O(task)
                # define real end time as max of children end times
                child_end_times = [
                    m._resolve_computed_state(c).real_end for c in children
                ]
                m.model.add_max_equality(
                    self.real_end, child_end_times
                ).only_enforce_if(config_active).with_name(
                    f"t{t.id}_real_end_cfg{i}_child"
                )
                continue

            # O(cost config * task)

            m.model.add(self.real_end == int(unit) * (start_time + 1)).only_enforce_if(
                config_active
            ).with_name(f"t{t.id}_real_end_cfg{i}_duration")

    def __setup_real_dur(self, m: Model, t: TaskConfig):
        if isinstance(self.parent_active, cmh.IntVar):
            # set real duration to 0 if task config is orphaned
            m.model.add(self.real_duration == 0).only_enforce_if(
                self.parent_active.Not()
            )

        for i, cfg in enumerate(t.cost_configs):
            config_active = self.configs_active[i]

            if len(cfg.children) > 0:  # O(task)
                # define real duration as sum of children
                sum_child_dur_expr = 0
                for c in cfg.children:
                    sum_child_dur_expr += m._resolve_computed_state(c).real_duration
                m.model.add(self.real_duration == sum_child_dur_expr).with_name(
                    f"t{t.id}_real_duration_cfg{i}_child"
                ).only_enforce_if(config_active)
                continue

            # O(cost config * task)

            # define real duration as function of selected cost config
            assert cfg.duration is not None

            if isinstance(self.parent_active, cmh.IntVar):
                m.model.add(self.real_duration == cfg.duration).with_name(
                    f"t{t.id}_real_duration_cfg{i}_duration"
                ).only_enforce_if(self.parent_active, config_active)
            else:
                # this is root task, duration always enforced
                m.model.add(self.real_duration == cfg.duration).with_name(
                    f"t{t.id}_real_duration_cfg{i}_duration"
                ).only_enforce_if(config_active)


@dataclass
class ScheduledTask:
    task_id: int
    start: task_unit
    real_cost: int
    real_duration: atomic_unit
    real_end: atomic_unit
    # this is the index of the cost config chosen
    config: int


class Model:
    config: Config

    def __init__(self, config: Config):
        self.config = config

    # setup

    def _resolve_computed_state(self, t: int) -> ComputedState:
        if t in self.computed_vars:
            return self.computed_vars[t]
        state = ComputedState(self, self.config.tasks[t])
        self.computed_vars[t] = state
        return state

    def __start_end_constraints(self, t: TaskConfig):
        decision = self.decision_vars[t.id]
        computed = self.computed_vars[t.id]

        # define parent start/end constraints (tautalogy if not specified)
        parent = self.props.task.resolve_parent_cfg(t.id)

        # if root task, do not need to enforce any particular start/end
        # constraint, already covered by static lb/ub
        if parent is None:
            return

        # parent_start_var = computed.parent_start
        # parent_not_root = parent is not None
        scaling_factor = self.props.task.resolve_scaling_factor(t.id)
        assert scaling_factor is not None  # parent is not None

        self.model.add(decision.start >= computed.parent_start).only_enforce_if(
            computed.parent_active
        )

        # 1. scaling_factor := # of child unit which = 1 parent unit
        # 2. parent_start is in terms of the child unit
        # 3. parent_start + scaling_factor = parent_end
        self.model.add(
            decision.start < computed.parent_start + int(scaling_factor)
        ).only_enforce_if(computed.parent_active)

    def __prereq_constraints(self, t: TaskConfig):
        start_var = self.decision_vars[t.id].start
        for p in t.prerequisites:
            p_real_end_var = self.computed_vars[p].real_end
            self.model.add(p_real_end_var <= start_var * int(t.timescale_unit))

    def __timescale_overflow_constraints(self, t: TaskConfig):
        defined = self.computed_vars[t.id].real_duration
        start_var = self.decision_vars[t.id].start

        sum = defined
        # O(n^2) for n tasks in the same timescale!
        for other_id, other_task in self.config.tasks.items():
            if other_id == t.id:
                continue
            if other_task.timescale_unit != t.timescale_unit:
                continue

            key = frozenset((t.id, other_id))
            if key not in self.computed_pair_aligned_forward:
                other_start_var = self.decision_vars[other_id].start
                self.computed_pair_aligned_forward[key] = guard_bool(
                    self.model,
                    f"t{t.id}_t{other_id}_same_start",
                    other_start_var == start_var,
                    other_start_var != start_var,
                )
            is_aligned = self.computed_pair_aligned_forward[key]

            _, other_dur_ub = self.props.task.resolve_real_dur_bounds(other_id)
            other_dur_contrib = self.model.new_int_var(
                # we use 0 because other_dur_contrib could possibly be 0 (if inactive)
                0,
                int(other_dur_ub),
                f"t{t.id}_other{other_id}_term",
            )
            other_dur = self.computed_vars[other_id].real_duration
            self.model.add(other_dur_contrib == other_dur).only_enforce_if(is_aligned)
            self.model.add(other_dur_contrib == 0).only_enforce_if(is_aligned.Not())

            sum += other_dur_contrib

        self.model.add(sum <= t.timescale_unit)

    def __computed_costs(self, t: TaskConfig):
        computed = self.computed_vars[t.id]
        real_end_time = computed.real_end
        real_cost = computed.real_cost

        for i, cfg in enumerate(t.cost_configs):
            config_active = computed.configs_active[i]
            for j, intv in enumerate(cfg.costs):
                start, end = intv.interval
                cost_intv_after_start = guard_bool(
                    self.model,
                    f"t{t.id}_cfg{i}_intv{j}_after_start",
                    real_end_time >= start,
                    real_end_time < start,
                )
                cost_intv_before_end = guard_bool(
                    self.model,
                    f"t{t.id}_cfg{i}_intv{j}_before_end",
                    real_end_time <= end,
                    real_end_time > end,
                )
                self.model.add(real_cost == intv.cost).with_name(
                    f"t{t.id}_cfg{i}_intv{j}_real_cost_set"
                ).only_enforce_if(
                    config_active, cost_intv_after_start, cost_intv_before_end
                )

    def __objective_function(self):
        sum_cost_expr = 0
        for id in self.config.tasks:
            sum_cost_expr += self.computed_vars[id].real_cost
        self.model.minimize(sum_cost_expr)

    # in general, worst case: O(task * cost config * cost interval)
    def make_cpmodel(self) -> cp_model.CpModel:
        self.model = cp_model.CpModel()
        self.props = Props(self.config)

        # find worst-case max starting/ending time (for default upper-bound without knowing anything else)

        # init decision variables O(task)
        self.decision_vars: dict[int, DecisionState] = {}

        # init computed variables O(task)
        self.computed_vars: dict[int, ComputedState] = {}

        for t in self.config.tasks.values():
            state = DecisionState(self.model, self.props, t)
            self.decision_vars[t.id] = state

        for t in self.config.tasks.keys():
            self._resolve_computed_state(t)

        for t in self.config.tasks.keys():
            self._resolve_computed_state(t).setup_constraints()

        # add start/end constraints O(task)
        for t in self.config.tasks.values():
            self.__start_end_constraints(t)

        # add prereq constraints O(prereqs * task)
        for t in self.config.tasks.values():
            self.__prereq_constraints(t)

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

        self.computed_pair_aligned_forward: dict[frozenset[int], cp_model.IntVar] = {}

        for t in self.config.tasks.values():
            self.__timescale_overflow_constraints(t)

        # add computed costs O(cost config * cost interval * task)
        for t in self.config.tasks.values():
            self.__computed_costs(t)

        # objective function O(task)
        self.__objective_function()

        return self.model

    def _debug(self):
        model = self.make_cpmodel()
        solver = cp_model.CpSolver()
        solver.parameters.log_search_progress = True
        solver.parameters.cp_model_presolve = True
        status = solver.solve(model)
        print_vars(
            model,
            solver,
            [self.decision_vars[t].config_select for t in self.config.tasks],
        )
        return (
            status,
            solver.ObjectiveValue(),
            [
                ScheduledTask(
                    task_id=t,
                    start=task_unit(solver.value(self.decision_vars[t].start)),
                    real_cost=solver.value(self.computed_vars[t].real_cost),
                    real_duration=atomic_unit(
                        solver.value(self.computed_vars[t].real_duration)
                    ),
                    real_end=atomic_unit(solver.value(self.computed_vars[t].real_end)),
                    config=solver.value(self.decision_vars[t].config_select),
                )
                for t in self.config.tasks
            ],
        )

    def solve(
        self,
        model: cp_model.CpModel,
    ) -> tuple[cp_model.CpSolverStatus, float, list[ScheduledTask]]:
        solver = cp_model.CpSolver()
        status = solver.solve(model)
        scheduled = [
            ScheduledTask(
                task_id=t,
                start=task_unit(solver.value(self.decision_vars[t].start)),
                real_cost=solver.value(self.computed_vars[t].real_cost),
                real_duration=atomic_unit(
                    solver.value(self.computed_vars[t].real_duration)
                ),
                real_end=atomic_unit(solver.value(self.computed_vars[t].real_end)),
                config=solver.value(self.decision_vars[t].config_select),
            )
            for t in self.config.tasks
        ]
        # assert_intrinsic_start_end(self.config, scheduled)
        # assert_non_overflow(self.config, scheduled)
        return (
            status,
            solver.ObjectiveValue(),
            scheduled,
        )


def assert_intrinsic_start_end(config: Config, scheduled: list[ScheduledTask]):
    for s in scheduled:
        task_cfg = config.tasks[s.task_id]
        if task_cfg.start is not None:
            assert s.start >= task_cfg.start
        if task_cfg.end is not None:
            assert s.start < task_cfg.end


def assert_non_overflow(config: Config, scheduled: list[ScheduledTask]):
    # maps: timescale unit -> timescale instance start dates -> duration filled
    unit_bucket_durations: dict[atomic_unit, dict[task_unit, atomic_unit]] = {}

    duration_dict: dict[int, atomic_unit] = {}
    scheduled_dict: dict[int, ScheduledTask] = {}
    for s in scheduled:
        scheduled_dict[s.task_id] = s

    def ensure_duration(id: int) -> atomic_unit:
        if id in duration_dict:
            return duration_dict[id]

        s = scheduled_dict[id]

        task_cfg = config.tasks[id]
        unit = task_cfg.timescale_unit
        if unit not in unit_bucket_durations:
            unit_bucket_durations[unit] = {}
        unit_buckets = unit_bucket_durations[unit]
        if s.start not in unit_buckets:
            unit_buckets[s.start] = atomic_unit(0)

        chosen_config = task_cfg.cost_configs[s.config]
        if chosen_config.duration is not None:
            duration_dict[id] = chosen_config.duration
            return chosen_config.duration

        sum = atomic_unit(0)
        for child in chosen_config.children:
            sum += ensure_duration(child)
        duration_dict[id] = sum
        return sum

    for s in scheduled:
        ensure_duration(s.task_id)

    for s in scheduled:
        unit = config.tasks[s.task_id].timescale_unit
        unit_bucket_durations[unit][s.start] += duration_dict[s.task_id]

    for unit in unit_bucket_durations:
        for filled in unit_bucket_durations[unit].values():
            assert filled <= unit
