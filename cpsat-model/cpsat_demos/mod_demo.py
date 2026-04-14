from ortools.sat.python import cp_model

from solution_printer import print_vars

model = cp_model.CpModel()

x = model.new_int_var(0, 10, "x")
model.add_modulo_equality(0, x, 2)

solver = cp_model.CpSolver()
status = solver.solve(model)

print_vars(model, solver, [x])
