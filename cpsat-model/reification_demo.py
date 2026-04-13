from ortools.sat.python import cp_model

model = cp_model.CpModel()

x = model.new_int_var(0, 10, "x")
y = model.new_bool_var("y")
z = model.new_int_var(5, 10, "z")
model.add(x >= 5).only_enforce_if(y)
model.add(x < 5).only_enforce_if(y.Not())
model.add(z == 5).only_enforce_if(y)
model.add(z == 10).only_enforce_if(y.Not())

solver = cp_model.CpSolver()
status = solver.solve(model)


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


solver.parameters.enumerate_all_solutions = True
solver.solve(model, VarArraySolutionPrinter([x, y, z]))
