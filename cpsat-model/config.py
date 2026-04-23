from dataclasses import dataclass
from ortools.sat.python import cp_model, cp_model_helper as cmh
from cpsat_demos.solution_printer import print_vars
import sys


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


@dataclass
class CostInterval:
    """
    The specified cost applies if the task's absolute end time is within the interval.
    """

    interval: tuple[int, int]
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
    duration: int | None


@dataclass
class TaskConfig:
    id: int
    timescale_unit: int
    cost_configs: list[CostConfig]
    prerequisites: list[int]
    start: int | None
    end: int | None
    parent_conditions: list[ParentCond]


@dataclass
class Config:
    timescales: list[int]
    # margin will not be auto-created, the user is in charge of specifying magin
    tasks: dict[int, TaskConfig]


@dataclass
class ModelProps:
    max_start_time: int
    max_end_time: int
    min_cost: int
    max_cost: int
    max_scaling_factor: int
    timescales_or_null_domain: cp_model.Domain


class DecisionState:
    start: cmh.IntVar
    config_select: cmh.IntVar

    def __init__(
        self,
        model: cp_model.CpModel,
        props: ModelProps,
        t: TaskConfig,
    ) -> None:
        start_lb = 0
        start_ub = props.max_start_time // t.timescale_unit
        if t.start is not None:
            start_lb = t.start
        if t.end is not None:
            start_ub = t.end - 1
        self.start = model.new_int_var(start_lb, start_ub, f"t{t.id}_st")
        self.config_select = model.new_int_var(
            0, len(t.cost_configs) - 1, f"t{t.id}_cfg"
        )


class ComputedState:
    real_end: cmh.IntVar
    real_duration: cmh.IntVar
    real_cost: cmh.IntVar
    # this should be a one hot
    configs_active: list[cmh.IntVar]
    parent_start: cmh.IntVar
    parent_unit: cmh.IntVar

    def __init__(
        self,
        state: DecisionState,
        model: cp_model.CpModel,
        props: ModelProps,
        t: TaskConfig,
    ) -> None:
        self.real_duration = model.new_int_var(0, props.max_end_time, f"t{t.id}_dur")
        self.real_end = model.new_int_var(0, props.max_end_time, f"t{t.id}_end")
        self.real_cost = model.new_int_var(
            props.min_cost, props.max_cost, f"t{t.id}_cost"
        )
        self.parent_start = model.new_int_var(
            0, props.max_start_time, f"t{t.id}_parent_start"
        )
        self.parent_unit = model.new_int_var_from_domain(
            props.timescales_or_null_domain, f"t{t.id}_parent_unit"
        )
        self.configs_active = [
            guard_bool(
                model,
                f"t{t.id}_cfg{i}_active",
                state.config_select == i,
                state.config_select != i,
            )
            for i in range(len(t.cost_configs))
        ]


@dataclass
class ScheduledTask:
    task_id: int
    # this is in terms of the task_unit
    start: int
    # this is in terms of the atomic unit, it may not be a multiple of task_unit
    real_end: int
    # this is the index of the cost config chosen
    config: int


def _cap_size(i: int):
    if i == sys.maxsize:
        return "∞"
    elif i == -sys.maxsize - 1:
        return "-∞"
    else:
        return str(i)


