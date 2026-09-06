# Problem

The current design conflates 3 concepts into one idea of a
"parent", this can result in limitations in modelling.

Namely:

- The time a task can be scheduled being dependent on another
  task's time scheduled.
- A task's "activation" (namely duration >0), based on another
  task's cost configuration chosen.
- A task's duration based on the sum of many other tasks'
  durations.

It should be possible for the user to state dynamic rules for all
of these independently, but within certain safeguards as to avoid
invalid models.

In particular, we want to expose the full power of cpsat solver
and provide but a thin "syntactic sugar" over it, not impose
arbitrary limitations.

# New formulation

Each task has a start, cost, and duration decision variable.

Start is still subject to hard domain constraints, either by
definition or scheduling horizon.

Cost is just an int64.

Duration is bounded to other domain constraints.

Additional cpsat constraints / intermediate variables may be
formulated based on these variables.

Now we can have the previous constructs and rules simply be
"templates" or macros for cpsat constraints / intermediary
variables.

Each rule brings its own validation and proof.

In particular:

- Given task must be scheduled within another task's bounds
- Given task is "activated" based on another task's costs or start
  time or what have you
   - Add constraints onto duration & cost
- Given task's duration is based on the sum of these other tasks'
  durations

All of these are independent of one another (and all involve
validating that no cycles occur).

# Core rules

- Non-overflow constraint
   - And with this, implies "wrapper" parents
- Prerequisites

