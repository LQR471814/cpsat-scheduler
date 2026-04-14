from ortools.sat.python import cp_model

from solution_printer import print_vars

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

print_vars(model, solver, [x, y, xy, z])
