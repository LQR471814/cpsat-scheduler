package state

import (
	"cpsat-scheduler/internal/proto/commonpb"
	"cpsat-scheduler/internal/proto/solverpb"
	"cpsat-scheduler/internal/state/db"
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

func deadlineIntervals(deadline *commonpb.AtomicUnit, expCost, totalCost int64) []*solverpb.CostInterval {
	return []*solverpb.CostInterval{
		{
			Start: &commonpb.AtomicUnit{Value: 0},
			End:   deadline,
			Cost:  expCost,
		},
		{
			Start: deadline,
			End:   &commonpb.AtomicUnit{Value: math.MaxInt64 - 1},
			Cost:  totalCost,
		},
	}
}

func roundInt64(x float64) int64 {
	return int64(math.Round(x))
}

func pertDurCfgs(
	profile db.Profile,
	choices int64,
	durcfg db.DurConfig,
) (out []*solverpb.DurConfig, err error) {
	totalCost := int64(0)
	if durcfg.TotalCost.Valid {
		totalCost = durcfg.TotalCost.Int64
	}

	// no real issue if deadline is null, will just default to 0, which will lead to intv like:
	// [0, 0] \cup [1, "\infty"]
	deadline := &commonpb.AtomicUnit{
		Value: RealNullTimeToProfileTime(durcfg.Deadline, profile).Int64,
	}

	for i := range choices {
		// we distribute probability stops via cube-root power fn
		// (x/n)^(1/3)
		//
		// p = P(complete before deadline)
		p := math.Pow(float64(i)/float64(choices), float64(1)/float64(3))
		// we find duration necessary for probability
		dur := time.Duration(roundInt64(pertPPF(
			p,
			float64(durcfg.Opt),
			float64(durcfg.Exp),
			float64(durcfg.Pes),
		)))
		out = append(out, &solverpb.DurConfig{
			Intervals: deadlineIntervals(
				deadline,
				// expected cost = P(^ complete before deadline) * total cost
				roundInt64((1-p)*float64(totalCost)),
				totalCost,
			),
			Duration: &commonpb.AtomicUnit{
				Value: RealDurationToProfileDuration(dur, profile),
			},
		})
	}

	return
}
