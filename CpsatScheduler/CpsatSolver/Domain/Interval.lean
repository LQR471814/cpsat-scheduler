import CpsatScheduler.CpsatSolver.Domain.Int64

namespace CpsatSolver

theorem Interval.mem_toSet (i : Interval) (x : ℤ) :
    x ∈ i.toSet ↔ x ∈ i := Iff.rfl

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
    left := Subtype.mk left nonoverflow.1
    right := Subtype.mk right nonoverflow.2
    left_le_right := left_le_right
  }

def Interval.neg (i : Interval)
    (h : Int64.Nonoverflow (-i.right : ℤ) ∧ Int64.Nonoverflow (-i.left : ℤ)) :
    Interval :=
  {
    left := Subtype.mk (-(i.right : ℤ)) h.left
    right := Subtype.mk (-(i.left : ℤ)) h.right
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

instance : DecidableRel Interval.separated :=
  fun a b => inferInstanceAs (Decidable ((a.right : ℤ) + 1 < (b.left : ℤ)))

theorem Interval.separated_trans {x a y : Interval}
    (hxa : Interval.separated x a) (hay : Interval.separated a y) :
    Interval.separated x y := by
  have hlr := a.left_le_right
  have hx : (x.right : ℤ) + 1 < (a.left : ℤ) := hxa
  have hy : (a.right : ℤ) + 1 < (y.left : ℤ) := hay
  have : (x.right : ℤ) + 1 < (y.left : ℤ) := by linarith
  exact this

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

def Interval.inter? (a b : Interval) : Option Interval :=
  if h : (Int64.max' a.left b.left : ℤ) ≤ Int64.min' a.right b.right then
    some {
      left := Int64.max' a.left b.left
      right := Int64.min' a.right b.right
      left_le_right := h
    }
  else
    none

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

def Interval.divPosConst (i : Interval)
  (divisor : ℤ) (pos : divisor > 0) :
    Interval :=
  {
    left := Subtype.mk
      (i.left.val / divisor)
      (Int64.proof_ediv_of_pos
        i.left.prop
        pos)
    right := Subtype.mk
      (i.right.val / divisor)
      (Int64.proof_ediv_of_pos
        i.right.prop
        pos)
    left_le_right := Int.ediv_le_ediv
      pos
      i.left_le_right
  }

theorem Interval.mem_const_div (i : Interval)
  (divisor : ℤ) (pos : divisor > 0) :
    ∀ x ∈ i, x / divisor ∈ i.divPosConst divisor pos :=
  fun x x_mem_i => by
    change (i.mem x) at x_mem_i
    dsimp [Interval.mem] at x_mem_i
    constructor
    · dsimp [divPosConst]
      apply Int.ediv_le_ediv
      · exact pos
      · exact x_mem_i.1
    · dsimp [divPosConst]
      apply Int.ediv_le_ediv
      · exact pos
      · exact x_mem_i.2

end CpsatSolver
