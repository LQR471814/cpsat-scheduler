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

$\forall t \in T [I_{t} \neq \emptyset]$

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

$R_{it} \in \text{Set}~\mathbb{N}$ gives the set of task durations
which this cost applies to.

$$
\forall t \in T \forall i \in I_{t} \forall A \in R_{it} \forall B
\in R_{it} (A \neq B \to A \cap B = \emptyset)
$$

In other words, no cost configurations should overlap with each
other.

> [!NOTE]
> We split a task's duration vs finish probability distribution
> into multiple segments. For each segment, we take the
> "worst-case" cost, so the cost of taking the longest time in the
> segment.
>
> For a task with a cost of non-finish of $C$, the cost of not
> finishing at a duration of $\delta$ $C[1-F(\delta)]$ where $F$
> is the CDF of duration vs finish probability.

$Ch_{it} \in T$ is the set of children for a task $t \in T$ and
cost configuration $i \in I_{t}$. (should not contain cycles)

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
\iota p(t \in Ch_{p}), & \exists p \in T (t \in Ch_{p}) \\
\emptyset, & \neg\exists p \in T (t \in Ch_{p}) \\
\end{cases}$

$Pa_{t}$ gives the parent or null of the given task $t \in T$.

$\theta_{t} : I_{t} \to \text{Set}~\mathbb{N}$ for a $t \in T$

$$
\begin{aligned}
& \theta_{t}(i) = \{s \in \Theta(u_{t})|[ \\
&     (Pa_{t} \neq \emptyset \to s \geq \frac{u_{Pa_{t}}}{u_{t}}D_{Pa_{t}}[s]) \\
&     \land (s_{t} \neq \emptyset \to s \geq s_{t}) \\
& ] \land [ \\
&     (Pa_{t}\neq \emptyset \to s < \frac{u_{Pa_{t}}}{u_{t}}(D_{Pa_{t}}+1)) \\
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

If it is a leaf task, the best estimate we have of a completion
time is the end of the time slot it is scheduled at.

$\epsilon : T \to \mathbb{N}$

$$
\epsilon(t) = \begin{cases}
\max_{c \in Ch_{t}} \epsilon(c), & Ch_{t} \neq \emptyset \\
u_{t}D_{t}[s] + \delta_{tD_{t}[i]}, & Ch_t = \emptyset
\end{cases}
$$

The real task completion time is only used for [[#Prerequisites]]
and computing [[#Cost]], it is not used to constrain valid task
starting times. (as that would be circular)

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

