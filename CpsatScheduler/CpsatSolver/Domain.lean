import Mathlib

set_option linter.mathlibStandardSet false
set_option linter.style.longLine false
set_option linter.style.setOption false

namespace CpsatSolver

abbrev Int64.min : ℤ := -(2 : ℤ) ^ 63
abbrev Int64.max : ℤ := (2 : ℤ) ^ 63 - 1
abbrev Int64.Nonoverflow (b : ℤ) : Prop :=
  b ≥ min ∧ b ≤ max

theorem Int64.proof_ediv_of_pos {a divisor : ℤ}
    (ha : Int64.Nonoverflow a) (hdivisor : 0 < divisor) :
    Int64.Nonoverflow (a / divisor) := by
  constructor
  · change Int64.min ≤ a / divisor
    rw [Int.le_ediv_iff_mul_le hdivisor]
    unfold Int64.min
    nlinarith [ha.1]
  · rw [Int.ediv_le_iff_le_mul hdivisor]
    unfold Int64.max
    nlinarith [ha.2]

theorem Int64.proof_of_mul_left {a b : ℤ}
    (hb : b ≠ 0)
    (h₁ : ¬(a = (2 : ℤ) ^ 63 ∧ b = -1))
    (h : Int64.Nonoverflow (a * b)) :
    Int64.Nonoverflow a := by
  obtain ⟨hab_min, hab_max⟩ := h
  constructor
  · by_contra hna
    have ha' : a ≤ -((2 : ℤ) ^ 63) - 1 := by
      unfold min at hna
      omega
    cases lt_or_gt_of_ne hb with
    | inl hbneg =>
      have hb1 : b ≤ -1 := by omega
      have : (2 : ℤ) ^ 63 ≤ a * b := by nlinarith
      unfold max at hab_max
      omega
    | inr hbpos =>
      have hb1 : 1 ≤ b := by omega
      have : a * b ≤ -((2 : ℤ) ^ 63) - 1 := by nlinarith
      unfold min at hab_min
      omega
  · by_contra hna
    have ha' : (2 : ℤ) ^ 63 ≤ a := by
      unfold max at hna
      omega
    cases lt_or_gt_of_ne hb with
    | inl hbneg =>
      have hb1 : b ≤ -1 := by omega
      have hle : a * b ≤ (2 : ℤ) ^ 63 * b := by nlinarith
      have hle' : (2 : ℤ) ^ 63 * b ≤ -((2 : ℤ) ^ 63) := by nlinarith
      have heq_prod : a * b = -((2 : ℤ) ^ 63) := by
        unfold min at hab_min
        omega
      have hb_eq : b = -1 := by nlinarith
      have ha_eq : a = (2 : ℤ) ^ 63 := by nlinarith
      exact h₁ ⟨ha_eq, hb_eq⟩
    | inr hbpos =>
      have hb1 : 1 ≤ b := by omega
      have : (2 : ℤ) ^ 63 ≤ a * b := by nlinarith
      unfold max at hab_max
      omega

theorem Int64.proof_of_mul {a b : ℤ}
    (ha : a ≠ 0)
    (hb : b ≠ 0)
    (h₁ : ¬(a = (2 : ℤ) ^ 63 ∧ b = -1))
    (h₂ : ¬(a = -1 ∧ b = (2 : ℤ) ^ 63))
    (h : Int64.Nonoverflow (a * b)) :
    Int64.Nonoverflow a ∧ Int64.Nonoverflow b :=
  ⟨Int64.proof_of_mul_left hb h₁ h,
   Int64.proof_of_mul_left ha (by
     intro hba
     exact h₂ ⟨hba.2, hba.1⟩) (by simpa [mul_comm] using h)⟩

structure Int64 where
  val : ℤ
  nonoverflow : Int64.Nonoverflow val
deriving DecidableEq

instance : Coe Int64 ℤ where
  coe proven := proven.val

def Int64.of (n : ℤ) (h : Int64.Nonoverflow n := by decide) : Int64 :=
  ⟨n, h⟩

/-- Closed interval over `Int64`. Also used as conservative expression bounds. -/
structure Interval where
  left : Int64
  right : Int64
  left_le_right : (left : ℤ) ≤ right
