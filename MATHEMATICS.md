# Timescale hierarchy

$U \subseteq \mathbb{N}$ is a set of timescale units.

$\forall a \in U \forall b \in U [a \ (\text{mod}\ b) \equiv 0]$

$\Theta : U \to \text{Set } \mathbb{N}$

$\Theta(u) = \{x \in \mathbb{N} | x\ (\text{mod}\ u) \equiv 0\}$

$\Theta(u)$ is the set of all valid starting/ending times and
durations for $u \in U$.

$\Upsilon = \min_{u \in U} u$ shall be considered the "atomic" unit.

# Task

$T$ is the set of all tasks.

## Timescale unit

$u_{t} \in U$ is the timescale unit of task $t \in T$.

## Cost

$I_{t}$ is the set of cost configurations for task $t \in T$.

$\forall t \in T (I_{t} \neq \emptyset)$

Each task must have at least 1 cost configuration, otherwise
decision variables and cost computation would be undefined.

$$
\begin{aligned}
C_{it} \subseteq & \{([a, b], c)| \\
& a \in \theta_{t}(i) \\
& \land b \in \theta_{t}(i) \cup \{\max[\theta_{t}(i)] + u_{t}\} \\
& \land b > a \\
& \land c \in \mathbb{Z}\}
\end{aligned}
$$

