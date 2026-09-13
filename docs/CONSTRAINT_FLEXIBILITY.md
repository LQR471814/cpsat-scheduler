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

All of these are independent of one another (and all involve
validating that no cycles occur).

> [!NOTE]
> The reason we don't have a "Given task's duration is based on
> the sum of these other tasks' durations" constraint is because
> the new logic for "synthetic parents" (now known as
> [[#Duration%20Accumulation]]) makes this unnecessary.
>
> Namely, a parent's need not actually contribute any duration in
> particular, it actually just forces certain tasks to be
> scheduled within a given interval.

# Core rules

- Non-overflow constraint
   - And with this, implies "wrapper" parents
- Prerequisites

# Duration Accumulation

It is currently undesirable for the durations of tasks without
parents to not be counted in higher timescales without the adding
of "synthetic parents" for every task.

To model this, for each timescale, we will use the
`add_cumulative` constraint like follows:

- For all timescales:
   - Tasks of the current unit will have intervals will span their
     start times to the end of their timescale instance.
   - Tasks of smaller units, will expand their intervals to be of
     the current unit's size, and be included within intervals.
   - The duration decision var will be used for the demand of each
     task interval.
   - The capacity will be the timescale instance's size.

The reason we must constrain on each timescale is because of the
following:

- We cannot constrain on the greatest timescale because otherwise
  impossibilities at smaller timescales can be allowed on a larger
  timescale:
   - Suppose I scheduled 8 hours worth of 4 hour unit tasks at
     8:00 AM on a certain day.
   - If my greatest timescale unit is 1 day, and nothing else was
     scheduled during that day, then I have 8 hours / 24 hours on
     that day.
   - This doesn't overflow the day timescale (the one I check),
     but does overflow the 4-hour timescale.
- We cannot constrain only on the smallest timescale because
  otherwise we may not detect overflow involving tasks only
  defined on larger timescales.
   - Suppose I scheduled three 4 hour unit tasks (total 12 hours)
     throughout one day.
   - Then suppose I scheduled a 20-hour task for that day.
   - The total for that day is 32 hours of work.
   - If I only checked for overflow on the 4-hour level, I
     wouldn't have known the day had overflown.

These arguments extend to any number of constraints less than the
set of all units used.

