package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"database/sql"

	"google.golang.org/protobuf/types/known/timestamppb"
)

func (s server) CreateEvent(ctx context.Context, req *api.CreateEventRequest) (res *api.CreateEventResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	_, err = txqry.CreateEvent(ctx, db.CreateEventParams{
		Profile: req.GetEvent().GetProfile(),
		Name:    req.GetEvent().GetName(),
		Desc:    req.GetEvent().GetDesc(),
		Start:   req.GetEvent().GetStart().AsTime(),
		End:     req.GetEvent().GetEnd().AsTime(),
	})
	if err != nil {
		return
	}
	res = &api.CreateEventResponse{}
	return
}

func (s server) ReadEvent(ctx context.Context, in *api.ReadEventRequest) (res *api.ReadEventResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	ev, err := txqry.ReadEvent(ctx, in.GetId())
	if err != nil {
		return
	}
	res = &api.ReadEventResponse{
		Event: &api.Event{
			Name:    ev.Name,
			Desc:    ev.Desc,
			Profile: ev.Profile,
			Start:   timestamppb.New(ev.Start),
			End:     timestamppb.New(ev.End),
		},
	}
	return
}

func (s server) UpdateEvent(ctx context.Context, in *api.UpdateEventRequest) (res *api.UpdateEventResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	err = txqry.UpdateEvent(ctx, db.UpdateEventParams{
		ID:      in.GetId(),
		Profile: in.GetEvent().GetProfile(),
		Name:    in.GetEvent().GetName(),
		Desc:    in.GetEvent().GetDesc(),
		Start:   in.GetEvent().GetStart().AsTime(),
	})
	if err != nil {
		return
	}
	res = &api.UpdateEventResponse{}
	return
}

func (s server) ListEvent(ctx context.Context, in *api.ListEventRequest) (res *api.ListEventResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	events, err := txqry.ListEvent(ctx, in.GetProfile())
	if err != nil {
		return
	}
	res = &api.ListEventResponse{
		Entries: make([]*api.Entry, len(events)),
	}
	for i, ev := range events {
		res.Entries[i] = &api.Entry{
			Id:   ev.ID,
			Name: ev.Name,
		}
	}
	return
}

func (s server) RemoveEvent(ctx context.Context, in *api.RemoveEventRequest) (res *api.RemoveEventResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	err = txqry.DeleteEvent(ctx, in.GetId())
	if err != nil {
		return
	}
	res = &api.RemoveEventResponse{}
	return
}
