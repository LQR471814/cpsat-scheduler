module

public import CpsatScheduler.Internal.CpsatSolver.Encodability.Basic
public import CpsatScheduler.Internal.CpsatSolver.Encodability.DeriveHasReprPlain
public import CpsatScheduler.Internal.CpsatSolver.Encodability.DeriveHasReprWithProps

/-!
# `HasRepr` instances for the solver types

Flat `List ℕ` representations for every solver type, replacing the `Encodable`
instances (whose `Nat.pair` composition blew up to hundreds of MB on large
nested values).  Generic combinators and the base instances live in
`Encodability.Defs`; the derive macros generate the per-type encoders here.
-/

public section

namespace CpsatSolver

derive_has_repr_plain IntVar
derive_has_repr_plain BoolVar
derive_has_repr_plain BoolLit
derive_has_repr_plain UnitAwareIntVar
derive_has_repr_plain LinearExpr.Raw

derive_has_repr_with_props LinearExpr
derive_has_repr_with_props FixedSizeIntervalVar

derive_has_repr_plain BoundedLinearExpr.Rel
derive_has_repr_plain BoundedLinearExpr
derive_has_repr_plain Constraint.CumulativeItem

/-- `Constraint.Enforcement`: tag 0 for `always`, tag 1 carries the literal
    array (the `≠ #[]` proof is proof-irrelevant). -/
instance : HasRepr Constraint.Enforcement where
  toRepr
    | .always => [0]
    | .onlyWhenAll literals _ => 1 :: HasRepr.toRepr literals
  toRepr_inj := by
    intro a b h
    cases a <;> cases b <;>
      simp only [List.cons.injEq] at h
    · rfl
    · exact absurd h.1 (by decide)
    · exact absurd h.1 (by decide)
    · obtain ⟨_, hlits⟩ := h
      have := (HasRepr.toRepr_inj (α := Array BoolLit)) hlits
      subst this
      rfl

/-- `Constraint.Variant`: constructor index as the leading tag, then the data
    fields flattened with `encodeChunks`.  The decidable side-conditions
    (`nonempty`, `divisor_pos`, `within_domain`) are proof-irrelevant and not
    serialized.  `allowed_assignments` packs its implicit `n` with the
    index-dependent `vars`/`rows` as a `Σ`. -/
instance : HasRepr Constraint.Variant where
  toRepr
    | .bounded_linear expr =>
      0 :: HasRepr.toRepr expr
    | .max_equality target exprs _ =>
      1 :: encodeChunks [HasRepr.toRepr target, HasRepr.toRepr exprs]
    | .div_eq target numerator divisor _ =>
      2 :: encodeChunks
        [HasRepr.toRepr target, HasRepr.toRepr numerator, HasRepr.toRepr divisor]
    | .allowed_assignments (n := n) vars rows _ _ =>
      3 :: HasRepr.toRepr
        (⟨n, (vars, rows)⟩ : Σ n : ℕ, Vector IntVar n × Array (Vector Int64 n))
    | .cumulative items capacity =>
      4 :: encodeChunks [HasRepr.toRepr items, HasRepr.toRepr capacity]
    | .bool_and terms _ =>
      5 :: HasRepr.toRepr terms
    | .bool_or terms _ =>
      6 :: HasRepr.toRepr terms
    | .implication src dst =>
      7 :: encodeChunks [HasRepr.toRepr src, HasRepr.toRepr dst]
  toRepr_inj := by
    intro a b h
    cases a <;> cases b <;>
      simp only [List.cons.injEq] at h <;>
      (try (exact absurd h.1 (by decide)))
    -- bounded_linear
    · have := (HasRepr.toRepr_inj (α := BoundedLinearExpr)) h.2
      subst this; rfl
    -- max_equality
    · obtain ⟨_, hc⟩ := h
      replace hc := encodeChunks_inj hc
      simp only [List.cons.injEq, and_true] at hc
      obtain ⟨h1, h2⟩ := hc
      have e1 := (HasRepr.toRepr_inj (α := LinearExpr)) h1
      have e2 := (HasRepr.toRepr_inj (α := Array LinearExpr)) h2
      subst e1; subst e2; rfl
    -- div_eq
    · obtain ⟨_, hc⟩ := h
      replace hc := encodeChunks_inj hc
      simp only [List.cons.injEq, and_true] at hc
      obtain ⟨h1, h2, h3⟩ := hc
      have e1 := (HasRepr.toRepr_inj (α := LinearExpr)) h1
      have e2 := (HasRepr.toRepr_inj (α := LinearExpr)) h2
      have e3 := (HasRepr.toRepr_inj (α := Int64)) h3
      subst e1; subst e2; subst e3; rfl
    -- allowed_assignments
    · have e :=
        (HasRepr.toRepr_inj
          (α := Σ n : ℕ, Vector IntVar n × Array (Vector Int64 n))) h.2
      simp only [Sigma.mk.injEq] at e
      obtain ⟨hn, hrest⟩ := e
      subst hn
      simp only [heq_eq_eq, Prod.mk.injEq] at hrest
      obtain ⟨hv, hr⟩ := hrest
      subst hv; subst hr; rfl
    -- cumulative
    · obtain ⟨_, hc⟩ := h
      replace hc := encodeChunks_inj hc
      simp only [List.cons.injEq, and_true] at hc
      obtain ⟨h1, h2⟩ := hc
      have e1 := (HasRepr.toRepr_inj (α := Array Constraint.CumulativeItem)) h1
      have e2 := (HasRepr.toRepr_inj (α := LinearExpr)) h2
      subst e1; subst e2; rfl
    -- bool_and
    · have := (HasRepr.toRepr_inj (α := Array BoolLit)) h.2
      subst this; rfl
    -- bool_or
    · have := (HasRepr.toRepr_inj (α := Array BoolLit)) h.2
      subst this; rfl
    -- implication
    · obtain ⟨_, hc⟩ := h
      replace hc := encodeChunks_inj hc
      simp only [List.cons.injEq, and_true] at hc
      obtain ⟨h1, h2⟩ := hc
      have e1 := (HasRepr.toRepr_inj (α := BoolLit)) h1
      have e2 := (HasRepr.toRepr_inj (α := BoolLit)) h2
      subst e1; subst e2; rfl

derive_has_repr_plain Constraint
derive_has_repr_plain Objective

end CpsatSolver
