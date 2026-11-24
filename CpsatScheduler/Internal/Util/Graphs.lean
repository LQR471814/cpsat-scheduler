module

public import Mathlib.Data.Fintype.Pi

public section

structure FinDigraph.Edge (α : Type) (nodes : Finset α) where
  src : nodes
  dst : nodes
  deriving DecidableEq

structure FinDigraph (α : Type) where
  nodes : Finset α
  edges : Finset (FinDigraph.Edge α nodes)

abbrev FinDigraph.rank (g : FinDigraph α) :=
  Fin g.nodes.card

@[expose]
def FinDigraph.IsAcyclic [DecidableEq α] (g : FinDigraph α) : Prop :=
  ∃ rank : g.nodes → g.rank,
    ∀ edge : g.edges, rank edge.val.src < rank edge.val.dst

instance [DecidableEq α] (g : FinDigraph α)
  : Decidable g.IsAcyclic := by
  unfold FinDigraph.IsAcyclic
  infer_instance

@[expose]
def FinDigraph.IsTree (g : FinDigraph α) : Prop :=
  ∀ n : g.nodes, ∀ e₁ e₂ : g.edges,
    e₁.val.dst = n ∧ e₂.val.dst = n → e₁ = e₂

instance [DecidableEq α] (g : FinDigraph α)
  : Decidable g.IsTree := by
  unfold FinDigraph.IsTree
  infer_instance
