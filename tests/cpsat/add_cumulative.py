from ortools.sat.python import cp_model

from cpsatscheduler.backend.print import print_model_size

model = cp_model.CpModel()

sizes = [1, 4, 6, 2, 3]
N = len(sizes)  # the number of possible elements
M = 3  # the number of possible slots
J = 6  # the maximum cumulative size for each slot

print("possible elements:", N)
print("possible slots:", M)

# for each element, we define a variable representing its choice of slot
slot_choice = [model.new_int_var(0, M - 1, f"slot_choice_for_el_{i}") for i in range(N)]

# - intervals and demands are bijective
#
# this enforces that:
# - for all possible values of time (t):
#   - the sum of corresponding demand[i] for all possible intervals (interval[i]):
#       - where t \in interval[i]
#   - must be <= capacity
#
# so essentially, for a demand[i] to be "active" and contribute to the sum at a
# time t, it must be within the interval[i]
#
# remember that we want the "size" of an element to become "active" if it is
# scheduled to a particular slot number
#
# therefore for each slot <-> interval [slot num, slot num + 1)
#
# for element i, "size" = demand[i]
#
# then capacity=J
intervals = [
    model.new_fixed_size_interval_var(start=slot_choice[i], size=1, name=f"element_{i}")
    for i in range(N)
]
demands = sizes

model.add_cumulative(
    intervals=intervals,
    demands=demands,
    capacity=J,
)

print_model_size(model)

solver = cp_model.CpSolver()
status = solver.solve(model)

for j in range(M):
    sum = 0
    for i in range(N):
        chosen = solver.value(slot_choice[i])
        if chosen == j:
            print(f"slot {j} +{sizes[i]}")
            sum += sizes[i]
    print(f"slot {j}, sum = {sum}")
