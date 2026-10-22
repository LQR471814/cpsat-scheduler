# PROBLEM: IDs

- if we want proof to be a localized matter
- this requires monad (division of state into many slices)
- monad hides definitions
- definitions include monad? (impossible)
- monad exposes definitions -> we're back to where we've started,
  this is not easy either

are there FP native ways to make construction easier?

the fundamental contention is that the definition of a task
depends on the definition of other tasks, so the only way to
establish this dependency explicitly is via explicitly linking the
definition to the prior task

to make this connection implicit is to add a monad (which adds in
a lot of other implicit-ness that is undesirable)

however, the use of construction alone, makes it arduous to update
tasks (as a deleted or added task requires its dependencies to be
updated)

furthermore, two tasks may depend on the same predecessor, which
would break uniqueness

## SOLUTION: IDs

we can actually just make the identity of the task structure be
its ID, then just accept a Finset of tasks for the final
construction.

the Finset will tell the user (via concrete definition or proof,
if there are duplicate tasks, and which ones they are)

# PROBLEM: layering of functionality

we want the implementations of certain functionality to be as
independent of each other as possible.

particularly, a "task" should be nothing more than a collection of
3 decision variables (start, duration, cost).

"cost-demand table" is a utility for constructing a constraint.
"PERT tasks" are a utility for constructing a "cost-demand table".

> [!NOTE]
> some wrinkles in this are the fact that PERT computation is not
> pure. this means that anything PERT related needs to be tossed
> into an IO monad.
>
> this is really inconvenient and perhaps the better way to
> account for this is to simply implement PERT PPF in lean.
>
> another alternative is to simply use the approximation for PERT
> (while this introduces some problems with regards to variance,
> the accuracy of PERT in general is heavily dependent on its
> parameters so the difference between the beta-PERT and the
> triangular PERT is hardly significant)

this gets complicated by the objective constraint, which needs to
interact with a bunch of otherwise independent tasks, constraints,
and functionality on different layers.

1. all task costs must be summed to be one particular type of cost
2. additional types of cost may be computed based on the start
time of the task and various other factors

the cleaner way to do this would be to make the objective accept a
generic low-level list of linear exprs representing cost terms,
then allow for different layers of functionality to supply their
own cost terms.

> [!EXAMPLE]
> tasks can provide their time demand cost as a linear expr, tasks
> constructed via process factors

## SOLUTION: layering

1. task remains a collection of 3 variables
2. PERT should be computed via pure lean via PERT approximation
3. PERT should have a utility for constructing task cost domain
4. objective constraint should take in various LinearExpr and sum
   them up, process factors and other utilities should construct
   these LinearExpr and provide a way to merge them in a weighted
   manner
