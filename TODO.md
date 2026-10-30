- [ ] Refactor:
   - [ ] IDs
   - [ ] PERT construction
      - PERT should be computed in pure Lean, studies already show
        the dubious effect the actual distribution has on the
        accuracy of the PERT estimation.
   - [ ] Objective construction
      - This should include support for weighted sum of multiple
        objectives.
   - [ ] Registrar
      - [ ] Address parent/child task construction
         - This is currently impossible due to monads making
           definitions opaque.
- [ ] Features:
   - [ ] Task blocking
   - [ ] Address time fragmentation issues:
      - Currently costly to shrink task duration.
      - When free time is very fragmented, output schedule can be
        unnecessarily costly because tasks cannot be broken up.
      - Solution may be to create "time compensation reward"
        (negative cost) for expanding task duration?
         - Where upper bound on "time compensation" is the current
           total cost incurred by sibling tasks?
      - Still some tasks have a minimum amount of time required to
        "get started" on them, this is another constraint which
        must be accounted for.
   - [ ] Early biasing: A tiny cost for early completion.
   - [ ] Complexity matching: A small cost for mismatched
     complexity and mental energy.
   - [ ] Additional location & time restrictions:
      - [ ] Sometimes, certain tasks must be performed on the
        weekends (or under additional constraints, like RRULE
        restriction on start times).
      - [ ] Certain tasks may also be performed in certain
        locations, which the individual may not be in all the
        time.
