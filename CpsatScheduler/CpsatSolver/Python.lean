import Regex
import Mathlib.Data.Finset.Defs
import Mathlib.Data.Finset.Insert

namespace CpsatSolver.Python

def ReservedKeywords : Finset String := {
  "False",
  "await",
  "else",
  "import",
  "pass",
  "None",
  "break",
  "except",
  "in",
  "raise",
  "True",
  "class",
  "finally",
  "is",
  "return",
  "and",
  "continue",
  "for",
  "lambda",
  "try",
  "as",
  "def",
  "from",
  "nonlocal",
  "while",
  "assert",
  "del",
  "global",
  "not",
  "with",
  "async",
  "elif",
  "if",
  "or",
  "yield"
}

def IDRegex := re! r"^[A-Za-z_][0-9A-Za-z_]+$"

def ValidID (name : String) : Prop :=
  ¬ (name ∈ ReservedKeywords) ∧ (IDRegex.test name)

instance : Decidable (ValidID α) :=
  (inferInstance : Decidable (
    ¬ (α ∈ ReservedKeywords) ∧ (IDRegex.test α)
  ))

end CpsatSolver.Python
