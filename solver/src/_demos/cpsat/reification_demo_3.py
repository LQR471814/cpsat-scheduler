from ortools.sat.python import cp_model
from cpsatmodel.print import print_vars

model = cp_model.CpModel()

x = model.new_int_var(2, 3, "x")
y = model.new_bool_var("y")

b = model.new_bool_var("b")
model.add_bool_or(x == 3, y).only_enforce_if(b)
model.add_bool_and(x != 3, y.Not()).only_enforce_if(b.Not())

solver = cp_model.CpSolver()
status = solver.solve(model)

print_vars(model, solver, [x, y, b])