class Model:
    config: Config

    def __init__(self, config: Config):
        self.config = config

    # setup

    def __get_max_range(self):
        max_timescale = 0
        for t in self.config.tasks.values():
            if t.timescale_unit > max_timescale:
                max_timescale = t.timescale_unit
        max_timescale_count = 0
        for t in self.config.tasks.values():
            if t.timescale_unit == max_timescale:
                max_timescale_count += 1
        max_start_time = max_timescale * (max_timescale_count - 1)
        max_end_time = max_timescale * max_timescale_count
        return max_start_time, max_end_time

    def __get_cost_range(self):
        min_cost = 0
        max_cost = 0
        for t in self.config.tasks.values():
            for cfg in t.cost_configs:
                for intv in cfg.costs:
                    if intv.cost > max_cost:
                        max_cost = intv.cost
                    if intv.cost < min_cost:
                        min_cost = intv.cost
        return min_cost, max_cost

    def __get_max_scaling_factor(self):
        max_scaling_factor = 1
        prev = self.config.timescales[0]
        for u in self.config.timescales[1:]:
            scale = u // prev
            if scale > max_scaling_factor:
                max_scaling_factor = scale
        return max_scaling_factor

    def __init_model_props(self) -> ModelProps:
        max_start_time, max_end_time = self.__get_max_range()
        min_cost, max_cost = self.__get_cost_range()
        max_scaling_factor = self.__get_max_scaling_factor()
        timescales_or_null_domain = cp_model.Domain.from_values(
            [*self.config.timescales, 0]
        )
        return ModelProps(
            max_start_time,
            max_end_time,
            min_cost,
            max_cost,
            max_scaling_factor,
            timescales_or_null_domain,
        )

    def __setup_computed_duration_and_end(self, t: TaskConfig):
        unit = t.timescale_unit
        decision = self.decision_vars[t.id]
        computed = self.computed_vars[t.id]
        start_time = decision.start
        end_time = computed.real_end
        real_duration = computed.real_duration
        cost_config_active_bools = computed.configs_active

        for i, cfg in enumerate(t.cost_configs):
            children = cfg.children
            config_active = cost_config_active_bools[i]

            if len(children) > 0:  # O(task)
                # define real duration as sum of children
                real_duration_expr = 0
                for c in children:
                    dur = self.computed_vars[c].real_duration
                    real_duration_expr += dur

                self.model.add(real_duration == real_duration_expr).only_enforce_if(
                    config_active
                )

                # define real end time as max of children end times
                children_exprs = [self.computed_vars[c].real_end for c in children]
                self.model.add_max_equality(end_time, children_exprs).only_enforce_if(
                    config_active
                )
            else:  # O(cost config * task)
                # define real duration as function of selected cost config
                assert cfg.duration is not None
                defined = cfg.duration
                self.model.add(real_duration == defined).only_enforce_if(config_active)
                # define real end time as real start time + real duration
                self.model.add(
                    end_time == unit * start_time + real_duration
                ).only_enforce_if(config_active)

    def __setup_computed_parents(self, t: TaskConfig):
        computed = self.computed_vars[t.id]
        task_parent_unit = computed.parent_unit
        task_parent_start = computed.parent_start

        if len(t.parent_conditions) == 0:
            # indicates that task does not have parent
            self.model.add(task_parent_unit == 0)
            self.model.add(task_parent_start == 0)
            return

        for par_cond in t.parent_conditions:
            parent_unit = self.config.tasks[par_cond.id].timescale_unit
            parent_start = self.decision_vars[par_cond.id].start
            parent_cost_config_active = self.computed_vars[par_cond.id].configs_active[
                par_cond.config
            ]
            self.model.add(task_parent_unit == parent_unit).only_enforce_if(
                parent_cost_config_active
            )
            self.model.add(task_parent_start == parent_start).only_enforce_if(
                parent_cost_config_active
            )

    def __start_end_constraints(self, t: TaskConfig):
        task_unit = t.timescale_unit
        decision = self.decision_vars[t.id]
        computed = self.computed_vars[t.id]
        task_starting_var = decision.start

        # define parent start/end constraints (tautalogy if not specified)
        parent_unit = computed.parent_unit
        parent_start_var = computed.parent_start

        # 1. check parent not null
        parent_not_null = guard_bool(
            self.model,
            f"task_parent_not_null_{t.id}",
            parent_unit != 0,
            parent_unit == 0,
        )

        # 2. compute scaling factor (if par not null)
        scaling_factor = self.model.new_int_var(
            1, self.props.max_scaling_factor, f"scaling_factor_{t.id}"
        )
        self.model.add(parent_unit >= task_unit).only_enforce_if(parent_not_null)
        self.model.add_division_equality(
            scaling_factor, parent_unit, task_unit
        ).only_enforce_if(parent_not_null)

        # 3. compute parent start in the task's unit (if par not null)
        parent_start_converted = self.model.new_int_var(
            0, self.props.max_start_time, f"parent_start_converted_{t.id}"
        )
        self.model.add_multiplication_equality(
            parent_start_converted, scaling_factor, parent_start_var
        ).only_enforce_if(parent_not_null)

        # bound parent start and end
        self.model.add(task_starting_var >= parent_start_converted).only_enforce_if(
            parent_not_null
        )
        self.model.add(
            task_starting_var < parent_start_converted + scaling_factor
        ).only_enforce_if(parent_not_null)

        # # define intrinsic start/end constraints (tautalogy if not specified)
        # if t in self.config.task_start:
        #     print(task_starting_var >= self.config.task_start[t])
        #     model.add(task_starting_var >= self.config.task_start[t])
        # if t in self.config.task_end:
        #     print(task_starting_var < self.config.task_end[t])
        #     model.add(task_starting_var < self.config.task_end[t])

    def __prereq_constraints(self, t: TaskConfig):
        start_var = self.decision_vars[t.id].start
        for p in t.prerequisites:
            p_real_end_var = self.computed_vars[p].real_end
            self.model.add(p_real_end_var <= start_var)

    def __timescale_overflow_constraints(self, t: TaskConfig):
        defined = self.computed_vars[t.id].real_duration
        unit = t.timescale_unit  # this is also the max duration

        sum = defined
        for other in self.config.tasks:
            if other == t.id:
                continue
            if self.config.tasks[other].timescale_unit != unit:
                continue
            key = frozenset((t.id, other))

            if key not in self.computed_pair_aligned_forward:
                self.computed_pair_aligned_forward[frozenset((t.id, other))] = (
                    guard_bool(
                        self.model,
                        f"t{t.id}_t{other}_same_start",
                        self.decision_vars[other].start
                        == self.decision_vars[t.id].start,
                        self.decision_vars[other].start
                        != self.decision_vars[t.id].start,
                    )
                )

            is_aligned = self.computed_pair_aligned_forward[key]
            other_term = self.model.new_int_var(
                0, self.props.max_end_time, f"t{t.id}_other{other}_term"
            )
            self.model.add(
                other_term == self.computed_vars[other].real_duration
            ).only_enforce_if(is_aligned)
            self.model.add(other_term == 0).only_enforce_if(is_aligned.Not())
            sum += other_term

        self.model.add(sum <= unit)

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
                    f"t{t.id}_cfg{i}_intv{j}_before_start",
                    real_end_time >= start,
                    real_end_time < start,
                )
                cost_intv_before_end = guard_bool(
                    self.model,
                    f"t{t.id}_cfg{i}_intv{j}_after_end",
                    real_end_time <= end,
                    real_end_time > end,
                )
                self.model.add(real_cost == intv.cost).only_enforce_if(
                    config_active, cost_intv_after_start, cost_intv_before_end
                )

    def __objective_function(self):
        sum_cost_expr = 0
        for id in self.config.tasks:
            sum_cost_expr += self.computed_vars[id].real_cost
        self.model.minimize(sum_cost_expr)

    # in general, worst case: O(task * cost config * cost interval)
    def _model(self):
        self.model = cp_model.CpModel()
        self.props = self.__init_model_props()

        # find worst-case max starting/ending time (for default upper-bound without knowing anything else)

        # init decision variables O(task)
        self.decision_vars: dict[int, DecisionState] = {}

        # init computed variables O(task)
        self.computed_vars: dict[int, ComputedState] = {}

        for t in self.config.tasks.values():
            self.decision_vars[t.id] = DecisionState(self.model, self.props, t)
            self.computed_vars[t.id] = ComputedState(
                self.decision_vars[t.id],
                self.model,
                self.props,
                t,
            )

        # init computed duration & end time variables defs
        for t in self.config.tasks.values():
            self.__setup_computed_duration_and_end(t)

        # init computed parent vars O(task)
        for t in self.config.tasks.values():
            self.__setup_computed_parents(t)

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

    def _print_proto(self):
        print("Proto:")

        proto = self.model.Proto()

        varnames: dict[int, str] = {}
        for i, v in enumerate(proto.variables):
            varnames[i] = v.name

        def color_grey(s: str) -> str:
            return f"\033[90m{s}\033[0m"

        def color_red(s: str) -> str:
            return f"\033[31m{s}\033[0m"

        def color_blue(s: str) -> str:
            return f"\033[34m{s}\033[0m"

        def print_lin_expr(expr) -> str:
            terms = [
                f"{color_grey(varnames[expr.vars[i]])}"
                if expr.coeffs[i] == 1
                else f"-{color_grey(varnames[expr.vars[i]])}"
                if expr.coeffs[i] == -1
                else f"{color_blue(expr.coeffs[i])} * {color_grey(varnames[expr.vars[i]])}"
                for i in range(len(expr.vars))
            ]
            if hasattr(expr, "offset") and expr.offset != 0:
                terms.append(color_blue(str(expr.offset)))
            return " + ".join(terms)

        constraints: dict[int, str] = {}
        for i, cobj in enumerate(proto.constraints):
            output = ""
            if cobj.has_all_diff():
                c = cobj.all_diff
                raise Exception("all_diff not supported")
            elif cobj.has_at_most_one():
                c = cobj.at_most_one
                raise Exception("at_most_one not supported")
            elif cobj.has_automaton():
                c = cobj.automaton
                raise Exception("automaton not supported")
            elif cobj.has_bool_and():
                c = cobj.bool_and
                raise Exception("bool_and not supported")
            elif cobj.has_bool_or():
                c = cobj.bool_or
                raise Exception("bool_or not supported")
            elif cobj.has_bool_xor():
                c = cobj.bool_xor
                raise Exception("bool_xor not supported")
            elif cobj.has_circuit():
                c = cobj.circuit
                raise Exception("bool_circuit not supported")
            elif cobj.has_cumulative():
                c = cobj.cumulative
                raise Exception("cumulative not supported")
            elif cobj.has_dummy_constraint():
                c = cobj.dummy_constraint
                raise Exception("dummy_constraint not supported")
            elif cobj.has_element():
                c = cobj.element
                raise Exception("element not supported")
            elif cobj.has_exactly_one():
                c = cobj.exactly_one
                raise Exception("exactly_one not supported")
            elif cobj.has_int_div():
                c = cobj.int_div
                output = f"{print_lin_expr(c.target)} = {print_lin_expr(c.exprs[0])} / {print_lin_expr(c.exprs[1])}"
            elif cobj.has_int_mod():
                c = cobj.int_mod
                output = f"{print_lin_expr(c.target)} = {print_lin_expr(c.exprs[0])} % {print_lin_expr(c.exprs[1])}"
            elif cobj.has_int_prod():
                c = cobj.int_prod
                target = print_lin_expr(c.target)
                terms = " * ".join([print_lin_expr(e) for e in c.exprs])
                output = f"{target} = {terms}"
            elif cobj.has_interval():
                c = cobj.interval
                start = print_lin_expr(c.start)
                size = print_lin_expr(c.size)
                end = print_lin_expr(c.end)
                output = f"{start} + {size} == {end}"
            elif cobj.has_inverse():
                c = cobj.inverse
                raise Exception("unsupported inverse!")
            elif cobj.has_lin_max():
                c = cobj.lin_max
                target = f"{print_lin_expr(c.target)}"
                terms = ", ".join([print_lin_expr(e) for e in c.exprs])
                output = f"{target} = max{{{terms}}}"
            elif cobj.has_linear():
                c = cobj.linear
                expr = print_lin_expr(c)

                domains = " U ".join(
                    [
                        f"[{color_blue(_cap_size(c.domain[i]))}, {color_blue(_cap_size(c.domain[i + 1]))}]"
                        for i in range(len(c.domain) // 2)
                    ]
                )
                output = f"{expr} ∈ {domains}"
            elif cobj.has_no_overlap():
                c = cobj.no_overlap
                raise Exception("unsupported no overlap!")
            elif cobj.has_no_overlap_2d():
                c = cobj.no_overlap_2d
                raise Exception("unsupported no overlap 2d!")
            elif cobj.has_table():
                c = cobj.table
                raise Exception("unsupported no overlap table!")
            else:
                raise Exception("this should never happen!")

            constraints[i] = output

        for idx, rep in constraints.items():
            enforcement = " ^ ".join(
                [
                    constraints[id] if id > 0 else f"~({constraints[-id - 1]})"
                    for id in proto.constraints[idx].enforcement_literal
                ]
            )
            if enforcement == "":
                print(rep)
                continue
            print(f"{enforcement} {color_red('->')} {rep}")

    def _solve_debug(self):
        model = self._model()
        solver = cp_model.CpSolver()
        solver.parameters.log_search_progress = True
        solver.parameters.cp_model_presolve = True
        status = solver.solve(model)

        self._print_proto()

        return (
            status,
            solver.ObjectiveValue(),
            [
                ScheduledTask(
                    task_id=t,
                    start=solver.value(self.decision_vars[t].start),
                    real_end=solver.value(self.computed_vars[t].real_end),
                    config=solver.value(self.decision_vars[t].config_select),
                )
                for t in self.config.tasks
            ],
        )

    def solve(self) -> tuple[cp_model.CpSolverStatus, float, list[ScheduledTask]]:
        model = self._model()
        # model.add(self.var_cost_config_select[1] == 4)
        solver = cp_model.CpSolver()
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
                    start=solver.value(self.decision_vars[t].start),
                    real_end=solver.value(self.computed_vars[t].real_end),
                    config=solver.value(self.decision_vars[t].config_select),
                )
                for t in self.config.tasks
            ],
        )


