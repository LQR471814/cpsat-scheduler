The current architecture is as follows:

- Lean model manager:
   - Role:
      - Building the cpsat-solver model and interpreting its
        results.
      - Owns python daemon process and communicates with it.
   - Reason:
      - Many aspects of model generation are easy to get wrong,
        correctness is extremely important, and errors can be very
        subtle.
         - Ex. Ensuring integer overflow doesn't happen in cpsat
           expressions. Ensuring correct unit conversions, or the
           edge-case behavior of dates.
      - Because Lean can check more "sophisticated" properties
        about the model at compile time and indicate to the user
        exactly where those properties are violated, the user
        often has a much nicer experience than having CP-SAT
        solver tell you that the model is infeasible.
- Python environment & daemon:
   - Role:
      - Executes code with python `exec()` passed in via STDIN.
   - Reason:
      - Generating standard Python code and executing is easier
        (to implement and maintain), rather than special Lean
        bindings which are unsupported by default.
      - To save on time importing heavy modules like `scipy`.

