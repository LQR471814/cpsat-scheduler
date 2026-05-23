package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
)

func (s server) ListScheduledTasks(ctx context.Context, req *api.ListScheduledTasksRequest) (res *api.ListScheduledTasksResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	// this is very ugly but unfortunately the fastest way to get this done
	if req.Timescale != nil {
		scheduled, err := txqry.ListScheduledTasksInTimescale(ctx, db.ListScheduledTasksInTimescaleParams{
			Start:   req.Start.AsTime(),
			End:     req.End.AsTime(),
			Profile: req.ProfileId,
			Unit:    req.GetTimescale(),
		})
		if err != nil {
			return nil, err
		}
		res = &api.ListScheduledTasksResponse{
			Entries: make([]*api.Entry, len(scheduled)),
		}
		for i, s := range scheduled {
			res.Entries[i] = &api.Entry{
				Id:   s.Task,
				Name: s.Name,
			}
		}
	} else {
		scheduled, err := txqry.ListScheduledTasks(ctx, db.ListScheduledTasksParams{
			Start:   req.Start.AsTime(),
			End:     req.End.AsTime(),
			Profile: req.ProfileId,
		})
		if err != nil {
			return nil, err
		}
		res = &api.ListScheduledTasksResponse{
			Entries: make([]*api.Entry, len(scheduled)),
		}
		for i, s := range scheduled {
			res.Entries[i] = &api.Entry{
				Id:   s.Task,
				Name: s.Name,
			}
		}
	}

	return
}

// RecomputeSchedule lists all profiles, runs scheduling for each profile, and persists the generated schedules.
func (s server) RecomputeSchedule(ctx context.Context, req *api.RecomputeScheduleRequest) (res *api.RecomputeScheduleResponse, err error) {
	statectx, err := state.NewContext(ctx, s.logger, s.driver, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		return
	}
	defer statectx.Tx().Rollback()
	txqry := statectx.Queries()

	profileID := req.GetProfile()
	profile, err := txqry.GetProfile(ctx, profileID)
	if err != nil {
		return
	}

	solveRes, err := s.solver.SolveProfile(statectx, profile)
	if err != nil {
		return
	}

	err = txqry.DeleteSchedule(ctx, profileID)
	if err != nil {
		return
	}

	for _, solved := range solveRes.Solution {
		var task db.Task
		task, err = txqry.GetTask(ctx, solved.Id)
		if err != nil {
			return
		}

		profileStart := sql.NullInt64{Valid: true, Int64: solved.Start * task.Unit}
		profileEnd := sql.NullInt64{Valid: true, Int64: solved.End * task.Unit}

		realStart := state.ProfileTimeToRealTime(profileStart, profile)
		realEnd := state.ProfileTimeToRealTime(profileEnd, profile)

		if !realStart.Valid {
			panic("assert failed: realStart invalid")
		}
		if !realEnd.Valid {
			panic("assert failed: realEnd invalid")
		}

		err = txqry.SaveScheduledTask(ctx, db.SaveScheduledTaskParams{
			Task:    solved.Id,
			Profile: profile.ID,
			Start:   realStart.Time,
			End:     realEnd.Time,
		})
		if err != nil {
			return
		}
	}

	err = statectx.Tx().Commit()
	if err != nil {
		return
	}

	res = &api.RecomputeScheduleResponse{}
	return
}
