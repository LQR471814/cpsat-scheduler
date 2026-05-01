package state

import (
	"context"
	"cpsat-scheduler/internal/db"
	"database/sql"
	"log/slog"
)

type Context struct {
	ctx     context.Context
	logger  *slog.Logger
	db      *db.Queries
	driver  *sql.DB
	profile db.Profile
}

func NewContext(
	ctx context.Context,
	logger *slog.Logger,
	db *db.Queries,
	driver *sql.DB,
	profile db.Profile,
) Context {
	return Context{
		ctx:     ctx,
		logger:  logger,
		db:      db,
		driver:  driver,
		profile: profile,
	}
}
