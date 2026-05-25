package main

import (
	"context"
	"cpsat-scheduler/internal/proto/apipb"
	"cpsat-scheduler/internal/state/db"
	"flag"
	"log/slog"
	"net"
	"os"
	"os/signal"

	"github.com/lmittmann/tint"
	"google.golang.org/grpc"
)

const socket_path = "/tmp/cpsat-scheduler.api.sock"

func listenServer(ctx context.Context, server *grpc.Server) (err error) {
	_ = os.Remove(socket_path)
	listener, err := net.Listen("unix", socket_path)
	if err != nil {
		return
	}
	err = os.Chmod(socket_path, 0600)
	if err != nil {
		return
	}
	go func() {
		server.Serve(listener)
	}()
	<-ctx.Done()
	server.GracefulStop()
	return
}

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()

	solverPath := flag.String("solver", "", "path to solver binary")
	flag.Parse()

	if *solverPath == "" {
		slog.Error("missing -solver flag to solver binary path")
		os.Exit(1)
	}

	tintHandle := tint.NewHandler(os.Stderr, &tint.Options{Level: slog.LevelDebug})
	logger := slog.New(tintHandle)
	logger = logger.WithGroup("main")

	driver, err := db.OpenDB(ctx, logger, "state.db")
	if err != nil {
		slog.Error("open db", "err", err)
		os.Exit(1)
	}
	defer driver.Close()

	impl, err := newServer(ctx, logger, driver, *solverPath)
	if err != nil {
		slog.Error("init server", "err", err)
		os.Exit(1)
	}
	server := grpc.NewServer()
	apipb.RegisterAPIServer(server, impl)

	logger.Info("listening...", "path", socket_path)
	err = listenServer(ctx, server)
	if err != nil {
		slog.Error("listen", "err", err)
		os.Exit(1)
	}
}
