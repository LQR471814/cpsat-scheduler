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

