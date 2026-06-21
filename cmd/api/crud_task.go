package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/proto/commonpb"
	"cpsat-scheduler/internal/state"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"errors"
	"fmt"
	"strings"
)

func (s server) ReadTask(ctx context.Context, in *apipb.ReadTaskRequest) (res *apipb.ReadTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		err = fmt.Errorf("begin tx (readonly): %w", err)
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	taskState, err := state.LoadProtoTaskState(ctx, txqry, in.Id)
	if err != nil {
		err = fmt.Errorf("load task state: %w", err)
		return
	}
	res = &apipb.ReadTaskResponse{State: taskState}
	return
}

func (s server) SaveTask(ctx context.Context, in *apipb.SaveTaskRequest) (res *apipb.SaveTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		err = fmt.Errorf("begin tx: %w", err)
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)
	var id int64
	id, err = state.SaveProtoTaskState(ctx, txqry, in.Id, in.ProfileId, in.State)
	if err != nil {
		err = fmt.Errorf("save task state: %w", err)
		return
	}
	err = tx.Commit()
	if err != nil {
		err = fmt.Errorf("commit tx: %w", err)
		return
	}
	res = &apipb.SaveTaskResponse{Id: id}
	return
}

func (s server) DeleteTask(ctx context.Context, in *apipb.DeleteTaskRequest) (res *apipb.DeleteTaskResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		err = fmt.Errorf("begin tx: %w", err)
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	err = txqry.DeleteTask(ctx, in.Id)
	if err != nil {
		err = fmt.Errorf("db DeleteTask: %w", err)
		return
	}
	err = txqry.DeleteDurConfig(ctx, in.Id)
	if err != nil {
		err = fmt.Errorf("db DeleteDurConfig: %w", err)
		return
	}
	err = txqry.DeleteChildrenConfigs(ctx, in.Id)
	if err != nil {
		err = fmt.Errorf("db DeleteChildrenConfigs: %w", err)
		return
	}

	err = tx.Commit()
	if err != nil {
		err = fmt.Errorf("commit tx: %w", err)
		return
	}
	res = &apipb.DeleteTaskResponse{}
	return
}

func (s server) ListPossibleRelatives(ctx context.Context, in *apipb.ListPossibleRelativesRequest) (res *apipb.ListPossibleRelativesResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, nil)
	if err != nil {
		err = fmt.Errorf("begin tx: %w", err)
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	task, err := txqry.GetTask(ctx, in.TaskId)
	if err != nil {
		err = fmt.Errorf("db GetTask: %w", err)
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
		err = fmt.Errorf(
			"db query (%s) (%v): %w",
			query.String(),
			args,
			err,
		)
		return
	}
	defer rows.Close()

	var items []*commonpb.Entry
	for rows.Next() {
		entry := &commonpb.Entry{}
		err = rows.Scan(&entry.Id, &entry.Name)
		if err != nil {
			err = fmt.Errorf("row scan commonpb.Entry: %w", err)
			return
		}
		items = append(items, entry)
	}

	return
}

func (s server) ListTasks(ctx context.Context, req *apipb.ListTasksRequest) (res *apipb.ListTasksResponse, err error) {
	tasks, err := s.db.ListTaskEntries(ctx, req.GetProfile())
	if err != nil {
		err = fmt.Errorf("db ListTaskEntries: %w", err)
		return
	}
	res = &apipb.ListTasksResponse{
		Tasks: make([]*commonpb.Entry, len(tasks)),
	}
	for i, t := range tasks {
		res.Tasks[i] = &commonpb.Entry{
			Id:   t.ID,
			Name: t.Name,
		}
	}
	return
}

func (s server) ListTaskStates(ctx context.Context, req *apipb.ListTaskStatesRequest) (res *apipb.ListTaskStatesResponse, err error) {
	tx, err := s.driver.BeginTx(ctx, &sql.TxOptions{
		ReadOnly: true,
	})
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := s.db.WithTx(tx)

	tasks, err := txqry.ListTasks(ctx, req.GetProfile())
	if err != nil {
		err = fmt.Errorf("db ListTasks: %w", err)
		return
	}

	res = &apipb.ListTaskStatesResponse{
		Tasks: make([]*apipb.ListTaskStatesResponse_Task, len(tasks)),
	}
	for i, t := range tasks {
		resTask := &apipb.ListTaskStatesResponse_Task{
			Id: t.ID,
			State: &apipb.TaskState{
				Name:         t.Name,
				Desc:         t.Desc,
				Timescale:    t.Unit,
				Start:        state.SQLTimeToProto(t.Start),
				End:          state.SQLTimeToProto(t.End),
				Parent:       nil,
				Prereqs:      nil,
				Postreqs:     nil,
				DurationCfg:  nil,
				ChildrenCfgs: nil,
			},
		}
		res.Tasks[i] = resTask

		// set parent
		var parent db.Task
		parent, err = txqry.GetParent(ctx, t.ID)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return
		}
		if errors.Is(err, sql.ErrNoRows) {
			resTask.State.Parent = &commonpb.Entry{
				Id:   parent.ID,
				Name: parent.Name,
			}
		}

		// set prereqs
		var prereqs []db.ListPrereqRow
		prereqs, err = txqry.ListPrereq(ctx, t.ID)
		if err != nil {
			return
		}
		resTask.State.Prereqs = make([]*commonpb.Entry, len(prereqs))
		for i, p := range prereqs {
			resTask.State.Prereqs[i] = &commonpb.Entry{
				Id:   p.ID,
				Name: p.Name,
			}
		}

		// set postreqs
		var postreqs []db.ListPostreqRow
		postreqs, err = txqry.ListPostreq(ctx, t.ID)
		if err != nil {
			return
		}
		resTask.State.Postreqs = make([]*commonpb.Entry, len(postreqs))
		for i, p := range postreqs {
			resTask.State.Postreqs[i] = &commonpb.Entry{
				Id:   p.ID,
				Name: p.Name,
			}
		}

		// set duration
		var durCfg db.DurConfig
		durCfg, err = txqry.GetDurConfig(ctx, t.ID)
		if err == nil {
			resTask.State.DurationCfg = &apipb.DurState{
				Pert: &apipb.PERT{
					Pes: state.SQLDurationToProto(durCfg.Pes),
					Exp: state.SQLDurationToProto(durCfg.Exp),
					Opt: state.SQLDurationToProto(durCfg.Opt),
				},
				Deadline:  state.SQLTimeToProto(durCfg.Deadline),
				TotalCost: durCfg.TotalCost,
			}
		} else if !errors.Is(err, sql.ErrNoRows) {
			return
		}

		// set children cfgs
		var cfgs []db.ChildrenConfig
		cfgs, err = txqry.ListChildrenConfigs(ctx, t.ID)
		if err != nil {
			return
		}
		resTask.State.ChildrenCfgs = make([]*apipb.ChildrenConfigState, len(cfgs))
		for i, cfg := range cfgs {
			state := &apipb.ChildrenConfigState{
				Desc:     cfg.Desc,
				Deadline: state.SQLTimeToProto(cfg.Deadline),
				ExpCost:  cfg.ExpCost.Int64,
				Children: nil,
			}
			resTask.State.ChildrenCfgs[i] = state

			var children []db.ListChildrenConfigChildrenRow
			children, err = txqry.ListChildrenConfigChildren(ctx, cfg.ID)
			if err != nil {
				return
			}
			state.Children = make([]*commonpb.Entry, len(children))
			for i, c := range children {
				state.Children[i] = &commonpb.Entry{
					Id:   c.ID,
					Name: c.Name,
				}
			}
		}
	}

	return
}
