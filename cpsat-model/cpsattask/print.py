import sys
import cpsattask.color as color
from ortools.sat.python import cp_model


class VarArraySolutionPrinter(cp_model.CpSolverSolutionCallback):
    """Print intermediate solutions."""

    def __init__(self, variables: list[cp_model.IntVar]):
        cp_model.CpSolverSolutionCallback.__init__(self)
        self.__variables = variables
        self.__solution_count = 0

    def on_solution_callback(self) -> None:
        self.__solution_count += 1
        for v in self.__variables:
            print(f"{v}={self.value(v)}", end=" ")
        print()

    @property
    def solution_count(self) -> int:
        return self.__solution_count


def print_vars(
    model: cp_model.CpModel, solver: cp_model.CpSolver, variables: list[cp_model.IntVar]
):
    solver.parameters.enumerate_all_solutions = True
    solver.solve(model, VarArraySolutionPrinter(variables))


class ProtoPrinter:
    def __init__(self, proto) -> None:
        self.proto = proto
        self.varnames: dict[int, str] = {}
        for i, v in enumerate(proto.variables):
            self.varnames[i] = v.name

    def __cap_size(self, i: int):
        if i == sys.maxsize:
            return "∞"
        elif i == -sys.maxsize - 1:
            return "-∞"
        else:
            return str(i)

    def __print_lin_expr(self, expr) -> str:
        terms = [
            f"{color.grey(self.varnames[expr.vars[i]])}"
            if expr.coeffs[i] == 1
            else f"-{color.grey(self.varnames[expr.vars[i]])}"
            if expr.coeffs[i] == -1
            else f"{color.blue(expr.coeffs[i])}·{color.grey(self.varnames[expr.vars[i]])}"
            for i in range(len(expr.vars))
        ]
        if hasattr(expr, "offset") and expr.offset != 0:
            terms.append(color.blue(str(expr.offset)))
        return " + ".join(terms)

    def __constraints(self):
        constraints: dict[int, str] = {}
        for i, cobj in enumerate(self.proto.constraints):
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
                output = f"{self.__print_lin_expr(c.target)} = {self.__print_lin_expr(c.exprs[0])}÷{self.__print_lin_expr(c.exprs[1])}"
            elif cobj.has_int_mod():
                c = cobj.int_mod
                output = f"{self.__print_lin_expr(c.target)} = {self.__print_lin_expr(c.exprs[0])}%{self.__print_lin_expr(c.exprs[1])}"
            elif cobj.has_int_prod():
                c = cobj.int_prod
                target = self.__print_lin_expr(c.target)
                terms = "·".join([self.__print_lin_expr(e) for e in c.exprs])
                output = f"{target} = {terms}"
            elif cobj.has_interval():
                c = cobj.interval
                start = self.__print_lin_expr(c.start)
                size = self.__print_lin_expr(c.size)
                end = self.__print_lin_expr(c.end)
                output = f"{start} + {size} == {end}"
            elif cobj.has_inverse():
                c = cobj.inverse
                raise Exception("unsupported inverse!")
            elif cobj.has_lin_max():
                c = cobj.lin_max
                target = f"{self.__print_lin_expr(c.target)}"
                terms = ", ".join([self.__print_lin_expr(e) for e in c.exprs])
                output = f"{target} = max{{{terms}}}"
            elif cobj.has_linear():
                c = cobj.linear
                expr = self.__print_lin_expr(c)

                domains = " ∪ ".join(
                    [
                        f"[{color.blue(self.__cap_size(c.domain[i]))}, {color.blue(self.__cap_size(c.domain[i + 1]))}]"
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
                continue
                raise Exception("this should never happen!")
            constraints[i] = output
        return constraints

    def print_text(self):
        color.enabled = True
        for idx, rep in self.__constraints().items():
            enforcement = " ∧ ".join(
                [
                    color.grey(self.proto.constraints[id].name)
                    if id > 0
                    else f"¬({color.grey(self.proto.constraints[-id - 1].name)})"
                    for id in self.proto.constraints[idx].enforcement_literal
                ]
            )
            if enforcement == "":
                print(f"{self.proto.constraints[idx].name} {rep}")
                continue
            print(
                f"{self.proto.constraints[idx].name} {enforcement} {color.red('→')} {rep}"
            )

    def print_mermaid(self):
        color.enabled = False
        print("flowchart LR")
        for idx, rep in self.__constraints().items():
            cnstr = self.proto.constraints[idx]
            for i, enforce_id in enumerate(cnstr.enforcement_literal):
                neg = enforce_id < 0
                if neg:
                    enforce_id = -enforce_id - 1
                print(f"\t{enforce_id} -->", end="")
                if neg:
                    print("|no|", end="")
                else:
                    print("|yes|", end="")
                print(f" {idx}", end="")
                if i == 0:
                    if len(cnstr.enforcement_literal) > 1:
                        print(f'(("{cnstr.name}: {rep}"))')
                    else:
                        print(f'["{cnstr.name}: {rep}"]')
                else:
                    print("")
