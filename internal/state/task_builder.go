package state

import (
	"context"
	"cpsat-scheduler/internal/db"
	"database/sql"
	"errors"
	"fmt"
)

type DurState struct {
	PesUnit int64
	Pes     int64

	ExpUnit int64
	Exp     int64

	OptUnit int64
	Opt     int64

	Deadline  sql.NullTime
	TotalCost sql.NullInt64
}

type ChildrenConfigState struct {
	Desc     string
	Deadline sql.NullTime
	ExpCost  sql.NullInt64
	Children []int64
}

type TaskState struct {
	Name         string
	Desc         string
	Timescale    *int64
	DurationCfg  *DurState
	ChildrenCfgs []ChildrenConfigState
	Prereqs      []int64
	Postreqs     []int64
	Parent       *int64
}

func (s *TaskState) loadTask(
	ctx context.Context,
	txqry *db.Queries,
	task,
	profileId int64,
) (err error) {
	t, err := txqry.GetTask(ctx, task)
	if err != nil {
		return
	}
	s.Timescale = &t.Unit
	s.Name = t.Name
	if t.Name == "" {
		err = fmt.Errorf("assert: Name is empty")
		return
	}
	s.Desc = t.Desc
	if t.Profile != profileId {
		panic("assert: profile of task must match context profile")
	}
	return
}

func (s *TaskState) loadConfigs(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	cfg, err := txqry.GetDurConfig(ctx, task)
	if errors.Is(err, sql.ErrNoRows) {
		err = nil
	} else if err != nil {
		return
	} else {
		s.DurationCfg = &DurState{
			Deadline:  cfg.Deadline,
			Pes:       cfg.Pes,
			PesUnit:   cfg.PesUnit,
			Exp:       cfg.Exp,
			ExpUnit:   cfg.ExpUnit,
			Opt:       cfg.Opt,
			OptUnit:   cfg.OptUnit,
			TotalCost: cfg.TotalCost,
		}
	}

	configs, err := txqry.ListChildrenConfigs(ctx, task)
	if err != nil {
		return
	}
	s.ChildrenCfgs = make([]ChildrenConfigState, len(configs))
	for i, c := range configs {
		var children []int64
		children, err = txqry.ListChildrenConfigChildren(ctx, c.ID)
		if err != nil {
			return
		}
		s.ChildrenCfgs[i] = ChildrenConfigState{
			Desc:     c.Desc,
			Deadline: c.Deadline,
			ExpCost:  c.ExpCost,
			Children: children,
		}
	}
	return
}

func (s *TaskState) loadConstraints(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	if s.Prereqs, err = txqry.ListPrereq(ctx, task); err != nil {
		return
	}
	if s.Postreqs, err = txqry.ListPostreq(ctx, task); err != nil {
		return
	}
	par, err := txqry.GetParent(ctx, task)
	if errors.Is(err, sql.ErrNoRows) {
		err = nil
		return
	}
	if err != nil {
		return
	}
	s.Parent = &par.ID
	return
}

func (s *TaskState) Load(ctx context.Context, txqry *db.Queries, task, profileId int64) (err error) {
	if err = s.loadTask(ctx, txqry, task, profileId); err != nil {
		return
	}
	if err = s.loadConfigs(ctx, txqry, task); err != nil {
		return
	}
	return s.loadConstraints(ctx, txqry, task)
}

func (s *TaskState) saveTask(
	ctx context.Context,
	txqry *db.Queries,
	task *int64,
	profileId int64,
) (id int64, err error) {
	if s.Timescale == nil {
		panic("assert: timescale != nil")
	}
	if s.Name == "" {
		panic("assert: name not empty")
	}
	if task == nil {
		id, err = txqry.CreateTask(ctx, db.CreateTaskParams{
			Profile: profileId,
			Unit:    *s.Timescale,
			Name:    s.Name,
			Desc:    s.Desc,
		})
		return
	}
	id = *task
	err = txqry.UpdateTask(ctx, db.UpdateTaskParams{
		ID:   *task,
		Unit: *s.Timescale,
		Name: s.Name,
		Desc: s.Desc,
	})
	return
}

func (s *TaskState) saveConfigs(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	if s.DurationCfg != nil {
		if err = txqry.CreateDurConfig(ctx, db.CreateDurConfigParams{
			Task:      task,
			Pes:       s.DurationCfg.Pes,
			Exp:       s.DurationCfg.Exp,
			Opt:       s.DurationCfg.Opt,
			Deadline:  s.DurationCfg.Deadline,
			TotalCost: s.DurationCfg.TotalCost,
		}); err != nil {
			return
		}
	}

	for _, cfg := range s.ChildrenCfgs {
		if err = txqry.CreateChildrenConfig(ctx, db.CreateChildrenConfigParams{
			Task:     task,
			Desc:     cfg.Desc,
			Deadline: cfg.Deadline,
			ExpCost:  cfg.ExpCost,
		}); err != nil {
			return
		}
	}
	return
}

func (s *TaskState) saveConstraints(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	for _, req := range s.Prereqs {
		err = txqry.SetPrereq(ctx, db.SetPrereqParams{
			Prereq:  req,
			Postreq: task,
		})
		if err != nil {
			return
		}
	}
	for _, req := range s.Postreqs {
		err = txqry.SetPrereq(ctx, db.SetPrereqParams{
			Prereq:  task,
			Postreq: req,
		})
		if err != nil {
			return
		}
	}
	if s.Parent != nil {
		err = txqry.SetChild(ctx, db.SetChildParams{
			Parent: *s.Parent,
			Child:  task,
		})
	}
	return
}

func (s *TaskState) deletePreviousConfigs(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	err = txqry.DeleteChildrenConfigs(ctx, task)
	if err != nil {
		return
	}
	err = txqry.DeleteDurConfig(ctx, task)
	return
}

func (s *TaskState) Save(ctx context.Context, txqry *db.Queries, task *int64, profileId int64) (id int64, err error) {
	if id, err = s.saveTask(ctx, txqry, task, profileId); err != nil {
		return
	}
	if task != nil {
		if err = s.deletePreviousConfigs(ctx, txqry, *task); err != nil {
			return
		}
	}
	if err = s.saveConfigs(ctx, txqry, *task); err != nil {
		return
	}
	err = s.saveConstraints(ctx, txqry, *task)
	return
}

type TaskBuilder struct {
	ctx   *Context
	task  *int64
	State TaskState
}

func NewTaskBuilder(ctx *Context) TaskBuilder {
	if ctx == nil {
		panic("assert: ctx cannot be nil")
	}
	return TaskBuilder{ctx: ctx}
}

func (b TaskBuilder) LoadExisting(task int64) (out TaskBuilder, err error) {
	tx, err := b.ctx.driver.BeginTx(b.ctx.ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := b.ctx.db.WithTx(tx)

	state := &b.State
	err = state.Load(b.ctx.ctx, txqry, task, b.ctx.profile.ID)
	b.task = &task
	out = b
	return
}

func (b TaskBuilder) Build() (id int64, err error) {
	tx, err := b.ctx.driver.BeginTx(b.ctx.ctx, nil)
	if err != nil {
		return
	}
	defer tx.Rollback()
	txqry := b.ctx.db.WithTx(tx)

	state := &b.State
	id, err = state.Save(b.ctx.ctx, txqry, b.task, b.ctx.profile.ID)
	return
}
