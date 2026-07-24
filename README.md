# CP-SAT Scheduler

CP-SAT Scheduler is an experimental scheduler that uses Google
OR-Tools' CP-SAT solver to place tasks on a discrete time grid.
The current codebase is a Python package for building scheduling
models, expressing costs and constraints, solving them, and
printing or viewing the resulting schedule.

## Project Layout

- `src/cpsatscheduler/backend/` - core CP-SAT model configuration,
  task builders, unit types, and solution printing helpers.
- `src/cpsatscheduler/frontend/` - higher-level scheduling helpers
  for real datetimes, time units, PERT-style estimates, and cost
      topology utilities.
- `examples/` - Examples of scheduling scenarios.
- `tests/` - pytest coverage for CP-SAT behavior demos and
  expected solver output.
- `docs/` - design notes and reference material for the scheduler
  model and planned architecture.

## Development

This project targets Python 3.13 and uses `uv`.

```sh
uv sync
uv run pytest
uv run ruff check
uv run ty check
```

## Documentation

- [Design](docs/DESIGN.md) - high level "scheduling philosophy",
  covers core concepts, design & UX
- [Mathematics](docs/MATHEMATICS.md) - formal model for scheduling
- [CP-SAT proto](docs/cp_model.proto) - local copy/reference for
  CP-SAT model protobuf structures.
