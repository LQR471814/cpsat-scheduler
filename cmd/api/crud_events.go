package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/proto/commonpb"
	"cpsat-scheduler/internal/state/db"
	"database/sql"

	"google.golang.org/protobuf/types/known/timestamppb"
)

func (s server) CreateEvent(ctx context.Context, req *apipb.CreateEventRequest) (res *apipb.CreateEventResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	for _, ev := range req.GetEvent() {
		_, err = txqry.CreateEvent(ctx, db.CreateEventParams{
			Profile: ev.GetProfile(),
			Name:    ev.GetName(),
			Desc:    ev.GetDesc(),
			Start:   ev.GetStart().AsTime(),
			End:     ev.GetEnd().AsTime(),
		})
		if err != nil {
			return
		}
	}
	err = tx.Commit()
	if err != nil {
		return
	}
	res = &apipb.CreateEventResponse{}
	return
}

func (s server) ReadEvent(ctx context.Context, in *apipb.ReadEventRequest) (res *apipb.ReadEventResponse, err error) {
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
	res = &apipb.ReadEventResponse{
		Event: &apipb.Event{
			Name:    ev.Name,
			Desc:    ev.Desc,
			Profile: ev.Profile,
			Start:   timestamppb.New(ev.Start),
			End:     timestamppb.New(ev.End),
		},
	}
	return
}

func (s server) UpdateEvent(ctx context.Context, in *apipb.UpdateEventRequest) (res *apipb.UpdateEventResponse, err error) {
	err = s.db.UpdateEvent(ctx, db.UpdateEventParams{
		ID:      in.GetId(),
		Profile: in.GetEvent().GetProfile(),
		Name:    in.GetEvent().GetName(),
		Desc:    in.GetEvent().GetDesc(),
		Start:   in.GetEvent().GetStart().AsTime(),
	})
	if err != nil {
		return
	}
	res = &apipb.UpdateEventResponse{}
	return
}

func (s server) ListEvent(ctx context.Context, in *apipb.ListEventRequest) (res *apipb.ListEventResponse, err error) {
	events, err := s.db.ListEvent(ctx, in.GetProfile())
	if err != nil {
		return
	}
	res = &apipb.ListEventResponse{
		Entries: make([]*commonpb.Entry, len(events)),
	}
	for i, ev := range events {
		res.Entries[i] = &commonpb.Entry{
			Id:   ev.ID,
			Name: ev.Name,
		}
	}
	return
}

func (s server) RemoveEvent(ctx context.Context, in *apipb.RemoveEventRequest) (res *apipb.RemoveEventResponse, err error) {
	err = s.db.DeleteEvent(ctx, in.GetId())
	if err != nil {
		return
	}
	res = &apipb.RemoveEventResponse{}
	return
}
