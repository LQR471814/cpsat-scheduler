from ortools.sat.python import cp_model

from cpsatmodel.print import print_vars

model = cp_model.CpModel()

X = model.new_bool_var("X")  # parent cfgs
Y = model.new_bool_var("Y")  # parent cfgs
W = model.new_bool_var("W")  # X | Y

switch = model.new_bool_var("switch")
active = model.new_bool_var("active")

# W = X|Y|...
# S = Switch
# A = Active

# | S | W | A |
# | F | F | F |
# | F | T | F |
# | T | F | F |
# | T | T | T |

# S & W & A

model.add_bool_or([X, Y]).only_enforce_if(W)
model.add_bool_and([X.Not(), Y.Not()]).only_enforce_if(W.Not())

model.add_bool_and([switch, W]).only_enforce_if(active)
model.add_bool_or([switch.Not(), W.Not()]).only_enforce_if(active.Not())

solver = cp_model.CpSolver()
print_vars(model, solver, [X, Y, switch, active])
