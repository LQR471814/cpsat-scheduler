package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/proto/commonpb"
	"cpsat-scheduler/internal/proto/solverpb"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"fmt"

	"google.golang.org/protobuf/types/known/durationpb"
)

func (s server) ListScheduledTasks(ctx context.Context, req *apipb.ListScheduledTasksRequest) (res *apipb.ListScheduledTasksResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		err = fmt.Errorf("begin tx: %w", err)
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	profile, err := txqry.GetProfile(ctx, req.ProfileId)
	if err != nil {
		err = fmt.Errorf("db GetProfile: %w", err)
		return
	}

	// this is very ugly but unfortunately the fastest way to get this done
	if req.Timescale != nil {
		scheduled, err := txqry.ListScheduledTasksInTimescale(ctx, db.ListScheduledTasksInTimescaleParams{
			Start:   req.Start.AsTime(),
			End:     req.End.AsTime(),
			Profile: req.ProfileId,
			Unit:    req.GetTimescale(),
		})
		if err != nil {
			err = fmt.Errorf("db ListScheduledTasksInTimescale: %w", err)
			return nil, err
		}
		res = &apipb.ListScheduledTasksResponse{
			Entries: make([]*apipb.ListScheduledTasksResponse_ScheduledTask, len(scheduled)),
		}
		for i, s := range scheduled {
			dur := state.ProfileDurationToRealDuration(state.AtomicUnits(s.Duration), profile)
			res.Entries[i] = &apipb.ListScheduledTasksResponse_ScheduledTask{
				Id:       s.Task,
				Name:     s.Name,
				Duration: durationpb.New(dur),
			}
		}
	} else {
		scheduled, err := txqry.ListScheduledTasks(ctx, db.ListScheduledTasksParams{
			Start:   req.Start.AsTime(),
			End:     req.End.AsTime(),
			Profile: req.ProfileId,
		})
		if err != nil {
			err = fmt.Errorf("db ListScheduledTasks: %w", err)

			return nil, err
		}
		res = &apipb.ListScheduledTasksResponse{
			Entries: make([]*apipb.ListScheduledTasksResponse_ScheduledTask, len(scheduled)),
		}
		for i, s := range scheduled {
			dur := state.ProfileDurationToRealDuration(state.AtomicUnits(s.Duration), profile)
			res.Entries[i] = &apipb.ListScheduledTasksResponse_ScheduledTask{
				Id:       s.Task,
				Name:     s.Name,
				Duration: durationpb.New(dur),
			}
		}
	}

	return
}

// RecomputeSchedule lists all profiles, runs scheduling for each profile, and persists the generated schedules.
func (s server) RecomputeSchedule(ctx context.Context, req *apipb.RecomputeScheduleRequest) (res *apipb.RecomputeScheduleResponse, err error) {
	statectx, err := state.NewContext(ctx, s.logger, s.driver, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		err = fmt.Errorf("new state context: %w", err)
		return
	}
	defer statectx.Tx().Rollback()
	txqry := statectx.Queries()

	profile, err := txqry.GetProfile(ctx, req.GetProfile())
	if err != nil {
		err = fmt.Errorf("db GetProfile: %w", err)
		return
	}

	s.logger.Debug("solving profile", "profile", profile.ID)

	horizon := state.Horizon{
		Start: &commonpb.AtomicUnit{Value: int64(state.RealTimeToProfileTime(req.GetHorizon().GetStart().AsTime(), profile))},
		End:   &commonpb.AtomicUnit{Value: int64(state.RealTimeToProfileTime(req.GetHorizon().GetEnd().AsTime(), profile))},
	}
	solveRes, err := s.solver.SolveProfile(statectx, profile, horizon)
	if err != nil {
		err = fmt.Errorf("solve profile: %w", err)
		return
	}

	switch solveRes.Status {
	case solverpb.SolveStatus_FEASIBLE,
		solverpb.SolveStatus_OPTIMAL:
		s.logger.Debug("reset schedule state", "profile", profile.ID)

		err = replaceSchedule(ctx, txqry, profile, solveRes)
		if err != nil {
			err = fmt.Errorf("replace schedule: %w", err)
			return
		}
		err = statectx.Tx().Commit()
		if err != nil {
			err = fmt.Errorf("commit tx: %w", err)
			return
		}
	}

	res = &apipb.RecomputeScheduleResponse{}
	return
}

func replaceSchedule(
	ctx context.Context,
	txqry *db.Queries,
	profile db.Profile,
	solveRes *solverpb.SolveResponse,
) (err error) {
	err = txqry.DeleteSchedule(ctx, profile.ID)
	if err != nil {
		err = fmt.Errorf("db DeleteSchedule: %w", err)
		return
	}

	for _, solved := range solveRes.Solution {
		var task db.Task
		task, err = txqry.GetTask(ctx, solved.Id)
		if err != nil {
			err = fmt.Errorf("db GetTask: %w", err)
			return
		}

		profileStart := sql.NullInt64{Valid: true, Int64: solved.Start.Value * task.Unit}
		profileEnd := sql.NullInt64{Valid: true, Int64: (solved.Start.Value + 1) * task.Unit}

		realStart := state.ProfileNullTimeToRealTime(profileStart, profile)
		realEnd := state.ProfileNullTimeToRealTime(profileEnd, profile)

		if !realStart.Valid {
			panic("assert failed: realStart invalid")
		}
		if !realEnd.Valid {
			panic("assert failed: realEnd invalid")
		}

		err = txqry.SaveScheduledTask(ctx, db.SaveScheduledTaskParams{
			Task:     solved.Id,
			Profile:  profile.ID,
			Start:    realStart.Time,
			End:      realEnd.Time,
			Duration: solved.Duration.Value,
		})
		if err != nil {
			err = fmt.Errorf("db SaveScheduledTask: %w", err)
			return
		}
	}

	return
}
