package state

import (
	"context"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"fmt"
	"log/slog"
)

type Context struct {
	ctx    context.Context
	logger *slog.Logger
	tx     *sql.Tx
	db     *db.Queries
}

func NewContext(
	ctx context.Context,
	logger *slog.Logger,
	driver *sql.DB,
	opts *sql.TxOptions,
) (c Context, err error) {
	tx, err := driver.BeginTx(ctx, opts)
	if err != nil {
		err = fmt.Errorf("begin tx: %w", err)
		return
	}
	c = Context{
		ctx:    ctx,
		logger: logger,
		tx:     tx,
		db:     db.New(tx),
	}
	return
}

func (c Context) Queries() *db.Queries {
	return c.db
}

func (c Context) Tx() *sql.Tx {
	return c.tx
}

// Ctx returns the underlying context.Context.
func (c Context) Ctx() context.Context {
	return c.ctx
}
