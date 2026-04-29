We want to represent a chronological series of "planning updates",
since a real schedule will require continuous updates according to
new information.

This broadly falls into:

1. Progress updates (on tasks)
2. New tasks / dropped tasks
3. Updates to task information

Furthermore, we would like to specify more advanced semantics for
tasks, namely:

1. Deadlines
2. Prerequisite conditions
3. Cost as function of scheduled timespan

What we can keep:

1. Hierarchical timespan-based system for scheduling

What doesn't work (too much effort):

1. CALDAV / this system integration, ideally kept separate.

# Progress updates

## Problem

We want to make progress updates as ergonomic as possible so as to
reduce the friction involved in maintaining them.

## Implementation

This would likely be something like a prompt when you open the
progress update window: *It has been X duration since your last
progress update, what did you do during that time?*

Giving the user the correct options to take is also non-trivial,
some common flows I can think of are:

1. Showing the user the list of time allocations scheduled for
   current daypart, then today by default.
2. Showing an "other" button where the user can input a new time
   allocation target.

In general, we assume that the user will follow the schedule
unless otherwise and thereby encourage the user through UI design,
to follow the schedule.

# Repeated time allocation

## Problem

We want to both make it easy for the 90% use case of (I want this
task to repeat every day/week/etc...) but also flexible enough to
support the edge case of a very specific repeated time allocation.

We also want to make it easy to create a "margin" for certain days
for unexpected or yet unscheduled events.

## Implementation

We provide a callback function, such that:

- Given a timescale instance
- Return null or a new instance of the event

Then we call it on-demand from the planning daemon, it becomes
a dynamic part of the "constraints state".

# Timespans

Tasks allow more sophisticated control over the scheduling of time
allocations rather than just "this task must happen in this fixed
timespan".

Tasks come with their own timespan (which should cover the entire
time interval which the task should be active), this constrains
the timescale and interval which they can be scheduled.

However, tasks can flexibly spawn time allocations to cover their
own time allocation according to a scheduling algorithm and
additional information like a cost function. (a function that maps
a time allocation in a time span instance to a cost value)

Tasks may also be children of other tasks, meaning that children
can be moved around by a scheduling algorithm.

Tasks can come with prerequisites, that is, logical predicates
that must be true before a task may be scheduled.

# Summary

Tasks are:

1. ID - External completion criteria identifier
2. Constraints:
    - Timeframe (timescale instance), dictated by parent
    - Prerequisite tasks
    - Deadline + absolute cost of exceeding it
3. Indeterminacy: (what the solver gets to choose)
    - Total allocated time -> probability of not finishing
      after the total allocated time ->
      $E[\text{cost}]=P(\neg\text{finish}|T)C(\neg\text{finish})$
    - The timeframes of children tasks (explicit time
      allocations)
    - Timeframes of as much "margin / unspecified" children tasks
      created:
        1. As necessary to fill up the total allocated time
        2. Minus the explicit children task time allocations
        3. Without exceeding the maximum atomic task work time
        for the given timescale.
            - Ex. Children in the daypart timescale have a
              maximum atomic work time of 90 minutes.
            - Ex. Children in the day timescale has a maximum
              atomic work time 3 hours.
            - etc...

We will model this using Google's [CP-SAT solver](https://github.com/d-krupke/cpsat-primer?tab=readme-ov-file).

> [!WARNING]
> Floating point values are not allowed and should be avoided or
> approximated with fixed-point methods.

## Timescale hierarchy (idea)

The hierarchy is divided into a few units: (configurable)

1. 96-year
2. 32-year
3. 8-year
4. 2-year
5. 1-year
6. Semester
7. Quarter
8. Month
9. 2-Week
10. Week
11. Day
12. Day-part

A timescale instance (or work timeframe) is simply a tuple
consisting of $(t,u)$ where $t$ is a multiple of the timescale
type $u$. The absolute time is computed as $\epsilon + tu$ where
$\epsilon$ is some starting epoch time (configurable).

There exist constraints for all timescale instances, in
particular, for all tasks with = timescale instance, one must
ensure that the total time allocated does not exceed the available
time in that instance.

## Task

```
const task_timescale_unit int
```

```
task_schedule_time = int \in [parent_timeframe_start, deadline in this task's timescale unit)
# can be done with a linear constraint
```

Int variable for timescale multiplier as to when the task has been
scheduled, it is constrained based on the deadline and timeframe
chosen by the parent.

```
task_margin_configuration = int \in {IDs for completion probabilities with regards to margin}
task_expected_costs_n = n \in task_margin_configuration -> cost int
```

You can think of completion distribution of a task as: how much of
the *real time of completion* is covered or exceeded by our chosen
time allocation? Obviously, the more margin we add, the higher the
probability of completion.

*Choosing* how much margin to add usually comes down to an
estimate for the total amount of time a task will take, or an
estimate for the current "percentage done" of the task. Either
way, there are many ways to estimate how much margin to add to a
task so it is better for us to be unopinionated on the matter.
Convenience functions can be provided to automatically
generate/update a child "margin" task according to such methods.

The model generation engine which holds the "high-level" state of
the tasks can in fact show all 3 representations and allow the
user to specify whichever one is appropriate.

Thus, a task's duration is completely determined by its children,
which are in turn determined by their children, and etc... until
reaching "leaf" tasks.

These leaf tasks should be no longer than 90 minutes, choices
include: `{task's max duration, 15, 30, 45, 60, 75, 90}` (should
also be configurable)

Tying this back to the verification of timescale instance budget
at the end of [[#Timescale hierarchy (idea)]]. We do top-down
propagation, with each task's "real duration variable" being the
sum of their childrens' "real durations", all the way down until
reaching the leaf tasks.

Then, we build the timescale verification top-down. We check all
tasks' timeframes and ensure that for each timeframe, the sum of
the real duration of tasks scheduled within does not exceed the
allowed maximum.

For each timeframe, we technically include all tasks with that
timescale unit but we disable (set to 0) the task durations that
have different scheduled time values.
