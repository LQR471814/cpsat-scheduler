from ortools.sat.python import cp_model

from solution_printer import print_vars

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

print_vars(model, solver, [x, y, y2, z])
