package state

import (
	"cpsat-scheduler/internal/state/db"
	"cpsat-scheduler/internal/solver/solverpb"
	"database/sql"
	"math"
	"time"

	"gonum.org/v1/gonum/stat/distuv"
)

func betaPPF(p, alpha, beta float64) float64 {
	if alpha <= 0 || beta <= 0 {
		return math.NaN()
	}
	if p < 0 || p > 1 {
		return math.NaN()
	}
	d := distuv.Beta{
		Alpha: alpha,
		Beta:  beta,
	}
	return d.Quantile(p)
}

// returns the duration necessary to achieve a certain probability
func pertPPF(p, opt, exp, pes float64) float64 {
	alpha := 1 + 4*(exp-opt)/(pes-opt)
	beta := 1 + 4*(pes-exp)/(pes-opt)
	x := betaPPF(p, alpha, beta)
	dur := opt + x*(pes-opt)
	return dur
}

func deadlineIntervals(deadline, expCost, totalCost int64) []*solverpb.CostInterval {
	return []*solverpb.CostInterval{
		{
			Start: 0,
			End:   deadline,
			Cost:  expCost,
		},
		{
			Start: deadline,
			End:   math.MaxInt64 - 1,
			Cost:  totalCost,
		},
	}
}

func roundInt64(x float64) int64 {
	return int64(math.Round(x))
}

func convertDeadline(
	univStart time.Time,
	atomicTimescaleDuration time.Duration,
	deadline sql.NullTime,
) int64 {
	if !deadline.Valid {
		return 0
	}
	return int64(deadline.Time.Sub(univStart) / atomicTimescaleDuration)
}

func pertDurCfgs(
	univStart time.Time,
	atomicTimescaleDuration time.Duration,
	choices int64,
	durcfg db.DurConfig,
) (out []*solverpb.DurConfig, err error) {
	totalCost := int64(0)
	if durcfg.TotalCost.Valid {
		totalCost = durcfg.TotalCost.Int64
	}

	deadline := convertDeadline(univStart, atomicTimescaleDuration, durcfg.Deadline)

	for i := range choices {
		x := i + 1
		// we distribute probability stops via cube-root power fn
		// (x/n)^(1/3)
		p := math.Pow(float64(x)/float64(choices), float64(1)/float64(3))
		dur := roundInt64(pertPPF(
			p,
			float64(durcfg.Opt*durcfg.OptUnit),
			float64(durcfg.Exp*durcfg.ExpUnit),
			float64(durcfg.Pes*durcfg.PesUnit),
		))
		out = append(out, &solverpb.DurConfig{
			Intervals: deadlineIntervals(
				deadline,
				roundInt64(p*float64(totalCost)),
				totalCost,
			),
			Duration: dur,
		})
	}

	return
}