deriving DecidableEq

abbrev Bounds := Interval

instance : Membership ℤ Interval where
  mem i x := (i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)

instance {i : Interval} {x : ℤ} : Decidable (x ∈ i) :=
  inferInstanceAs (Decidable ((i.left : ℤ) ≤ x ∧ x ≤ (i.right : ℤ)))

def Interval.toSet (i : Interval) : Set ℤ :=
  Set.Icc (i.left : ℤ) i.right

theorem Interval.mem_toSet (i : Interval) (x : ℤ) :
    x ∈ i.toSet ↔ x ∈ i := Iff.rfl

def Interval.fromValue (v : Int64) : Interval :=
  { left := v, right := v, left_le_right := le_rfl }

theorem Interval.mem_fromValue (v : Int64) (x : ℤ) :
    x ∈ Interval.fromValue v ↔ x = v.val := by
  constructor
  · intro h
    exact le_antisymm h.2 h.1
  · intro h
    subst h
    exact ⟨le_rfl, le_rfl⟩

def Interval.ofBounds (left right : ℤ)
    (nonoverflow : Int64.Nonoverflow left ∧ Int64.Nonoverflow right)
    (left_le_right : left ≤ right) : Interval :=
  {
    left := { val := left, nonoverflow := nonoverflow.1 }
    right := { val := right, nonoverflow := nonoverflow.2 }
    left_le_right := left_le_right
  }

def Interval.neg (i : Interval)
    (h : Int64.Nonoverflow (-i.right : ℤ) ∧ Int64.Nonoverflow (-i.left : ℤ)) :
    Interval :=
  {
    left := { val := -(i.right : ℤ), nonoverflow := h.left }
    right := { val := -(i.left : ℤ), nonoverflow := h.right }
    left_le_right := Int.neg_le_neg i.left_le_right
  }

theorem Interval.eval_neg (i : Interval)
    (h : Int64.Nonoverflow (-i.right : ℤ) ∧ Int64.Nonoverflow (-i.left : ℤ))
    {x : ℤ} (hx : x ∈ i) : -x ∈ i.neg h := by
  have hx1 := hx.1
  have hx2 := hx.2
  change (-i.right : ℤ) ≤ -x ∧ -x ≤ (-i.left : ℤ)
  constructor <;> linarith

def Interval.add (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow ((a.left : ℤ) + b.left) ∧
      Int64.Nonoverflow ((a.right : ℤ) + b.right)) : Interval :=
  Interval.ofBounds ((a.left : ℤ) + b.left) ((a.right : ℤ) + b.right)
    nonoverflow (add_le_add a.left_le_right b.left_le_right)

theorem Interval.eval_add (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow ((a.left : ℤ) + b.left) ∧
      Int64.Nonoverflow ((a.right : ℤ) + b.right))
    {x y : ℤ} (hx : x ∈ a) (hy : y ∈ b) :
    x + y ∈ a.add b nonoverflow := by
  change (a.left : ℤ) + b.left ≤ x + y ∧ x + y ≤ (a.right : ℤ) + b.right
  constructor <;> linarith [hx.1, hx.2, hy.1, hy.2]

def Interval.sub (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow ((a.left : ℤ) - b.right) ∧
      Int64.Nonoverflow ((a.right : ℤ) - b.left)) : Interval :=
  Interval.ofBounds ((a.left : ℤ) - b.right) ((a.right : ℤ) - b.left)
    nonoverflow (by linarith [a.left_le_right, b.left_le_right])

theorem Interval.eval_sub (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow ((a.left : ℤ) - b.right) ∧
      Int64.Nonoverflow ((a.right : ℤ) - b.left))
    {x y : ℤ} (hx : x ∈ a) (hy : y ∈ b) :
    x - y ∈ a.sub b nonoverflow := by
  change (a.left : ℤ) - b.right ≤ x - y ∧ x - y ≤ (a.right : ℤ) - b.left
  constructor <;> linarith [hx.1, hx.2, hy.1, hy.2]

