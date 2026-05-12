package state

import (
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state/db"
	"time"
)

func LookupProfileState(c Context, profileID int64) (pbtasks []*solverpb.Task, err error) {
	ctx := c.ctx
	tx, err := c.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := c.db.WithTx(tx)

	profile, err := txqry.GetProfile(c.ctx, profileID)
	if err != nil {
		return
	}
	tasks, err := txqry.ListTasks(ctx, profile.ID)
	if err != nil {
		return
	}

	choices := int64(4)
	if profile.PertGenChoices.Valid {
		choices = profile.PertGenChoices.Int64
	}

	pbtasks = make([]*solverpb.Task, len(tasks))
	for i, t := range tasks {
		var start *int64
		var end *int64
		if t.Start.Valid {
			start = &t.Start.Int64
		}
		if t.End.Valid {
			end = &t.End.Int64
		}

		var prereqs []int64
		prereqs, err = txqry.ListPrereq(ctx, t.ID)
		if err != nil {
			return
		}

		var durCfg db.DurConfig
		durCfg, err = txqry.GetDurConfig(ctx, t.ID)
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

		task.ChildrenCfgs, err = lookupChildCfgs(c, txqry, profile, t)
		if err != nil {
			return
		}
		pbtasks[i] = task
	}

	return
}

func lookupChildCfgs(c Context, txqry *db.Queries, profile db.Profile, task db.Task) (out []*solverpb.ChildrenConfig, err error) {
	ctx := c.ctx
	var childrenCfgs []db.ChildrenConfig
	childrenCfgs, err = txqry.ListChildrenConfigs(ctx, task.ID)
	if err != nil {
		return
	}
	for _, childCfg := range childrenCfgs {
		var children []int64
		children, err = txqry.ListChildrenConfigChildren(ctx, childCfg.ID)
		if err != nil {
			return
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
