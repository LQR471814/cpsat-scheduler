package state

import (
	"cpsat-scheduler/internal/solver/solverpb"
	"cpsat-scheduler/internal/state/db"
	"math"
)

func GenerateEventTasks(c Context, profile db.Profile, out *[]*solverpb.Task) (events []db.Event, err error) {
	events, err = c.db.ListEvent(c.ctx, profile.ID)
	if err != nil {
		return
	}
	id := int64(-1)
	generateEventTasks(c, profile, &id, out, events[0])
	// for _, ev := range events {
	// 	generateEventTasks(c, ev, profile, &id, out)
	// }
	return
}

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

func subdivideEventTasks(
	c Context,
	profile db.Profile,
	// id is a ptr to next currently unused id, it shall decrement for each task created
	id *int64,
	// subdivided tasks shall be put into out
	out *[]*solverpb.Task,
	// list of subdividable timescale units ordered large to small
	units []int64,
	// start and end are both profile times, representing the interval to subdivide
	start, end int64,
) {
	if units == nil {
		panic("assert failed: units != nil")
	}

	c.logger.Debug("subdivide", "start", start, "end", end)

	// 1) we choose the largest unit that is <= dur
	// 2) we shrink `units` to all those < the chosen unit
	dur := end - start
	var unit int64
	for i, u := range units {
		if u > dur {
			continue
		}
		unit = u
		if i < len(units)-1 {
			units = units[i+1:]
		} else {
			// if unit == 1, then we do not expect any more subdivisions (since
			// all is divisible by 1)
			units = nil
		}
		break
	}

	// leftDur is the span of time before the next unit
	//
	// start % unit = part of start that exceeds the prior unit
	// unit - (start % unit) = the atomic units until the next unit
	leftDur := unit - (start % unit)

	// if part of start that exceeds prior unit is 0, we make left dur 0
	if start%unit == 0 {
		leftDur = 0
	}

	// start + leftDur = the unit to start at
	unitStart := start + leftDur

	for i := range (end - unitStart) / unit {
		// both start and end are profile times
		start := unitStart + i*unit

		// since possible scheduled times is [start, end), we add one for only
		// possible schedule time to be start
		end := start + 1

		c.logger.Debug("task instance", "start", start, "end", end, "unit", unit)
		*out = append(*out, &solverpb.Task{
			Id:      *id,
			Unit:    unit,
			Start:   &start,
			End:     &end,
			Prereqs: nil,
			DurCfgs: []*solverpb.DurConfig{
				&solverpb.DurConfig{
					Intervals: zeroCost,
					Duration:  unit,
				},
			},
		})
		*id--
	}

	// since dur / unit rounds down, there may still exist some remainder of
	// the end that hasn't been covered
	rightDur := (end - unitStart) % unit

	if leftDur > 0 {
		subdivideEventTasks(c, profile, id, out, units, start, start+leftDur)
	}
	if rightDur > 0 {
		subdivideEventTasks(c, profile, id, out, units, end-rightDur, end)
	}
}

func generateEventTasks(c Context, profile db.Profile, id *int64, out *[]*solverpb.Task, ev db.Event) {
	start := RealTimeToProfileTime(ev.Start, profile)
	end := RealTimeToProfileTime(ev.End, profile)

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
		dur := unit
		if i == 0 {
			dur -= leftDur
		}
		cursor := start - leftDur + i*unit
		cursorEnd := cursor + 1
		c.logger.Debug("task", "start", cursor, "end", cursorEnd, "dur", dur, "unit", unit)
		*out = append(*out, &solverpb.Task{
			Id:      *id,
			Unit:    unit,
			Start:   &cursor,
			End:     &cursorEnd,
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

	if rightDur > 0 {
		cursor := end - rightDur
		cursorEnd := cursor + 1
		c.logger.Debug("task", "start", cursor, "end", cursorEnd, "dur", rightDur, "unit", unit)
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
