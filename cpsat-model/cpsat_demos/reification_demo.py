from ortools.sat.python import cp_model

from solution_printer import print_vars

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

print_vars(model, solver, [x, y, z])
