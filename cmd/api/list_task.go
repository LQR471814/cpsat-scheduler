package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"strings"
)

func (s server) ListScheduledTasks(ctx context.Context, in *api.ListScheduledTasksRequest) (res *api.ListScheduledTasksResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	scheduled, err := txqry.ListScheduledTasks(ctx, db.ListScheduledTasksParams{
		Start:   in.Start.AsTime(),
		End:     in.End.AsTime(),
		Profile: in.ProfileId,
	})
	res = &api.ListScheduledTasksResponse{
		Entries: make([]*api.TaskEntry, len(scheduled)),
	}
	for i, s := range scheduled {
		res.Entries[i] = &api.TaskEntry{
			Id:   s.Task,
			Name: s.Name,
		}
	}
	return
}

func (s server) ListPossibleRelatives(ctx context.Context, in *api.ListPossibleRelativesRequest) (res *api.ListPossibleRelativesResponse, err error) {
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
	case api.ListPossibleRelativesRequest_CHILD:
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
			args = append(args, task.Start.Int64)
		}
		if task.End.Valid {
			query.WriteString(` and (end is null or end < ?)`)
			args = append(args, task.End.Int64)
		}
	case api.ListPossibleRelativesRequest_PARENT:
		// where unit is larger and exclude already existing parent
		query.WriteString(` where unit > ? and not exists (
select 1 from children_config c
inner join children_config_child cc
	on c.id = cc.cfg
where cc.child = t.id
)`)
		args = append(args, task.Unit)
	case api.ListPossibleRelativesRequest_PREREQ:
		// where unit is the same and potential prereq with explicit end time
		// must end before starting
		query.WriteString(` where unit = ?`)
		args = append(args, task.Unit)
		if task.Start.Valid {
			query.WriteString(` and (end is null or end < ?)`)
			args = append(args, task.Start.Int64)
		}
	case api.ListPossibleRelativesRequest_POSTREQ:
		// where unit is the same and potential postreq with explicit start
		// time must start after end
		query.WriteString(` where unit = ?`)
		args = append(args, task.Unit)
		if task.End.Valid {
			query.WriteString(` and (start is null or start >= ?)`)
			args = append(args, task.End.Int64)
		}
	}

	rows, err := tx.Query(query.String(), args...)
	if err != nil {
		return
	}
	defer rows.Close()

	var items []*api.TaskEntry
	for rows.Next() {
		var task db.Task
		err = rows.Scan(&task)
		if err != nil {
			return
		}
		items = append(items, &api.TaskEntry{
			Id:   task.ID,
			Name: task.Name,
		})
	}

	return
}
