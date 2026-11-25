module

import Mathlib.Logic.Encodable.Basic
import CpsatScheduler.Internal.CpsatSolver.Encodability.DeriveEncodablePlain

structure Foo where
  foo : ℤ
  bar : ℤ
deriving DecidableEq
derive_encodable_plain Foo

