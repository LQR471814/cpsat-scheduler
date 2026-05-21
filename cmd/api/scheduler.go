package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
)

// RecomputeSchedule lists all profiles, runs scheduling for each profile, and persists the generated schedules.
func (s server) RecomputeSchedule(ctx context.Context, in *api.RecomputeScheduleRequest) (res *api.RecomputeScheduleResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	profileID := in.GetProfile()
	profile, err := txqry.GetProfile(ctx, profileID)
	if err != nil {
		return
	}

	statectx := state.NewContext(ctx, s.logger, s.driver)
	solveRes, err := s.solver.SolveProfile(statectx, profileID)
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

	err = tx.Commit()
	if err != nil {
		return
	}

	res = &api.RecomputeScheduleResponse{}
	return
}