Gives the cost $c$ which applies if the [[#Real task completion time]]
of task $t$ under cost configuration $i$ falls inside closed
interval $[a,b]$.

<!--
$R_{it} \in \text{Set}~\mathbb{N}$ gives the set of task durations
which this cost configuration applies to.

$$
\forall t \in T \forall i \in I_{t} \forall A \in R_{it} \forall B
\in R_{it} (A \neq B \to A \cap B = \emptyset)
$$
-->

In other words, no cost configurations should overlap with each
other.

### Continuous discretization

Suppose we are given a PDF of variable $f(x)$, which represents the
risk of non-completion for a given duration allocated to the task.

Let's suppose the absolute cost of non-completion is $Q$.

Let:

$F(x) = \int_{0}^{x} f(x) dx$

The expected cost for a given duration allocation $\delta$ is:

$$
E[\delta] = Q[1-F(\delta)]
$$

We can then choose a finite set of number of values for $\delta$,
and call it $\Delta$.

For any $\delta \in \Delta$ and deadline $d$, our cost intervals
will be:

$$
C_{it} = \{([0, d), E[\delta]), ([d, \infty), Q)\}
$$

## Children

Each task can have multiple sets of children according to cost
configuration.

$Ch_{it} \in T$ is the set of children for a task $t \in T$ and
cost configuration $i \in I_{t}$. (should not contain cycles)

However, we also want to be able to decide task cost
configurations independently of each other.

Thus there should never occur a situation where two child
configurations are selected and the same child appears in both.

Therefore, each child must have only one possible parent.

### Parents

$Hc : T \times T \to \text{Predicate}$

$Hc(p, c) = \exists i \in I_{p} (c \in Ch_{ip})$

$Hc(p,c)$ checks if $p \in T$ has $c \in T$ as a possible child.

$$
\forall c \in T \neg (\exists a \in T \exists b \in T [a \neq b
\land Hc(a, c) \land Hc(b, c)])
$$

There are no children which have two different possible parents.

Likewise, there should be no tasks whose timescales are not the
max timescale with no parents.

If it is unclear what the parent of a task should be, a "temporary
parent" should be created to house it, this way the durations of
the children are properly factored into the higher timescales.

### Deactivating orphans

If a child can possibly have a parent, but its current parent is
null, the child's real duration will automatically become $0$,
indicating that the child has been dropped.

$$
\forall c \in T [Pa_{c} = \emptyset \to \delta_{D_{c}[i]}c = 0]
$$

## Real task duration

$\delta_{ti} \in \mathbb{N}$ gives the real duration of a task
$t\in{T}$ and cost configuration $i \in I_{t}$.

> [!NOTE]
> For leaf tasks, this real duration shall be directly defined as
> a constant for all cost configurations $i \in I_{t}$.

For non-leaf tasks, this real duration will be defined as:

$$
\delta_{ti} = \sum_{c \in Ch_{t}} \delta_{cD_{c}[i]}
$$

> [!QUOTE]
> So for tasks with children, the real duration does not depend on
> the cost configuration. (only the cost configurations of leaf
> children)

## Start/end constraints

$s_{t} \in \Theta(u_{t}) \cup \{\emptyset\}$ is the start (or
null) of task $t\in{T}$.

$d_{t} \in \Theta(u_{t}) \cup \{\emptyset\}$ is the deadline (or
null) of task $t\in{T}$.

$Pa_{t} = \begin{cases}
\iota p(t \in Ch_{D_{p}[i]p}), & \exists p \in T (t \in Ch_{D_{p}[i]p}) \\
\emptyset, & \neg\exists p \in T (t \in Ch_{D_{p}[i]p}) \\
\end{cases}$

$Pa_{t}$ gives the current parent or null of the given task
$t\in{T}$.

$$
\forall p \in T (\exists i \in I_{p} [Ch_{ip} \neq \emptyset] \to \forall D_{p}[i] \in I_{p} [])
$$

For each child, it must not have more than one possible parent
outside of having no parent.

$\theta_{t} : I_{t} \to \text{Set}~\mathbb{N}$ for a $t \in T$

$$
\begin{aligned}
& \theta_{t}(i) = \{s \in \Theta(u_{t})|[ \\
&     (Pa_{t} \neq \emptyset \to s \geq \frac{u_{Pa_{t}}}{u_{t}}D_{Pa_{t}}[s]) \\
&     \land (s_{t} \neq \emptyset \to s \geq s_{t}) \\
& ] \land [ \\
&     (Pa_{t}\neq \emptyset \to s < \frac{u_{Pa_{t}}}{u_{t}}(D_{Pa_{t}}[s]+1)) \\
&     \land (d_{t} \neq \emptyset \to s < d_{t}) \\
& ]\}
\end{aligned}
$$

$\theta_{t}(i)$ represents the set of all valid task starting
times as determined by the given cost configuration and task and
parent starting time/deadlines.

## Real task completion time

For a given task we can find its actual completion time by
considering the end time of its latest scheduled child.

If it is a leaf task, the worst-case scenario is the end of the
time slot it is scheduled at.

$\epsilon : T \to \mathbb{N}$

$$
\epsilon(t) = \begin{cases}
\max_{c \in Ch_{t}} \epsilon(c), & Ch_{t} \neq \emptyset \\
u_{t}(D_{t}[s] + 1), & Ch_t = \emptyset
\end{cases}
$$

The real task completion time is used for [[#Prerequisites]] and
computing [[#Cost]]. This is useful because oftentimes, large
projects can be projected to complete before the end of the time
slot it is scheduled in, simply by looking at when the last child
task is finished (ex. you have a project scheduled for this month,
but you will reasonably finish by the middle of the month).

This will not be used to constrain valid task starting times for
the task itself. (as that would be circular).

This can sometimes have unintuitive results (such as multiple
tasks having the exact same "real" completion time), thus, it may
be helpful to rename this into something like "most specific
ending time" in the future. (ex. narrowest completion time)

## Prerequisites

$P_{t}$ is the set of prerequisite tasks of $t \in T$. (this
should not contain cycles)

$$
\forall t \in T \forall D_{t}[s] \in \theta(t) \forall p \in
P(t) [\epsilon(p) \leq u_{t}D_{t}[s]]
$$

We ensure that all task prerequisites are fulfilled before
starting a task.

# Non-overflow constraint

We ensure that no timescale instance overflows its timescale unit
time under the current state.

$L: U \times \Theta(u) \to \text{Set}~T$

$L(u, s) = \{x|x \in T \land u_{x}=u\land D_{x}[s] = s\}$

Function $L$ gives the list of tasks under a given timescale unit
and starting time.

$$
\forall u \in U \forall s \in \Theta(u) \left(\sum_{t \in L(u,s)}\delta_{tD_{t}[i]} \leq u\right)
$$

# Decision variables

$D_{t}[i] \in I_{t}$ is the cost configuration chosen for task
$t\in{T}$.

$D_{t}[s] \in \theta(t)$ is the starting time chosen for the task.

# Objective function

We want to minimize the total cost under the chosen cost
configurations.

$$
\min \sum_{t \in T} [\iota x(x \in C_{D_{t}[i]t} \land u_{t}D_{t}[s] \in x_{I})]_c
$$

# Deadlines

Sometimes a task's logical start and end time constraints exceed
the actual "deadline" involved for the task.

1. Suppose a project $P$ (timescale week) is due on Wednesday of
   week 2.
2. I am planning to begin work on Monday of week 1.
3. $P$ has 3 subtasks $P_1,P_2,P_3$ (timescale day).
4. I can only do $P_1$ and $P_2$ on week 1, $P_3$ must be
   scheduled on week 2.
5. Semantically speaking, I should be able to schedule $P_3$ on
   week 2.
6. However, this requires me to set the logical deadline of $P$ on
   week 2, which technically implies time could be scheduled
   **after** Wednesday of week 2.
7. The solution is simply to specify the appropriate (more
   specific) logical deadline for the subtasks $P_1,P_2,P_3$.
8. In essence, the logical deadline of a task of a time unit $u$
   and actual deadline $d$ is
   $\left\lceil\frac{d}{u}\right\rceil$

# Reasoning

Suppose I have a task $T$ with subtasks $T_1,T_2$.

Duration of $T_1$ is $\in [a_1, b_1]$

Duration of $T_2$ is $\in [a_2, b_2]$

Margin of task $T$ is $\in [a, b]$

Cost is also dependent on the duration of the children alongside
the margin, not the margin alone.

Better to phrase cost as a function of task end time

