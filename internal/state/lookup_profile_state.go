package state

import (
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state/db"
	"math"
)

// TODO: replace this with something less-hardcoded
var timescales = []int64{
	4128768,
	2064384,
	1032192,
	516096,
	258048,
	129024,
	64512,
	32256,
	8064,
	2688,
	672,
	96,
	16,
	1,
}

var zeroCost = []*solverpb.CostInterval{
	&solverpb.CostInterval{
		Start: 0,
		End:   math.MaxInt64 - 1,
		Cost:  0,
	},
}

type Horizon struct {
	// Start should be in terms of the atomic unit (profile time)
	Start int64
	// End should be in terms of the atomic unit (profile time)
	End int64
}

func generateEventTasks(c Context, profile db.Profile, horizon Horizon, id *int64, out *[]*solverpb.Task, ev db.Event) {
	start := RealTimeToProfileTime(ev.Start, profile)
	end := RealTimeToProfileTime(ev.End, profile)

	if start >= horizon.End {
		return
	}
	if end < horizon.Start {
		return
	}

	dur := end - start
	var unit int64
	for _, u := range timescales {
		if u > dur {
			continue
		}
		unit = u
		break
	}

	// subtract leftDur from first, set last to rightDur
	leftDur := start % unit
	rightDur := end % unit

	for i := int64(0); i < dur/unit; i++ {
		taskStart := start - leftDur + i*unit
		if taskStart < horizon.Start {
			continue
		}
		if taskStart >= horizon.End {
			continue
		}

		c.logger.Debug("task", "start", taskStart)

		dur := unit
		if i == 0 {
			dur -= leftDur
		}
		taskEnd := taskStart + 1
		*out = append(*out, &solverpb.Task{
			Id:      *id,
			Unit:    unit,
			Start:   &taskStart,
			End:     &taskEnd,
			Prereqs: nil,
			DurCfgs: []*solverpb.DurConfig{
				&solverpb.DurConfig{
					Intervals: zeroCost,
					Duration:  dur,
				},
			},
		})
		*id--
	}

	if rightDur == 0 {
		return
	}

	cursor := end - rightDur
	cursorEnd := cursor + 1
	*out = append(*out, &solverpb.Task{
		Id:      *id,
		Unit:    unit,
		Start:   &cursor,
		End:     &cursorEnd,
		Prereqs: nil,
		DurCfgs: []*solverpb.DurConfig{
			&solverpb.DurConfig{
				Intervals: zeroCost,
				Duration:  rightDur,
			},
		},
	})
	*id--
}

func GenerateEventTasks(c Context, profile db.Profile, horizon Horizon, out *[]*solverpb.Task) (events []db.Event, err error) {
	txqry := c.db.WithTx(c.tx)
	events, err = txqry.ListEvent(c.ctx, profile.ID)
	if err != nil {
		return
	}
	id := int64(-1)
	// TODO: remove debugging
	for _, ev := range events {
		generateEventTasks(c, profile, horizon, &id, out, ev)
	}
	return
}

func LookupProfileState(c Context, profile db.Profile, horizon Horizon, out *[]*solverpb.Task) (err error) {
	ctx := c.ctx

	tasks, err := c.db.ListTasks(ctx, profile.ID)
	if err != nil {
		return
	}

	choices := int64(4)
	if profile.PertGenChoices.Valid {
		choices = profile.PertGenChoices.Int64
	}

	var task *solverpb.Task
	for _, t := range tasks {
		task, err = lookupTask(c, profile, t, choices)
		if err != nil {
			return
		}

		// we only operate on start because horizon limits the start time
		if task.Start != nil {
			if *task.Start < horizon.Start {
				continue
			}
			if *task.Start >= horizon.End {
				continue
			}
		}

		*out = append(*out, task)
	}

	return
}

func lookupTask(
	c Context,
	profile db.Profile,
	t db.Task,
	choices int64,
) (out *solverpb.Task, err error) {
	var start *int64
	var end *int64
	if t.Start.Valid {
		start = &t.Start.Int64
	}
	if t.End.Valid {
		end = &t.End.Int64
	}

	var rows []db.ListPrereqRow
	rows, err = c.db.ListPrereq(c.ctx, t.ID)
	if err != nil {
		return
	}
	prereqs := make([]int64, len(rows))
	for i, r := range rows {
		prereqs[i] = r.ID
	}

	var durCfg db.DurConfig
	durCfg, err = c.db.GetDurConfig(c.ctx, t.ID)
	if err != nil {
		return
	}
	task := &solverpb.Task{
		Id:      t.ID,
		Unit:    t.Unit,
		Start:   start,
		End:     end,
		Prereqs: prereqs,
	}
	task.DurCfgs, err = pertDurCfgs(profile, choices, durCfg)
	if err != nil {
		return
	}

	task.ChildrenCfgs, err = lookupChildCfgs(c, profile, t)
	if err != nil {
		return
	}
	out = task
	return
}

func lookupChildCfgs(c Context, profile db.Profile, task db.Task) (out []*solverpb.ChildrenConfig, err error) {
	ctx := c.ctx
	var childrenCfgs []db.ChildrenConfig
	childrenCfgs, err = c.db.ListChildrenConfigs(ctx, task.ID)
	if err != nil {
		return
	}
	for _, childCfg := range childrenCfgs {
		var rows []db.ListChildrenConfigChildrenRow
		rows, err = c.db.ListChildrenConfigChildren(ctx, childCfg.ID)
		if err != nil {
			return
		}
		children := make([]int64, len(rows))
		for i, r := range rows {
			children[i] = r.ID
		}
		deadline := RealNullTimeToProfileTime(childCfg.Deadline, profile)
		out = append(out, &solverpb.ChildrenConfig{
			Intervals: deadlineIntervals(
				// no issue if deadline is null, it will just use 0
				deadline.Int64,
				childCfg.ExpCost.Int64,
				childCfg.TotalCost.Int64,
			),
			Children: children,
		})
	}
	return
}
