import CpsatScheduler.CpsatSolver.Domain.Interval
import Mathlib.Data.Nat.SuccPred

namespace CpsatSolver

theorem Domain.not_mem_empty (x : ℤ) : x ∉ Domain.empty := by
  rintro ⟨_, h, _⟩
  cases h

theorem Domain.mem_singleton (v : Int64) (x : ℤ) :
    x ∈ Domain.singleton v ↔ x = v.val := by
  constructor
  · rintro ⟨i, hi, hx⟩
    cases hi with
    | head => exact (Interval.mem_fromValue v x).mp hx
    | tail _ h => cases h
  · intro h
    subst h
    exact ⟨Interval.fromValue v, by simp [Domain.singleton],
      (Interval.mem_fromValue v _).mpr rfl⟩

@[simp] def Domain.contains (d : Domain) (x : ℤ) : Bool :=
  d.intervals.any fun i => decide (x ∈ i)

theorem Domain.contains_iff (d : Domain) (x : ℤ) :
    d.contains x = true ↔ x ∈ d := by
  unfold Domain.contains
  rw [List.any_eq_true]
  constructor
  · rintro ⟨i, hi, h⟩
    exact ⟨i, hi, of_decide_eq_true h⟩
  · rintro ⟨i, hi, h⟩
    exact ⟨i, hi, decide_eq_true h⟩

instance {d : Domain} {x : ℤ} : Decidable (x ∈ d) :=
  decidable_of_bool (d.contains x) (Domain.contains_iff d x)

@[simp] def Domain.min? (d : Domain) : Option Int64 :=
  d.intervals.head?.map (·.left)

@[simp] def Domain.max? (d : Domain) : Option Int64 :=
  d.intervals.getLast?.map (·.right)

private theorem mem_head_cons {α : Type} {a : α} {t : List α} : a ∈ a :: t :=
  List.mem_cons.mpr (Or.inl rfl)

theorem Domain.head_le_getLast {l : List Interval}
    (hp : l.Pairwise Interval.separated) (hne : l ≠ []) :
    ((l.head hne).left : ℤ) ≤ (l.getLast hne).right := by
  match l with
  | [] => exact (hne rfl).elim
  | [a] => exact a.left_le_right
  | a :: b :: t =>
    have hp' : (b :: t).Pairwise Interval.separated := (List.pairwise_cons.mp hp).2
    have hsep : Interval.separated a b := (List.pairwise_cons.mp hp).1 b mem_head_cons
    have ih := Domain.head_le_getLast hp' (List.cons_ne_nil b t)
    have hlast :
        ((a :: b :: t).getLast (List.cons_ne_nil _ _)) =
          (b :: t).getLast (List.cons_ne_nil _ _) :=
      List.getLast_cons (List.cons_ne_nil b t)
    have hle : (a.left : ℤ) ≤ (b.left : ℤ) := by
      have hlr := a.left_le_right
      have hs : (a.right : ℤ) + 1 < (b.left : ℤ) := hsep
      linarith
    rw [List.head_cons, hlast]
    exact le_trans hle ih

@[simp] def Domain.hullOf (d : Domain) (hne : d.intervals ≠ []) : Interval :=
  {
    left := d.intervals.head hne |>.left
    right := d.intervals.getLast hne |>.right
    left_le_right := Domain.head_le_getLast d.pairwise hne
  }

theorem Domain.separated_left_lt {a b : Interval} (h : Interval.separated a b) :
    (a.left : ℤ) < b.left := by
  have hlr := a.left_le_right
  have hs : (a.right : ℤ) + 1 < (b.left : ℤ) := h
  linarith

theorem Domain.separated_right_lt {a b : Interval} (h : Interval.separated a b) :
    (a.right : ℤ) < b.right := by
  have hlr := b.left_le_right
  have hs : (a.right : ℤ) + 1 < (b.left : ℤ) := h
  linarith

