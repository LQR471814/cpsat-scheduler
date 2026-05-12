package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state"
)

func (s server) ReadTask(ctx context.Context, in *api.ReadTaskRequest) (res *api.ReadTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	taskState, err := state.LoadProtoTaskState(ctx, txqry, in.Id)
	if err != nil {
		return
	}
	res = &api.ReadTaskResponse{State: taskState}
	return
}

func (s server) SaveTask(ctx context.Context, in *api.SaveTaskRequest) (res *api.SaveTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	_, err = state.SaveProtoTaskState(ctx, txqry, in.Id, in.ProfileId, in.State)
	return
}

func (s server) DeleteTask(ctx context.Context, in *api.DeleteTaskRequest) (res *api.DeleteTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	err = txqry.DeleteChildrenConfigs(ctx, in.Id)
	return
}
