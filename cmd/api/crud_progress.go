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

func (s server) ListProgressUpdates(ctx context.Context, req *apipb.ListProgressUpdatesRequest) (res *apipb.ListProgressUpdatesResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	logs, err := txqry.ListProgressLog(ctx, db.ListProgressLogParams{
		Start: req.GetStart().AsTime(),
		End:   req.GetEnd().AsTime(),
	})
	if err != nil {
		return
	}
	res = &apipb.ListProgressUpdatesResponse{
		Logs: make([]*apipb.ListProgressUpdatesResponse_ProgressLog, len(logs)),
	}
	for i, l := range logs {
		var updated []db.ListUpdatedTaskRow
		updated, err = txqry.ListUpdatedTask(ctx, l.ID)
		if err != nil {
			return
		}
		res.Logs[i] = &apipb.ListProgressUpdatesResponse_ProgressLog{
			Desc:    l.Desc,
			Time:    timestamppb.New(l.Time),
			Updates: make([]*apipb.ListProgressUpdatesResponse_ProgressLog_UpdatedTask, len(updated)),
		}
		for j, u := range updated {
			res.Logs[j].Updates[j] = &apipb.ListProgressUpdatesResponse_ProgressLog_UpdatedTask{
				Desc: u.Desc,
				Task: &apipb.Entry{
					Id:   u.Task,
					Name: u.TaskName,
				},
			}
		}
	}
	return
}

func (s server) ProgressUpdate(ctx context.Context, req *apipb.ProgressUpdateRequest) (res *apipb.ProgressUpdateResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	id, err := txqry.CreateProgressLog(ctx, db.CreateProgressLogParams{
		Profile: req.GetProfile(),
		Time:    req.GetTime().AsTime(),
		Desc:    req.GetDesc(),
	})
	if err != nil {
		return
	}
	for _, update := range req.GetUpdates() {
		err = txqry.CreateUpdatedTask(ctx, db.CreateUpdatedTaskParams{
			ProgressLog: id,
			Task:        update.GetTask(),
			Desc:        update.GetDesc(),
		})
		if err != nil {
			return
		}
	}

	err = tx.Commit()
	if err != nil {
		return
	}
	res = &apipb.ProgressUpdateResponse{Id: id}
	return
}

func (s server) EditProgressLog(ctx context.Context, req *apipb.EditProgressLogRequest) (res *apipb.EditProgressLogResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	profile, err := txqry.GetProgressLog(ctx, req.GetId())
	if errors.Is(err, sql.ErrNoRows) {
		err = fmt.Errorf("edit progress: progress log of id '%d' does not exist", req.GetId())
		return
	}
	if err != nil {
		return
	}

	err = txqry.DeleteProgressLog(ctx, req.GetId())
	if err != nil {
		return
	}

	id, err := txqry.CreateProgressLog(ctx, db.CreateProgressLogParams{
		Profile: profile,
		Time:    req.GetTime().AsTime(),
		Desc:    req.GetDesc(),
	})
	if err != nil {
		return
	}
	for _, update := range req.GetUpdates() {
		err = txqry.CreateUpdatedTask(ctx, db.CreateUpdatedTaskParams{
			ProgressLog: id,
			Task:        update.GetTask(),
			Desc:        update.GetDesc(),
		})
		if err != nil {
			return
		}
	}
	err = tx.Commit()
	if err != nil {
		return
	}

	res = &apipb.EditProgressLogResponse{}
	return
}

func (s server) DeleteProgressLog(ctx context.Context, req *apipb.DeleteProgressLogRequest) (res *apipb.DeleteProgressLogResponse, err error) {
	err = s.db.DeleteProgressLog(ctx, req.GetId())
	if err != nil {
		return
	}
	res = &apipb.DeleteProgressLogResponse{}
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