theorem Domain.mem_le_of_mem {l : List Interval}
    (hp : l.Pairwise Interval.separated) {i : Interval} (hi : i ∈ l) :
    ((l.head (List.ne_nil_of_mem hi)).left : ℤ) ≤ (i.left : ℤ) ∧
      (i.right : ℤ) ≤ ((l.getLast (List.ne_nil_of_mem hi)).right : ℤ) := by
  induction l generalizing i with
  | nil => cases hi
  | cons a t ih =>
    rcases List.mem_cons.mp hi with rfl | hit
    · constructor
      · exact le_rfl
      · cases t with
        | nil => exact le_rfl
        | cons b u =>
          have hp' := (List.pairwise_cons.mp hp).2
          have hsep : Interval.separated i b :=
            (List.pairwise_cons.mp hp).1 b mem_head_cons
          have hb := ih hp' mem_head_cons
          have hlast :
              ((i :: b :: u).getLast (List.cons_ne_nil _ _)) =
                (b :: u).getLast (List.cons_ne_nil _ _) :=
            List.getLast_cons (List.cons_ne_nil b u)
          rw [hlast]
          exact le_trans (le_of_lt (Domain.separated_right_lt hsep)) hb.2
    · have hp' := (List.pairwise_cons.mp hp).2
      have ih' := ih hp' hit
      cases t with
      | nil => cases hit
      | cons b u =>
        have hsep : Interval.separated a b :=
          (List.pairwise_cons.mp hp).1 b mem_head_cons
        have hlast :
            ((a :: b :: u).getLast (List.cons_ne_nil _ _)) =
              (b :: u).getLast (List.cons_ne_nil _ _) :=
          List.getLast_cons (List.cons_ne_nil b u)
        constructor
        · have hbl : (b.left : ℤ) ≤ i.left := by
            simpa using ih'.1
          exact le_trans (le_of_lt (Domain.separated_left_lt hsep)) hbl
        · simpa [hlast] using ih'.2

theorem Domain.mem_hull (d : Domain) (hne : d.intervals ≠ []) {x : ℤ}
    (hx : x ∈ d) : x ∈ d.hullOf hne := by
  obtain ⟨i, hi, hxi⟩ := hx
  have hbounds := Domain.mem_le_of_mem d.pairwise hi
  change ((d.intervals.head hne).left : ℤ) ≤ x ∧
    x ≤ ((d.intervals.getLast hne).right : ℤ)
  exact ⟨le_trans hbounds.1 hxi.1, le_trans hxi.2 hbounds.2⟩

def Domain.mergeOne (x : Interval) : List Interval → List Interval
  | [] => [x]
  | a :: t =>
    if (x.right : ℤ) + 1 < (a.left : ℤ) then
      x :: a :: t
    else if (a.right : ℤ) + 1 < (x.left : ℤ) then
      a :: Domain.mergeOne x t
    else
      Domain.mergeOne (x.span a) t
termination_by l => l.length

theorem Domain.mergeOne_ne_nil (x : Interval) :
    ∀ l, Domain.mergeOne x l ≠ [] := by
  intro l
  induction l generalizing x with
  | nil =>
    simp only [Domain.mergeOne]
    exact List.cons_ne_nil _ _
  | cons a t ih =>
    unfold Domain.mergeOne
    split_ifs
    · exact List.cons_ne_nil _ _
    · exact List.cons_ne_nil _ _
    · exact ih (x.span a)

def Domain.canonicalize : List Interval → List Interval
  | [] => []
  | x :: xs => Domain.mergeOne x (Domain.canonicalize xs)

