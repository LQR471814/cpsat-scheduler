package state

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"errors"
	"fmt"
)

func loadProtoTask(
	ctx context.Context,
	txqry *db.Queries,
	task int64,
) (*api.TaskState, error) {
	t, err := txqry.GetTask(ctx, task)
	if err != nil {
		return nil, err
	}

	if t.Name == "" {
		return nil, fmt.Errorf("assert: Name is empty")
	}

	return &api.TaskState{
		Timescale: t.Unit,
		Name:      t.Name,
		Desc:      t.Desc,
	}, nil
}

func loadProtoConfigs(ctx context.Context, txqry *db.Queries, task int64, s *api.TaskState) error {
	cfg, err := txqry.GetDurConfig(ctx, task)
	if errors.Is(err, sql.ErrNoRows) {
		err = nil
	} else if err != nil {
		return err
	} else {
		s.DurationCfg = &api.DurState{
			Deadline: SQLTimeToProto(cfg.Deadline),
			Pert: &api.PERT{
				Pes: cfg.Pes,
				Exp: cfg.Exp,
				Opt: cfg.Opt,
			},
			TotalCost: SQLInt64ToProto(cfg.TotalCost),
		}
	}

	configs, err := txqry.ListChildrenConfigs(ctx, task)
	if err != nil {
		return err
	}

	s.ChildrenCfgs = make([]*api.ChildrenConfigState, len(configs))
	for i, c := range configs {
		children, err := txqry.ListChildrenConfigChildren(ctx, c.ID)
		if err != nil {
			return err
		}
		childrenEntries := make([]*api.Entry, len(children))
		for i, child := range children {
			childrenEntries[i] = &api.Entry{
				Id:   child.ID,
				Name: child.Name,
			}
		}

		s.ChildrenCfgs[i] = &api.ChildrenConfigState{
			Desc:     c.Desc,
			Deadline: SQLTimeToProto(c.Deadline),
			ExpCost:  SQLInt64ToProto(c.ExpCost),
			Children: childrenEntries,
		}
	}

	return nil
}

func loadProtoConstraints(ctx context.Context, txqry *db.Queries, task int64, s *api.TaskState) error {
	var err error

	prereqs, err := txqry.ListPrereq(ctx, task)
	if err != nil {
		return err
	}
	s.Prereqs = make([]*api.Entry, len(prereqs))
	for i, r := range prereqs {
		s.Prereqs[i] = &api.Entry{
			Id:   r.ID,
			Name: r.Name,
		}
	}

	postreqs, err := txqry.ListPostreq(ctx, task)
	if err != nil {
		return err
	}
	s.Postreqs = make([]*api.Entry, len(postreqs))
	for i, r := range postreqs {
		s.Postreqs[i] = &api.Entry{
			Id:   r.ID,
			Name: r.Name,
		}
	}

	par, err := txqry.GetParent(ctx, task)
	if errors.Is(err, sql.ErrNoRows) {
		return nil
	}
	if err != nil {
		return err
	}

	s.Parent = &api.Entry{
		Id:   par.ID,
		Name: par.Name,
	}
	return nil
}

func LoadProtoTaskState(
	ctx context.Context,
	txqry *db.Queries,
	task int64,
) (*api.TaskState, error) {
	s, err := loadProtoTask(ctx, txqry, task)
	if err != nil {
		return nil, err
	}
	if err = loadProtoConfigs(ctx, txqry, task, s); err != nil {
		return nil, err
	}
	if err = loadProtoConstraints(ctx, txqry, task, s); err != nil {
		return nil, err
	}
	return s, nil
}

func saveProtoTask(
	ctx context.Context,
	txqry *db.Queries,
	task *int64,
	profile int64,
	s *api.TaskState,
) (int64, error) {
	if s == nil {
		panic("assert: state != nil")
	}
	if s.Name == "" {
		panic("assert: name not empty")
	}

	if task == nil {
		return txqry.CreateTask(ctx, db.CreateTaskParams{
			Profile: profile,
			Unit:    s.Timescale,
			Name:    s.Name,
			Desc:    s.Desc,
		})
	}

	id := *task
	err := txqry.UpdateTask(ctx, db.UpdateTaskParams{
		ID:   id,
		Unit: s.Timescale,
		Name: s.Name,
		Desc: s.Desc,
	})
	return id, err
}

func saveProtoConfigs(ctx context.Context, txqry *db.Queries, task int64, s *api.TaskState) error {
	if s.DurationCfg != nil {
		if err := txqry.CreateDurConfig(ctx, db.CreateDurConfigParams{
			Task:      task,
			Pes:       s.DurationCfg.Pes,
			Exp:       s.DurationCfg.Exp,
			Opt:       s.DurationCfg.Opt,
			Deadline:  ProtoTimeToSQL(s.DurationCfg.Deadline),
			TotalCost: ProtoInt64ToSQL(s.DurationCfg.TotalCost),
		}); err != nil {
			return err
		}
	}

	for _, cfg := range s.ChildrenCfgs {
		if cfg == nil {
			continue
		}

		id, err := txqry.CreateChildrenConfig(ctx, db.CreateChildrenConfigParams{
			Task:     task,
			Desc:     cfg.Desc,
			Deadline: ProtoTimeToSQL(cfg.Deadline),
			ExpCost:  ProtoInt64ToSQL(cfg.ExpCost),
		})
		if err != nil {
			return err
		}

		for _, child := range cfg.Children {
			if err := txqry.AddChildToConfig(ctx, db.AddChildToConfigParams{
				Cfg:   id,
				Child: child.Id,
			}); err != nil {
				return err
			}
		}
	}

	return nil
}

func saveProtoConstraints(ctx context.Context, txqry *db.Queries, task int64, s *api.TaskState) error {
	for _, req := range s.Prereqs {
		if err := txqry.SetPrereq(ctx, db.SetPrereqParams{
			Prereq:  req.Id,
			Postreq: task,
		}); err != nil {
			return err
		}
	}

	for _, req := range s.Postreqs {
		if err := txqry.SetPrereq(ctx, db.SetPrereqParams{
			Prereq:  task,
			Postreq: req.Id,
		}); err != nil {
			return err
		}
	}

	if s.Parent != nil {
		return txqry.SetChild(ctx, db.SetChildParams{
			Parent: s.Parent.Id,
			Child:  task,
		})
	}

	return nil
}

func deletePreviousProtoConfigs(ctx context.Context, txqry *db.Queries, task int64) error {
	if err := txqry.DeleteChildrenConfigs(ctx, task); err != nil {
		return err
	}
	return txqry.DeleteDurConfig(ctx, task)
}

func SaveProtoTaskState(
	ctx context.Context,
	txqry *db.Queries,
	task *int64,
	profile int64,
	state *api.TaskState,
) (id int64, err error) {
	if state.DurationCfg == nil && len(state.ChildrenCfgs) == 0 {
		err = fmt.Errorf("invalid input: either duration_cfg must be specified or at least one children_cfg must be specified, both can be specified but not neither")
		return
	}

	id, err = saveProtoTask(ctx, txqry, task, profile, state)
	if err != nil {
		return
	}
	if task != nil {
		if err = deletePreviousProtoConfigs(ctx, txqry, id); err != nil {
			return
		}
	}
	if err = saveProtoConfigs(ctx, txqry, id, state); err != nil {
		return
	}
	if err = saveProtoConstraints(ctx, txqry, id, state); err != nil {
		return
	}
	return
}
