module

public import CpsatScheduler.Internal.CpsatSolver.Encodability.Basic
public import CpsatScheduler.Internal.CpsatSolver.Encodability.DeriveHasReprPlain

public section

structure Foo where
  foo : ℤ
  bar : ℤ
deriving DecidableEq
derive_has_repr_plain Foo
