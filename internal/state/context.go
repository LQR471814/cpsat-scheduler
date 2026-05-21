package state

import (
	"context"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"log/slog"
)

type Context struct {
	ctx    context.Context
	logger *slog.Logger
	db     *db.Queries
	driver *sql.DB
}

func NewContext(
	ctx context.Context,
	logger *slog.Logger,
	driver *sql.DB,
) Context {
	return Context{
		ctx:    ctx,
		logger: logger,
		db:     db.New(driver),
		driver: driver,
	}
}

// Ctx returns the underlying context.Context.
func (c Context) Ctx() context.Context {
	return c.ctx
}

