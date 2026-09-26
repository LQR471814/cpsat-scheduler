import Lean.Data.Json
import CpsatScheduler.Python

namespace Scipy

namespace Name
def scipy := Python.ValidName.of "scipy"
def stats := Python.ValidName.of "stats"
def beta := Python.ValidName.of "beta"
def print := Python.ValidName.of "print"
def cdf := Python.ValidName.of "cdf"
def float := Python.ValidName.of "float"
def json := Python.ValidName.of "json"
def dumps := Python.ValidName.of "dumps"
end Name

private def flit (f : Float) : Python.Expr := .lit (.float f)

def cdfScalarUnchecked (x alpha beta : Float) : Python.Expr :=
  .call (.id Name.float)
    #[.call (.dot (.id Name.beta) Name.cdf) #[flit x, flit alpha, flit beta]]

end Scipy
