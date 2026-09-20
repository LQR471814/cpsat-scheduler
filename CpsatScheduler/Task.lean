import CpsatScheduler.Defs

namespace CpsatScheduler

/-- Generic task constructor over a contiguous range of start-bucket indices
`[kLo, kHi]` in `unit` coordinates.

The caller supplies only the two horizon-fit facts at the range endpoints:
`begin ≤ kLo * u` and `(kHi + 1) * u ≤ end_`. Every per-bucket obligation of
`Task.bucketsFitHorizon` — including both `Int64` nonoverflow bounds — is derived
by monotonicity in `k` and from the horizon's own `Int64` safety proof. -/
def Task.ofBucketRange (scales : Timescales)
    (id : TaskId)
    (unit : { u : UnitScale // u ∈ scales.units.set })
    (kLo : ℤ := scales.horizon.begin)
    (kHi : ℤ := scales.horizon.end_ / unit.val.val - 1)
    (hle : kLo ≤ kHi := by decide)
    (hbegin : (scales.horizon.begin : ℤ) ≤ kLo * unit.val.val := by decide)
    (hend : (kHi + 1) * unit.val.val ≤ scales.horizon.end_ := by decide)
    (label : Option String := none) :
    Task scales :=
  let u : ℤ := unit.val.val
  -- Unit is a positive natural, so `u ≥ 1`.
  have hu1 : (1 : ℤ) ≤ u := by
    change (1 : ℤ) ≤ ((unit.val.val : ℕ) : ℤ)
    have hpos : 0 < unit.val.val := unit.val.pos
    exact_mod_cast hpos
  have hu0 : (0 : ℤ) < u := lt_of_lt_of_le zero_lt_one hu1
  have hbegin0 : (0 : ℤ) ≤ (scales.horizon.begin : ℤ) := Int.natCast_nonneg _
  -- `kLo * u ≥ begin ≥ 0` with `u > 0` forces `kLo ≥ 0`.
  have hkLo0 : (0 : ℤ) ≤ kLo := by nlinarith [hbegin, hbegin0]
  have hkHi0 : (0 : ℤ) ≤ kHi := le_trans hkLo0 hle
  -- Horizon end is within Int64.
  have hendMax : (scales.horizon.end_ : ℤ) ≤ CpsatSolver.Int64.max :=
    scales.horizon.end_safe.2
  have hminNonpos : CpsatSolver.Int64.min ≤ (0 : ℤ) := by decide
  -- Upper anchor: everything in range is `≤ (kHi + 1) * u ≤ end_ ≤ max`.
  have hkHiu_le_end : kHi * u ≤ (scales.horizon.end_ : ℤ) := by nlinarith [hend, hu0]
  -- Interval endpoints are within Int64.
  have hkLoSafe : CpsatSolver.Int64.Nonoverflow kLo := by
    refine ⟨le_trans hminNonpos hkLo0, ?_⟩
    have : kLo ≤ kLo * u := by nlinarith [hu1, hkLo0]
    have hchain : kLo * u ≤ (scales.horizon.end_ : ℤ) := by nlinarith [hle, hu0, hkHiu_le_end]
    linarith [le_trans this hchain, hendMax]
  have hkHiSafe : CpsatSolver.Int64.Nonoverflow kHi := by
    refine ⟨le_trans hminNonpos hkHi0, ?_⟩
    have : kHi ≤ kHi * u := by nlinarith [hu1, hkHi0]
    linarith [le_trans this hkHiu_le_end, hendMax]
  {
    id := id
    label := label
    unit := unit
    startDomain :=
      CpsatSolver.NonemptyDomain.interval
        (CpsatSolver.Interval.ofBounds kLo kHi ⟨hkLoSafe, hkHiSafe⟩ hle)
    bucketsFitHorizon := by
      intro k hk
      -- Membership reduces to `kLo ≤ k ≤ kHi`.
      rw [CpsatSolver.NonemptyDomain.interval,
        CpsatSolver.Domain.mem_interval] at hk
      obtain ⟨hklo, hkhi⟩ := hk
      -- endpoints of `Interval.ofBounds kLo kHi` are `kLo`, `kHi`.
      have hklo' : kLo ≤ k := hklo
      have hkhi' : k ≤ kHi := hkhi
      have hk0 : (0 : ℤ) ≤ k := le_trans hkLo0 hklo'
      -- Core arithmetic bounds.
      have hbeginle : (scales.horizon.begin : ℤ) ≤ k * u := by
        have : kLo * u ≤ k * u := by nlinarith [hklo', hu0]
        linarith [hbegin, this]
      have hendle : (k + 1) * u ≤ (scales.horizon.end_ : ℤ) := by
        have : (k + 1) * u ≤ (kHi + 1) * u := by nlinarith [hkhi', hu0]
        linarith [hend, this]
      have hku0 : (0 : ℤ) ≤ k * u := by nlinarith [hk0, hu0]
      have hk1u0 : (0 : ℤ) ≤ (k + 1) * u := by nlinarith [hk0, hu0]
      have hku_le_end : k * u ≤ (scales.horizon.end_ : ℤ) := by
        have : k * u ≤ (k + 1) * u := by nlinarith [hu0]
        linarith [hendle, this]
      refine ⟨hbeginle, hendle, ?_, ?_⟩
      · exact ⟨le_trans hminNonpos hku0, le_trans hku_le_end hendMax⟩
      · exact ⟨le_trans hminNonpos hk1u0, le_trans hendle hendMax⟩
  }

end CpsatScheduler