def Interval.mulLower (a b : Interval) : ℤ :=
  min (min ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right))
      (min ((a.right : ℤ) * b.left) ((a.right : ℤ) * b.right))

def Interval.mulUpper (a b : Interval) : ℤ :=
  max (max ((a.left : ℤ) * b.left) ((a.left : ℤ) * b.right))
      (max ((a.right : ℤ) * b.left) ((a.right : ℤ) * b.right))

theorem Interval.mulLower_le_mulUpper (a b : Interval) :
    a.mulLower b ≤ a.mulUpper b := by
  unfold mulLower mulUpper
  exact (min_le_left _ _).trans ((min_le_left _ _).trans ((le_max_left _ _).trans (le_max_left _ _)))

def Interval.mul (a b : Interval)
    (nonoverflow :
      Int64.Nonoverflow (a.mulLower b) ∧
      Int64.Nonoverflow (a.mulUpper b)) : Interval :=
  Interval.ofBounds (a.mulLower b) (a.mulUpper b) nonoverflow (a.mulLower_le_mulUpper b)

theorem Interval.mul_const_mem (a : Interval) (value : Int64) (x : ℤ)
    (hx : x ∈ a)
    (nonoverflow :
      Int64.Nonoverflow (a.mulLower (Interval.fromValue value)) ∧
      Int64.Nonoverflow (a.mulUpper (Interval.fromValue value))) :
    value.val * x ∈ a.mul (Interval.fromValue value) nonoverflow := by
  change
    a.mulLower (Interval.fromValue value) ≤ value.val * x ∧
      value.val * x ≤ a.mulUpper (Interval.fromValue value)
  have hlo :
      a.mulLower (Interval.fromValue value) =
        min ((a.left : ℤ) * value.val) ((a.right : ℤ) * value.val) := by
    simp only [Interval.mulLower, Interval.fromValue, min_self]
  have hhi :
      a.mulUpper (Interval.fromValue value) =
        max ((a.left : ℤ) * value.val) ((a.right : ℤ) * value.val) := by
    simp only [Interval.mulUpper, Interval.fromValue, max_self]
  rw [hlo, hhi]
  rcases le_total (0 : ℤ) value.val with hv | hv
  · have h1 := mul_le_mul_of_nonneg_right hx.1 hv
    have h2 := mul_le_mul_of_nonneg_right hx.2 hv
    constructor
    · exact (min_le_left _ _).trans (h1.trans_eq (mul_comm x value.val))
    · refine (le_of_eq (mul_comm value.val x)).trans (h2.trans (le_max_right _ _))
  · have h1 := mul_le_mul_of_nonpos_right hx.1 hv
    have h2 := mul_le_mul_of_nonpos_right hx.2 hv
    constructor
    · exact (min_le_right _ _).trans (h2.trans_eq (mul_comm x value.val))
    · refine (le_of_eq (mul_comm value.val x)).trans (h1.trans (le_max_left _ _))

/-- Consecutive domain fragments must have a gap of at least one integer. -/
def Interval.separated (a b : Interval) : Prop :=
  (a.right : ℤ) + 1 < (b.left : ℤ)

instance : DecidableRel Interval.separated :=
  fun a b => inferInstanceAs (Decidable ((a.right : ℤ) + 1 < (b.left : ℤ)))

/-- Canonical sparse domain: pairwise separated, hence sorted, disjoint, and
nonadjacent. Empty domains are allowed. -/
structure Domain where
  intervals : List Interval
  pairwise : intervals.Pairwise Interval.separated
deriving DecidableEq

instance : Membership ℤ Domain where
  mem d x := ∃ i ∈ d.intervals, x ∈ i

def Domain.toSet (d : Domain) : Set ℤ := {x | x ∈ d}

def Domain.empty : Domain :=
  ⟨[], List.Pairwise.nil⟩

theorem Domain.not_mem_empty (x : ℤ) : x ∉ Domain.empty := by
  rintro ⟨_, h, _⟩
  cases h

def Domain.singleton (v : Int64) : Domain :=
  ⟨[Interval.fromValue v], List.pairwise_singleton _ _⟩

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

def Domain.contains (d : Domain) (x : ℤ) : Bool :=
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

