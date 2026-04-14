from ortools.sat.python import cp_model

model = cp_model.CpModel()

x = model.new_int_var(0, 10, "x")
y = model.new_bool_var("y")
y2 = model.new_bool_var("y2")
z = model.new_int_var(0, 100, "z")
model.add(x >= 5).only_enforce_if(y)
model.add(x < 5).only_enforce_if(y.Not())
model.add(x >= 3).only_enforce_if(y2)
model.add(x < 3).only_enforce_if(y2.Not())
model.add(z == 0).only_enforce_if(y.Not())
model.add(z == 99).only_enforce_if(y)
model.add(z == 50).only_enforce_if(y, y2)

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
solver.solve(model, VarArraySolutionPrinter([x, y, y2, z]))
