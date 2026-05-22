package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"errors"
	"fmt"

	"google.golang.org/protobuf/types/known/timestamppb"
)

func (s server) ListProgressUpdates(ctx context.Context, req *api.ListProgressUpdatesRequest) (res *api.ListProgressUpdatesResponse, err error) {
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
	res = &api.ListProgressUpdatesResponse{
		Logs: make([]*api.ListProgressUpdatesResponse_ProgressLog, len(logs)),
	}
	for i, l := range logs {
		var updated []db.ListUpdatedTaskRow
		updated, err = txqry.ListUpdatedTask(ctx, l.ID)
		if err != nil {
			return
		}
		res.Logs[i] = &api.ListProgressUpdatesResponse_ProgressLog{
			Desc:    l.Desc,
			Time:    timestamppb.New(l.Time),
			Updates: make([]*api.ListProgressUpdatesResponse_ProgressLog_UpdatedTask, len(updated)),
		}
		for j, u := range updated {
			res.Logs[j].Updates[j] = &api.ListProgressUpdatesResponse_ProgressLog_UpdatedTask{
				Desc: u.Desc,
				Task: &api.Entry{
					Id:   u.Task,
					Name: u.TaskName,
				},
			}
		}
	}
	return
}

func (s server) ProgressUpdate(ctx context.Context, req *api.ProgressUpdateRequest) (res *api.ProgressUpdateResponse, err error) {
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
	res = &api.ProgressUpdateResponse{Id: id}
	return
}

func (s server) EditProgressLog(ctx context.Context, req *api.EditProgressLogRequest) (res *api.EditProgressLogResponse, err error) {
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

	res = &api.EditProgressLogResponse{}
	return
}

func (s server) DeleteProgressLog(ctx context.Context, req *api.DeleteProgressLogRequest) (res *api.DeleteProgressLogResponse, err error) {
	err = s.db.DeleteProgressLog(ctx, req.GetId())
	if err != nil {
		return
	}
	res = &api.DeleteProgressLogResponse{}
	return
}

func (s server) GetLastCheckpoint(ctx context.Context, req *api.GetLastCheckpointRequest) (res *api.GetLastCheckpointResponse, err error) {
	t, err := s.db.GetLastCheckpoint(ctx, req.GetProfile())
	if err == nil {
		res = &api.GetLastCheckpointResponse{
			Time: timestamppb.New(t),
		}
	} else if errors.Is(err, sql.ErrNoRows) {
		res = &api.GetLastCheckpointResponse{Time: nil}
	}
	return
}
