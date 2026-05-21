package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"database/sql"

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
		Logs: make([]*api.ProgressLog, len(logs)),
	}
	for i, l := range logs {
		var updated []db.ListUpdatedTaskRow
		updated, err = txqry.ListUpdatedTask(ctx, l.ID)
		if err != nil {
			return
		}
		res.Logs[i] = &api.ProgressLog{
			Desc:    l.Desc,
			Profile: l.Profile,
			Time:    timestamppb.New(l.Time),
			Updates: make([]*api.ProgressLog_UpdatedTask, len(updated)),
		}
		for j, u := range updated {
			res.Logs[j].Updates[j] = &api.ProgressLog_UpdatedTask{
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
		Profile: req.GetLog().GetProfile(),
		Time:    req.GetLog().GetTime().AsTime(),
		Desc:    req.GetLog().GetDesc(),
	})
	if err != nil {
		return
	}

	for _, update := range req.GetLog().GetUpdates() {
		err = txqry.CreateUpdatedTask(ctx, db.CreateUpdatedTaskParams{
			ProgressLog: id,
			Task:        update.GetTask().GetId(),
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
