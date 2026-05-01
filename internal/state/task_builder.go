package state

import (
	"context"
	"cpsat-scheduler/internal/db"
	"database/sql"
	"errors"
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
	Name         *string
	Desc         *string
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
	s.Name = &t.Name
	s.Desc = &t.Desc
	if t.Profile != profileId {
		panic("assert: profile of task must match context profile")
	}
	return
}

func (s *TaskState) loadDuration(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	cfg, err := txqry.GetDurConfig(ctx, task)
	if errors.Is(err, sql.ErrNoRows) {
		err = nil
		return
	}
	if err != nil {
		return
	}
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
	return
}

func (s *TaskState) loadChildrenConfigs(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	configs, err := txqry.ListChildrenConfigs(ctx, task)
	if err != nil {
		return
	}
	s.ChildrenCfgs = make([]ChildrenConfigState, len(configs))
	for i, cfg := range configs {
		var children []int64
		children, err = txqry.ListChildrenConfigChildren(ctx, cfg.ID)
		if err != nil {
			return
		}
		s.ChildrenCfgs[i] = ChildrenConfigState{
			Desc:     cfg.Desc,
			Deadline: cfg.Deadline,
			ExpCost:  cfg.ExpCost,
			Children: children,
		}
	}
	return
}

func (s *TaskState) loadPrereqs(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	s.Prereqs, err = txqry.ListPrereq(ctx, task)
	return
}

func (s *TaskState) loadPostreqs(ctx context.Context, txqry *db.Queries, task int64) (err error) {
	s.Postreqs, err = txqry.ListPostreq(ctx, task)
	return
}

func (s *TaskState) loadParent(ctx context.Context, txqry *db.Queries, task int64) (err error) {
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
	if err = s.loadDuration(ctx, txqry, task); err != nil {
		return
	}
	if err = s.loadChildrenConfigs(ctx, txqry, task); err != nil {
		return
	}
	if err = s.loadPrereqs(ctx, txqry, task); err != nil {
		return
	}
	return s.loadPostreqs(ctx, txqry, task)
}

type TaskBuilder struct {
	ctx   *Context
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
	out = b
	return
}
