package state

import (
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state/db"
	"time"
)

func GenerateEventTasks(c Context, profile db.Profile, out *[]*solverpb.Task) (events []db.Event, err error) {
	events, err = c.db.ListEvent(c.ctx, profile.ID)
	if err != nil {
		return
	}
	id := int64(-1)
	for _, ev := range events {
		lookupEventTasks(ev, profile, &id, out)
	}
	return
}

func lookupEventTasks(ev db.Event, profile db.Profile, id *int64, out *[]*solverpb.Task) {
	start := int64(ev.Start.Sub(profile.UniverseStart)) / profile.AtomicTimescaleDuration
	end := int64(ev.End.Sub(profile.UniverseStart)) / profile.AtomicTimescaleDuration
	for i := start; i < end; i++ {
		next := i + 1
		task := &solverpb.Task{
			Id:      *id,
			Unit:    1,
			Start:   &i,
			End:     &next,
			Prereqs: nil,
			DurCfgs: []*solverpb.DurConfig{
				&solverpb.DurConfig{
					Intervals: []*solverpb.CostInterval{
						&solverpb.CostInterval{
							Start: i,
							End:   next,
							Cost:  0,
						},
					},
					Duration: 1,
				},
			},
			ChildrenCfgs: nil,
		}
		*out = append(*out, task)
		*id--
	}
}

func LookupProfileState(c Context, profile db.Profile, out *[]*solverpb.Task) (err error) {
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
	task.DurCfgs, err = pertDurCfgs(
		profile.UniverseStart,
		time.Duration(profile.AtomicTimescaleDuration),
		choices,
		durCfg,
	)
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
		deadline := convertDeadline(
			profile.UniverseStart,
			time.Duration(profile.AtomicTimescaleDuration),
			childCfg.Deadline,
		)
		out = append(out, &solverpb.ChildrenConfig{
			Intervals: deadlineIntervals(
				deadline,
				childCfg.ExpCost.Int64,
				childCfg.TotalCost.Int64,
			),
			Children: children,
		})
	}
	return
}