def Domain.min? (d : Domain) : Option Int64 :=
  d.intervals.head?.map (·.left)

def Domain.max? (d : Domain) : Option Int64 :=
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

def Domain.hullOf (d : Domain) (hne : d.intervals ≠ []) : Interval :=
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

theorem Interval.separated_trans {x a y : Interval}
    (hxa : Interval.separated x a) (hay : Interval.separated a y) :
    Interval.separated x y := by
  have hlr := a.left_le_right
  have hx : (x.right : ℤ) + 1 < (a.left : ℤ) := hxa
  have hy : (a.right : ℤ) + 1 < (y.left : ℤ) := hay
  have : (x.right : ℤ) + 1 < (y.left : ℤ) := by linarith
  exact this

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

def Interval.span (a b : Interval) : Interval :=
  {
    left := if (a.left : ℤ) ≤ b.left then a.left else b.left
    right := if (a.right : ℤ) ≤ b.right then b.right else a.right
    left_le_right := by
      have ha := a.left_le_right
      have hb := b.left_le_right
      split_ifs with hl hr
      · exact le_trans ha hr
      · exact ha
      · exact hb
      · exact le_trans (le_of_not_ge hl) ha
  }

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

theorem Interval.span_left (a b : Interval) :
    ((a.span b).left : ℤ) = min (a.left : ℤ) (b.left : ℤ) := by
  unfold Interval.span
  dsimp
  split_ifs with h
  · exact (min_eq_left h).symm
  · exact (min_eq_right (le_of_not_ge h)).symm

theorem Interval.span_right (a b : Interval) :
    ((a.span b).right : ℤ) = max (a.right : ℤ) (b.right : ℤ) := by
  unfold Interval.span
  dsimp
  split_ifs with h
  · exact (max_eq_right h).symm
  · exact (max_eq_left (le_of_not_ge h)).symm

theorem Interval.mem_span (a b : Interval) {x : ℤ} :
    x ∈ a.span b ↔
      min (a.left : ℤ) b.left ≤ x ∧ x ≤ max (a.right : ℤ) b.right := by
  constructor
  · intro h
    rw [← Interval.span_left, ← Interval.span_right]
    exact h
  · intro h
    rw [← Interval.span_left, ← Interval.span_right] at h
    exact h

theorem Interval.separated_span {a x b : Interval}
    (hx : Interval.separated a x) (hb : Interval.separated a b) :
    Interval.separated a (x.span b) := by
  change (a.right : ℤ) + 1 < ((x.span b).left : ℤ)
  rw [Interval.span_left]
  exact lt_min hx hb

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

def Domain.ofList (xs : List Interval) : Domain :=
  ⟨Domain.canonicalize xs, Domain.canonicalize_pairwise xs⟩

theorem Domain.canonicalize_cons_ne_nil (x : Interval) (xs : List Interval) :
    Domain.canonicalize (x :: xs) ≠ [] :=
  Domain.mergeOne_ne_nil x (Domain.canonicalize xs)

def Domain.ofArray (xs : Array Interval) : Domain :=
  Domain.ofList xs.toList

def Domain.insert (d : Domain) (i : Interval) : Domain :=
  ⟨Domain.mergeOne i d.intervals, Domain.mergeOne_pairwise i d.intervals d.pairwise⟩

def Domain.union (a b : Domain) : Domain :=
  b.intervals.foldl Domain.insert a

def Int64.max' (a b : Int64) : Int64 :=
  if (a : ℤ) ≤ b then b else a

def Int64.min' (a b : Int64) : Int64 :=
  if (a : ℤ) ≤ b then a else b

def Interval.inter? (a b : Interval) : Option Interval :=
  if h : (Int64.max' a.left b.left : ℤ) ≤ Int64.min' a.right b.right then
    some {
      left := Int64.max' a.left b.left
      right := Int64.min' a.right b.right
      left_le_right := h
    }
  else
    none

theorem Int64.le_max'_left (a b : Int64) : (a : ℤ) ≤ Int64.max' a b := by
  unfold Int64.max'
  split_ifs with h
  · exact h
  · exact le_rfl

theorem Int64.le_max'_right (a b : Int64) : (b : ℤ) ≤ Int64.max' a b := by
  unfold Int64.max'
  split_ifs with h
  · exact le_rfl
  · exact le_of_not_ge h

theorem Int64.min'_le_left (a b : Int64) : (Int64.min' a b : ℤ) ≤ a := by
  unfold Int64.min'
  split_ifs with h
  · exact le_rfl
  · exact le_of_not_ge h

