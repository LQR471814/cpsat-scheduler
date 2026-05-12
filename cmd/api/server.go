package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"log/slog"
)

type server struct {
	api.UnimplementedAPIServer

	ctx    context.Context
	logger *slog.Logger
	db     *db.Queries
	driver *sql.DB
}

func newServer(
	ctx context.Context,
	logger *slog.Logger,
	driver *sql.DB,
) server {
	return server{
		ctx:    ctx,
		logger: logger,
		db:     db.New(driver),
		driver: driver,
	}
}
