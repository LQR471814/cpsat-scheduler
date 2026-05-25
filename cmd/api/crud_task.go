package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/proto/commonpb"
	"cpsat-scheduler/internal/state"
	"database/sql"
	"strings"
)

func (s server) ReadTask(ctx context.Context, in *apipb.ReadTaskRequest) (res *apipb.ReadTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	taskState, err := state.LoadProtoTaskState(ctx, txqry, in.Id)
	if err != nil {
		return
	}
	res = &apipb.ReadTaskResponse{State: taskState}
	return
}

func (s server) SaveTask(ctx context.Context, in *apipb.SaveTaskRequest) (res *apipb.SaveTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	var id int64
	id, err = state.SaveProtoTaskState(ctx, txqry, in.Id, in.ProfileId, in.State)
	if err != nil {
		return
	}
	err = tx.Commit()
	if err != nil {
		return
	}
	res = &apipb.SaveTaskResponse{Id: id}
	return
}

func (s server) DeleteTask(ctx context.Context, in *apipb.DeleteTaskRequest) (res *apipb.DeleteTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	err = txqry.DeleteChildrenConfigs(ctx, in.Id)
	if err != nil {
		return
	}
	err = tx.Commit()
	if err != nil {
		return
	}
	res = &apipb.DeleteTaskResponse{}
	return
}

func (s server) ListPossibleRelatives(ctx context.Context, in *apipb.ListPossibleRelativesRequest) (res *apipb.ListPossibleRelativesResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	task, err := txqry.GetTask(ctx, in.TaskId)
	if err != nil {
		return
	}

	var args []any
	var query strings.Builder
	query.WriteString(`select id, name from task t`)
	switch in.Type {
	case apipb.ListPossibleRelativesRequest_CHILD:
		// where unit is smaller and exclude ones that are already children
		query.WriteString(` where unit < ? and not exists (
select 1 from children_config c
inner join children_config_child cc
	on c.id = cc.cfg
where c.task = t.id
)`)
		args = append(args, task.Unit)
		if task.Start.Valid {
			query.WriteString(` and (start is null or start >= ?)`)
			args = append(args, task.Start.Time)
		}
		if task.End.Valid {
			query.WriteString(` and (end is null or end < ?)`)
			args = append(args, task.End.Time)
		}
	case apipb.ListPossibleRelativesRequest_PARENT:
		// where unit is larger and exclude already existing parent
		query.WriteString(` where unit > ? and not exists (
select 1 from children_config c
inner join children_config_child cc
	on c.id = cc.cfg
where cc.child = t.id
)`)
		args = append(args, task.Unit)
	case apipb.ListPossibleRelativesRequest_PREREQ:
		// where unit is the same and potential prereq with explicit end time
		// must end before starting
		query.WriteString(` where unit = ?`)
		args = append(args, task.Unit)
		if task.Start.Valid {
			query.WriteString(` and (end is null or end < ?)`)
			args = append(args, task.Start.Time)
		}
	case apipb.ListPossibleRelativesRequest_POSTREQ:
		// where unit is the same and potential postreq with explicit start
		// time must start after end
		query.WriteString(` where unit = ?`)
		args = append(args, task.Unit)
		if task.End.Valid {
			query.WriteString(` and (start is null or start >= ?)`)
			args = append(args, task.End.Time)
		}
	}

	rows, err := tx.Query(query.String(), args...)
	if err != nil {
		return
	}
	defer rows.Close()

	var items []*commonpb.Entry
	for rows.Next() {
		entry := &commonpb.Entry{}
		err = rows.Scan(&entry.Id, &entry.Name)
		if err != nil {
			return
		}
		items = append(items, entry)
	}

	return
}
