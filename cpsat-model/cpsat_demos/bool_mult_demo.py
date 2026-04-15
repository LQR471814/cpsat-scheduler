from ortools.sat.python import cp_model

from solution_printer import print_vars

model = cp_model.CpModel()

x = model.new_bool_var("x")
y = model.new_int_var(0, 5, "y")
z = model.new_int_var(0, 5, "z")

model.add_multiplication_equality(z, x, y)

solver = cp_model.CpSolver()
status = solver.solve(model)

print_vars(model, solver, [x, y, z])
