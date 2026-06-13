package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"errors"
	"fmt"

	"google.golang.org/protobuf/types/known/timestamppb"
)

func (s server) ProgressUpdate(ctx context.Context, req *apipb.ProgressUpdateRequest) (res *apipb.ProgressUpdateResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		err = fmt.Errorf("begin tx: %w", err)
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	id, err := txqry.CreateProgressLog(ctx, db.CreateProgressLogParams{
		Profile: req.GetProfile(),
		Time:    req.GetTime().AsTime(),
	})
	if err != nil {
		err = fmt.Errorf("db CreateProgressLog: %w", err)
		return
	}
	for _, taskID := range req.GetUpdatedTasks() {
		var task db.Task
		task, err = txqry.GetTask(ctx, taskID)
		if err != nil {
			err = fmt.Errorf("db GetTask: %w", err)
			return
		}

		err = txqry.CreateUpdatedTask(ctx, db.CreateUpdatedTaskParams{
			ProgressLog: id,
			ID:          taskID,
			Name:        task.Name,
			Unit:        task.Unit,
			Desc:        task.Desc,
			Start:       task.Start,
			End:         task.End,
		})
		if err != nil {
			err = fmt.Errorf("db CreateUpdatedTask: %w", err)
			return
		}
	}

	err = tx.Commit()
	if err != nil {
		err = fmt.Errorf("commit tx: %w", err)
		return
	}
	res = &apipb.ProgressUpdateResponse{Id: id}
	return
}

func (s server) GetLastCheckpoint(ctx context.Context, req *apipb.GetLastCheckpointRequest) (res *apipb.GetLastCheckpointResponse, err error) {
	t, err := s.db.GetLastCheckpoint(ctx, req.GetProfile())
	if err == nil {
		res = &apipb.GetLastCheckpointResponse{
			Time: timestamppb.New(t),
		}
	} else if errors.Is(err, sql.ErrNoRows) {
		res = &apipb.GetLastCheckpointResponse{Time: nil}
		err = nil
	}
	return
}
