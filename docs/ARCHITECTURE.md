# Main components

1. Core solver:
    - A python gRPC daemon packaged into an executable with Nuitka
    - Google's CP-SAT solver:
        - Well-regarded
        - Flexible problem domains
        - Scalable, up to millions of variables
        - Doing *very rough* asymptotic analysis for variables
          based on config complexity, we get something like
          $O(TCI)$ where:
            - $T$ is the number of tasks
            - $C$ is the avg. # of cost configs per task
                - This is usually < 10.
            - $I$ is the avg. # of cost intervals per cost config
                - This is usually 2
            - So overall, we can say that it is *roughly linear*
              with regard to the # of tasks.
                - Where roughly is doing a *lot* of heavy lifting.
2. Backend:
    - A Golang gRPC daemon that communicates with the solver and
      manages high-level state in a SQLite database.
    - SQLite because:
        - Simple, no daemons, no infrastructure
        - Pure-go driver for SQLite, extremely simple builds.
        - Surprisingly scalable, I am estimating that most usages
          of this software will not exceed 1 million rows.
        - Mature [sqlc](https://sqlc.dev/) code generation for
          Golang to reduce boilerplate writing.
    - Golang because:
        - I am relatively experienced with it
        - Simple
        - Mature standard library + gRPC support
        - Performant (for this purpose) and lightweight
        - Strong tooling, trivial builds
3. Frontend:
    - A nushell CLI tool that communicates with the backend via
      `buf curl`.
    - CLI & specifically nushell because:
        - Flexible for automation & programmability:
            - You can script natively, no need for plugin layers,
              extensions, etc...
        - Fast to write & iterate
            - Compared to maintaining a complex user-interface,
              the "CLI-UI hybrid" devised here retains all the
              benefits of being somewhat intuitive and
              user-friendly while being powerful.

