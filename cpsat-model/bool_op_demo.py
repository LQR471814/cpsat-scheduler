from ortools.sat.python import cp_model

model = cp_model.CpModel()

x = model.new_bool_var("x")
y = model.new_bool_var("y")
xy = model.new_bool_var("x&y")
z = model.new_bool_var("z")

model.add_implication(xy, x)
model.add_implication(xy, y)
model.add_bool_and(x, y, xy).only_enforce_if(xy)
model.add_bool_or(x.Not(), y.Not()).only_enforce_if(xy.Not())

model.add(z == 1).only_enforce_if(x, y)
model.add(z == 0).only_enforce_if(x.Not(), y.Not())
model.add(z == 0).only_enforce_if(x, y.Not())
model.add(z == 0).only_enforce_if(x.Not(), y)

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
solver.solve(model, VarArraySolutionPrinter([x, y, xy, z]))
