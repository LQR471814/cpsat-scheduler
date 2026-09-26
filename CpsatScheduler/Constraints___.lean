import CpsatScheduler.Defs
import CpsatScheduler.Graphs

namespace CpsatScheduler

/-- Parents form a forest: at most one immediate parent, acyclic, and strict
unit growth on every edge. Multiple roots are allowed. -/
def ParentsForest {scales : Timescales} [DecidableEq (Task scales)]
    (g : FinDigraph (Task scales)) : Prop :=
  g.IsTree ∧ g.IsAcyclic ∧
    ∀ e : g.edges, e.val.src.val.unit.val.val < e.val.dst.val.unit.val.val

def PrerequisitesAcyclic {scales : Timescales} [DecidableEq (Task scales)]
    (g : FinDigraph (Task scales)) : Prop :=
  g.IsAcyclic

end CpsatScheduler
