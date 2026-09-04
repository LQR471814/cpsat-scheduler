import Mathlib.Data.Finset.Card
import Mathlib.Data.Fintype.Pi

structure FinDigraph.Edge (α : Type) (nodes : Finset α) where
  src : nodes
  dst : nodes
  deriving DecidableEq

structure FinDigraph (α : Type) where
  nodes : Finset α
  edges : Finset (FinDigraph.Edge α nodes)

abbrev FinDigraph.rank (g : FinDigraph α) :=
  Fin g.nodes.card

abbrev FinDigraph.IsAcyclic [DecidableEq α] (g : FinDigraph α) : Prop :=
  -- since g.nodes, g.rank, and the ∀ predicate are finite, ∃ is decidable via
  -- infer_instance
  ∃ rank : g.nodes → g.rank,
    -- since g.edges is finite and rank a < rank b is decidable, ∀ is decidable
    ∀ edge : g.edges, rank edge.val.src < rank edge.val.dst

instance [DecidableEq α] (g : FinDigraph α)
  : Decidable g.IsAcyclic := inferInstance

-- we ensure that if dst are the same, src must also be
-- this means that dst is the parent
abbrev FinDigraph.IsTree (g : FinDigraph α) : Prop :=
  ∀ n : g.nodes, ∀ e₁ e₂ : g.edges,
    e₁.val.dst = n ∧ e₂.val.dst = n → e₁ = e₂

instance [DecidableEq α] (g : FinDigraph α)
  : Decidable g.IsTree := inferInstance



private def exampleGraph : FinDigraph String := {
  nodes := { "a", "b", "c" },
  edges := {
    {
      src := { val := "a", property := by decide },
      dst := { val := "b", property := by decide }
    },
    {
      src := { val := "b", property := by decide },
      dst := { val := "c", property := by decide }
    },
    {
      src := { val := "a", property := by decide },
      dst := { val := "c", property := by decide }
    }
  }
}

example : exampleGraph.IsAcyclic := by decide

#eval decide exampleGraph.IsTree