theorem Domain.mergeOne_separated_of
    (a x : Interval) (t : List Interval)
    (ha_x : Interval.separated a x)
    (ha_t : ∀ y ∈ t, Interval.separated a y) :
    ∀ y ∈ Domain.mergeOne x t, Interval.separated a y := by
  induction t generalizing x with
  | nil =>
    intro y hy
    simp only [Domain.mergeOne] at hy
    cases hy with
    | head => exact ha_x
    | tail _ h => cases h
  | cons b u ih =>
    intro y hy
    unfold Domain.mergeOne at hy
    split_ifs at hy with hBefore hAfter
    · rcases List.mem_cons.mp hy with rfl | hy
      · exact ha_x
      · exact ha_t y hy
    · rcases List.mem_cons.mp hy with rfl | hy
      · exact ha_t y mem_head_cons
      · exact ih x ha_x (fun y hy => ha_t y (List.mem_cons.mpr (Or.inr hy))) y hy
    · exact ih (x.span b)
        (Interval.separated_span ha_x (ha_t b mem_head_cons))
        (fun y hy => ha_t y (List.mem_cons.mpr (Or.inr hy))) y hy

theorem Domain.mergeOne_pairwise (x : Interval) :
    ∀ l, l.Pairwise Interval.separated →
      (Domain.mergeOne x l).Pairwise Interval.separated := by
  intro l hl
  induction l generalizing x with
  | nil =>
    simp only [Domain.mergeOne]
    exact List.pairwise_singleton _ _
  | cons a t ih =>
    unfold Domain.mergeOne
    split_ifs with hBefore hAfter
    · refine List.pairwise_cons.mpr ⟨?_, hl⟩
      intro y hy
      rcases List.mem_cons.mp hy with rfl | hy
      · exact hBefore
      · exact Interval.separated_trans hBefore
          ((List.pairwise_cons.mp hl).1 y hy)
    · refine List.pairwise_cons.mpr ⟨?_, ih x (List.pairwise_cons.mp hl).2⟩
      intro y hy
      exact Domain.mergeOne_separated_of a x t hAfter
        (fun y hy => (List.pairwise_cons.mp hl).1 y hy) y hy
    · exact ih (x.span a) (List.pairwise_cons.mp hl).2

theorem Domain.canonicalize_pairwise (l : List Interval) :
    (Domain.canonicalize l).Pairwise Interval.separated := by
  induction l with
  | nil => exact List.Pairwise.nil
  | cons x xs ih => exact Domain.mergeOne_pairwise x _ ih

@[simp] def Domain.ofList (xs : List Interval) : Domain :=
  ⟨Domain.canonicalize xs, Domain.canonicalize_pairwise xs⟩

theorem Domain.canonicalize_cons_ne_nil (x : Interval) (xs : List Interval) :
    Domain.canonicalize (x :: xs) ≠ [] :=
  Domain.mergeOne_ne_nil x (Domain.canonicalize xs)

@[simp] def Domain.ofArray (xs : Array Interval) : Domain :=
  Domain.ofList xs.toList

@[simp] def Domain.insert (d : Domain) (i : Interval) : Domain :=
  ⟨Domain.mergeOne i d.intervals, Domain.mergeOne_pairwise i d.intervals d.pairwise⟩

@[simp] def Domain.union (a b : Domain) : Domain :=
  b.intervals.foldl Domain.insert a

@[simp] def Domain.inter (a b : Domain) : Domain :=
  Domain.ofList (a.intervals.flatMap fun ia =>
    b.intervals.filterMap (fun ib => ia.inter? ib))

@[simp] def Domain.interval (i : Interval) : Domain :=
  ⟨[i], List.pairwise_singleton _ _⟩

theorem Domain.mem_interval (i : Interval) (x : ℤ) :
    x ∈ Domain.interval i ↔ x ∈ i := by
  constructor
  · rintro ⟨j, hj, hx⟩
    cases hj with
    | head => exact hx
    | tail _ h => cases h
  · intro hx
    exact ⟨i, by simp [Domain.interval], hx⟩

def Domain.ofListNonempty (xs : List Interval) (h : xs ≠ []) : NonemptyDomain :=
  match xs, h with
  | [], h => (h rfl).elim
  | x :: rest, _ =>
    ⟨Domain.ofList (x :: rest), Domain.canonicalize_cons_ne_nil x rest⟩

end CpsatSolver
