# CP-SAT Scheduler

> Declarative time management with a globally optimizing
> constraint solver powered by [Google's or-tools](https://developers.google.com/optimization).

## Justification

Typically, time management looks like a calendar with blocked out
sections, a TO-DO list, or a routine. This is all well and good
for many people, and many cases, but things get more difficult
   once one wishes to answer questions like:

- "What happens to my schedule and my other responsibilities if I
  take on this project?"
- "What if I trade off time on less important (but urgent) tasks
  for increased risk of not completing on time, but gain time to
     do more important tasks (that might be less urgent)?"
- "Can I still meet my deadlines if I break up a large task into
  many smaller chunks to be done on different days, in light of my
  other deadlines?"
- "What if I want to prefer complex work to be done at times in
  the day when I have more mental energy?" (see ["Cognitive
  Performance"](/docs/MATHEMATICS.md#cognitive-performance))

The real trouble is that every part of a schedule can affect every
other part of the schedule. If I suddenly find out that it will
take me twice as long to do some large task, I will need to
reevaluate all the timetables for all the other tasks which had
previously been formulated on the assumption that I would have
much more time than I do now. I would also need to weigh the
trade-offs for tasks which can have variable durations or flexible
deadlines, as well as their effects on the tasks which depend on
those tasks, etc...

All in all, this means that manual scheduling has serious scaling
limits. For every task and responsibility you take on, the amount
of *options* you have for your schedule grows extremely fast.

As such, it would be useful to have a solver that allows one to
*declare* components, constraints, and trade-offs they are subject
to, then have the solver compute an optimal schedule under the
model you have defined. This solver would also make it trivial to
examine the effects of changing components, adding
responsibilities, etc...

This is what this project aims to do,

## Documentation

- [Mathematics](docs/MATHEMATICS.md) - formal model for scheduling
- [Architecture](/docs/ARCHITECTURE.md) - software architecture

## Additional resources

- [CP-SAT Primer](https://github.com/d-krupke/cpsat-primer#search-core) - learn how to use CP-SAT solver
- [CP-SAT Log Visualizer](https://cpsat-log-analyzer.streamlit.app/) - for performance debugging

