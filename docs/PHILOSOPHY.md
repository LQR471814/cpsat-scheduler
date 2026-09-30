# The problem

The purpose of this project is tackle a specific problem of scale
when it comes to planning and scheduling.

Individuals have limited mental bandwidth, this is why athletes
musicians and even engineers have managers. The more an individual
is under strenuous mental or physical "load" (for lack of a better
term), the less one can expect that individual to perform well on
auxiliary tasks such as executive decision-making and
administrative work.

When the amount of decision-making, administrative work, and
things to remember increases beyond an individual's capacity to
handle them reliably, it is necessary to either:

1. Remove work:
    - Freeing up time for administration or reducing the amount of
      administration necessary.
2. Set up a system to handle administration for you.

# Formalizing it

Henceforth, we will assume that we cannot simply remove work,
though, in the real world it is always a good idea to check if one
can.

The chief concern of planning or scheduling is determining how to
allocate time. Of many potential *tasks*, *how much* time should
be allocated *to what*, and *when* should it be allocated?

> [!INFO]
> **Task:** A target of time allocations.

## Reducing state search space

The problem, in its most "pure form" as expressed previously is
unfortunately computationally intractable. 1) because it doesn't
quantize time to make discrete search practical 2) because one
will face a state explosion when handling larger amounts of tasks.

Consider 10 tasks and 10 time regions they could be assigned to,
assume we have some objective function for the "cost" of any
particular schedule. The possible permutations of schedules is as
follows:

$$
P(10, 10) = \frac{10!}{(0)!} = 10! = 3,628,800
$$

You can imagine that as the number of tasks and time regions
increase, this number would become incredibly large.



## Cost and Uncertainty

Now of course, under our formal assumptions we can demonstrate
optimality, but the real world is often much more complex than
what we have formalized here.

Let us take this example:

1. Task A and task B are of equal importance.
2. However, task B is due tomorrow while task A is due at the end
   of the week.
3. It seems obvious that one should do task B first.
4. However, suppose that task A takes 15 minutes and can reduce
   the time it takes for task B to complete in half.
5. Now, it is obvious that task A must be done first.

Notice that every time I introduced a new piece of "external"
information (with "However") the optimal plan had shifted.

