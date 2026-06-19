package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/solver"
	"cpsat-scheduler/internal/state/db"
	"database/sql"
	"fmt"
	"log/slog"
)

type server struct {
	apipb.UnimplementedAPIServer

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
	solv, err := solver.NewSolver(ctx, logger, solverPath)
	if err != nil {
		err = fmt.Errorf("new solver: %w", err)
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