theorem Int64.min'_le_right (a b : Int64) : (Int64.min' a b : ℤ) ≤ b := by
  unfold Int64.min'
  split_ifs with h
  · exact h
  · exact le_rfl

theorem Interval.mem_inter? (a b : Interval) (x : ℤ) :
    (∃ i, Interval.inter? a b = some i ∧ x ∈ i) ↔ x ∈ a ∧ x ∈ b := by
  unfold Interval.inter?
  split_ifs with h
  · constructor
    · rintro ⟨i, hi, hx⟩
      cases hi
      exact ⟨⟨le_trans (Int64.le_max'_left a.left b.left) hx.1,
          le_trans hx.2 (Int64.min'_le_left a.right b.right)⟩,
        ⟨le_trans (Int64.le_max'_right a.left b.left) hx.1,
          le_trans hx.2 (Int64.min'_le_right a.right b.right)⟩⟩
    · intro ⟨ha, hb⟩
      refine ⟨_, rfl, ?_⟩
      constructor
      · unfold Int64.max'
        split_ifs
        · exact hb.1
        · exact ha.1
      · unfold Int64.min'
        split_ifs
        · exact ha.2
        · exact hb.2
  · constructor
    · rintro ⟨i, hi, _⟩
      cases hi
    · intro ⟨ha, hb⟩
      have : (Int64.max' a.left b.left : ℤ) ≤ Int64.min' a.right b.right := by
        unfold Int64.max' Int64.min'
        split_ifs <;> linarith [ha.1, ha.2, hb.1, hb.2]
      exact (h this).elim

def Domain.inter (a b : Domain) : Domain :=
  Domain.ofList (a.intervals.flatMap fun ia =>
    b.intervals.filterMap (fun ib => ia.inter? ib))

def Domain.interval (i : Interval) : Domain :=
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

structure NonemptyDomain where
  domain : Domain
  nonempty : domain.intervals ≠ []
deriving DecidableEq

instance : Coe NonemptyDomain Domain where
  coe d := d.domain

instance : Membership ℤ NonemptyDomain where
  mem d x := x ∈ d.domain

def NonemptyDomain.hull (d : NonemptyDomain) : Interval :=
  d.domain.hullOf d.nonempty

theorem NonemptyDomain.mem_hull (d : NonemptyDomain) {x : ℤ}
    (hx : x ∈ d) : x ∈ d.hull :=
  Domain.mem_hull d.domain d.nonempty hx

def NonemptyDomain.singleton (v : Int64) : NonemptyDomain :=
  ⟨Domain.singleton v, by simp [Domain.singleton]⟩

def NonemptyDomain.interval (i : Interval) : NonemptyDomain :=
  ⟨Domain.interval i, by simp [Domain.interval]⟩

def Domain.ofListNonempty (xs : List Interval) (h : xs ≠ []) : NonemptyDomain :=
  match xs, h with
  | [], h => (h rfl).elim
  | x :: rest, _ =>
    ⟨Domain.ofList (x :: rest), Domain.canonicalize_cons_ne_nil x rest⟩

def NonemptyDomain.min (d : NonemptyDomain) : Int64 :=
  (d.domain.intervals.head d.nonempty).left

def NonemptyDomain.max (d : NonemptyDomain) : Int64 :=
  (d.domain.intervals.getLast d.nonempty).right

example : ¬ ((100 : ℤ) ∈ Domain.interval
    (Interval.ofBounds 0 1 ⟨by decide, by decide⟩ (by decide))) := by
  decide

example : (2 : ℤ) ^ 60 ∈
    Domain.interval (Interval.ofBounds 0 ((2 : ℤ) ^ 60)
      ⟨by decide, by decide⟩ (by decide)) := by
  decide

end CpsatSolver
