package main

import (
	"context"
	"cpsat-scheduler/internal/api"
	"cpsat-scheduler/internal/solver"
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
	solver solver.Solver
}

func newServer(
	ctx context.Context,
	logger *slog.Logger,
	driver *sql.DB,
	solverPath string,
) (serv server, err error) {
	solv, err := solver.NewSolver(logger, solverPath)
	if err != nil {
		return
	}
	serv = server{
		ctx:    ctx,
		logger: logger,
		db:     db.New(driver),
		driver: driver,
		solver: solv,
	}
	return
}