def assert_intrinsic_start_end(config: Config, scheduled: list[ScheduledTask]):
    for s in scheduled:
        task_cfg = config.tasks[s.task_id]
        if task_cfg.start is not None:
            assert s.start >= task_cfg.start
        if task_cfg.end is not None:
            assert s.start < task_cfg.end


def assert_non_overflow(config: Config, scheduled: list[ScheduledTask]):
    unit_bucket_durations: dict[int, dict[int, int]] = {}

    duration_dict: dict[int, int] = {}
    scheduled_dict: dict[int, ScheduledTask] = {}
    for s in scheduled:
        scheduled_dict[s.task_id] = s

    def ensure_duration(id: int) -> int:
        if id in duration_dict:
            return duration_dict[id]

        s = scheduled_dict[id]

        task_cfg = config.tasks[id]
        unit = task_cfg.timescale_unit
        if unit not in unit_bucket_durations:
            unit_bucket_durations[unit] = {}
        unit_buckets = unit_bucket_durations[unit]
        if s.start not in unit_buckets:
            unit_buckets[s.start] = 0

        chosen_config = task_cfg.cost_configs[s.config]
        if chosen_config.duration is not None:
            duration_dict[id] = chosen_config.duration
            return chosen_config.duration

        sum = 0
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
        for bucket_duration in unit_bucket_durations[unit]:
            assert bucket_duration <= unit
